require "rails_helper"

RSpec.describe Wordpress::MediaFetcher do
  let(:store) { ObjectStore.current }
  let(:url) { "https://techandfi.com/wp-content/uploads/2026/05/photo.png" }

  def media_item(source_url: url, key: "wp-content/uploads/2026/05/photo.png")
    MediaItem.create!(key: key, filename: File.basename(key), source_url: source_url)
  end

  describe ".key_for" do
    it "keeps the original uploads path so content URLs need only a host swap" do
      expect(described_class.key_for(url)).to eq("wp-content/uploads/2026/05/photo.png")
    end

    it "decodes percent escapes so the stored key is the real filename" do
      expect(described_class.key_for("https://x.com/wp-content/uploads/a%20b.jpg"))
        .to eq("wp-content/uploads/a b.jpg")
    end

    it "returns nil for something that isn't a usable URL" do
      expect(described_class.key_for("not a url")).to be_nil
      expect(described_class.key_for("")).to be_nil
    end
  end

  describe "#fetch!" do
    it "downloads the image and uploads it under the original key" do
      stub_request(:get, url).to_return(body: "PNGDATA", headers: { "Content-Type" => "image/png" })
      item = media_item

      described_class.new(store: store).fetch!(item)

      expect(store.uploads["wp-content/uploads/2026/05/photo.png"])
        .to include(body: "PNGDATA", content_type: "image/png")
    end

    it "marks the record stored and records its size" do
      stub_request(:get, url).to_return(body: "PNGDATA", headers: { "Content-Type" => "image/png" })
      item = media_item

      described_class.new(store: store).fetch!(item)

      expect(item.reload).to have_attributes(status: "stored", byte_size: 7, content_type: "image/png")
      expect(item.uploaded_at).to be_present
    end

    it "strips charset parameters off the content type" do
      stub_request(:get, url).to_return(body: "x", headers: { "Content-Type" => "image/png; charset=binary" })
      item = media_item

      described_class.new(store: store).fetch!(item)

      expect(item.reload.content_type).to eq("image/png")
    end

    it "falls back to the extension when the server sends no content type" do
      stub_request(:get, url).to_return(body: "x", headers: {})
      item = media_item

      described_class.new(store: store).fetch!(item)

      expect(item.reload.content_type).to eq("image/png")
    end

    it "follows redirects" do
      stub_request(:get, url).to_return(status: 301, headers: { "Location" => "https://cdn.example.com/photo.png" })
      stub_request(:get, "https://cdn.example.com/photo.png")
        .to_return(body: "MOVED", headers: { "Content-Type" => "image/png" })

      described_class.new(store: store).fetch!(media_item)

      expect(store.uploads["wp-content/uploads/2026/05/photo.png"][:body]).to eq("MOVED")
    end

    it "raises on a 404 so the job can retry or record it" do
      stub_request(:get, url).to_return(status: 404)

      expect { described_class.new(store: store).fetch!(media_item) }
        .to raise_error(described_class::FetchError, /404/)
    end

    it "raises when the record has no source url" do
      item = MediaItem.create!(key: "a/b.png", filename: "b.png")

      expect { described_class.new(store: store).fetch!(item) }
        .to raise_error(described_class::FetchError, /no source_url/)
    end
  end
end

RSpec.describe Wordpress::FetchMediaJob do
  let(:url) { "https://techandfi.com/wp-content/uploads/2026/05/photo.png" }
  let(:item) do
    MediaItem.create!(key: "wp-content/uploads/2026/05/photo.png", filename: "photo.png", source_url: url)
  end

  it "stores the image and counts the attempt" do
    stub_request(:get, url).to_return(body: "PNG", headers: { "Content-Type" => "image/png" })

    described_class.perform_now(item.id)

    expect(item.reload).to have_attributes(status: "stored", fetch_attempts: 1)
  end

  it "does nothing when the image is already stored" do
    item.update!(status: :stored)

    described_class.perform_now(item.id)

    expect(item.reload.fetch_attempts).to eq(0)
    expect(WebMock).not_to have_requested(:get, url)
  end

  it "records the failure reason so it is visible in the admin while Active Job backs off" do
    stub_request(:get, url).to_return(status: 500)

    # retry_on handles the error rather than letting it escape, so the record is
    # the only place the reason survives until the retries are exhausted.
    described_class.perform_now(item.id)

    expect(item.reload).to have_attributes(status: "failed")
    expect(item.fetch_error).to match(/500/)
  end

  it "schedules a retry after a failure" do
    stub_request(:get, url).to_return(status: 500)

    expect { described_class.perform_now(item.id) }
      .to have_enqueued_job(described_class).with(item.id)
  end

  it "discards quietly when the record has been deleted" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
