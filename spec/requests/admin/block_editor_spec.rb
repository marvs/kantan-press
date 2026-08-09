require "rails_helper"

RSpec.describe "the block editor" do
  before { sign_in }

  describe "the post form" do
    it "loads React before the editor bundle, which requires it as a global" do
      get new_admin_post_path

      react = response.body =~ %r{src="/assets/react-[^"]+\.js"}
      editor = response.body =~ %r{src="/assets/isolated-block-editor-[^"]+\.js"}

      expect(react).to be_present
      expect(editor).to be_present
      expect(react).to be < editor
    end

    it "includes the Gutenberg stylesheets" do
      get new_admin_post_path

      expect(response.body).to match(%r{href="/assets/core-[^"]+\.css"})
      expect(response.body).to match(%r{href="/assets/isolated-block-editor-[^"]+\.css"})
    end

    it "renders the content field with the id the editor attaches to" do
      get new_admin_post_path

      expect(response.body).to include('id="post_content"')
      expect(response.body).to include("data-editor-placeholder")
    end

    it "keeps the editor off pages that have no content field" do
      get admin_posts_path

      expect(response.body).not_to include("isolated-block-editor")
    end

    it "round-trips existing block markup into the textarea unescaped-on-save" do
      post_record = create(:post, content: "<!-- wp:paragraph -->\n<p>Hi</p>\n<!-- /wp:paragraph -->")

      get edit_admin_post_path(post_record)

      # The textarea holds the markup HTML-escaped; the browser un-escapes it
      # back to the original string, which is what attachEditor parses.
      expect(response.body).to include("&lt;!-- wp:paragraph --&gt;")
    end
  end

  describe "POST /admin/media_items/upload" do
    def png_upload(filename: "photo.png", type: "image/png")
      Rack::Test::UploadedFile.new(
        StringIO.new("\x89PNG\r\n\x1a\n binary"), type, original_filename: filename
      )
    end

    it "stores the file and returns the shape Gutenberg's image block expects" do
      post upload_admin_media_items_path, params: { file: png_upload }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body).to include("id", "url", "alt", "mime", "type", "subtype")
      expect(body["mime"]).to eq("image/png")
      expect(body["type"]).to eq("image")
    end

    it "files uploads under the WordPress uploads convention" do
      travel_to Time.utc(2026, 5, 9) do
        post upload_admin_media_items_path, params: { file: png_upload }
      end

      expect(MediaItem.last.key).to eq("wp-content/uploads/2026/05/photo.png")
    end

    it "marks the record stored, since the upload already happened inline" do
      post upload_admin_media_items_path, params: { file: png_upload }

      expect(MediaItem.last).to be_stored
    end

    it "puts the bytes in the object store under that key" do
      post upload_admin_media_items_path, params: { file: png_upload }

      expect(ObjectStore.current.exist?(MediaItem.last.key)).to be(true)
    end

    it "does not overwrite an existing key" do
      post upload_admin_media_items_path, params: { file: png_upload }
      first = MediaItem.last.key

      post upload_admin_media_items_path, params: { file: png_upload }

      expect(MediaItem.last.key).not_to eq(first)
      expect(MediaItem.count).to eq(2)
    end

    it "normalises the filename into the key" do
      post upload_admin_media_items_path, params: { file: png_upload(filename: "My Photo (1).PNG") }

      expect(MediaItem.last.key).to end_with("my-photo-1.png")
    end

    it "rejects a type that is not an image" do
      post upload_admin_media_items_path,
           params: { file: Rack::Test::UploadedFile.new(StringIO.new("x"), "application/pdf", original_filename: "a.pdf") }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to match(/not an allowed image type/)
    end

    it "rejects a request with no file" do
      post upload_admin_media_items_path

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires a signed-in user" do
      delete session_path
      post upload_admin_media_items_path, params: { file: png_upload }

      expect(response).to redirect_to(new_session_path)
    end
  end
end
