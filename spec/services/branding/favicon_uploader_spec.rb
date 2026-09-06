require "rails_helper"

RSpec.describe Branding::FaviconUploader do
  before { favicon_root }

  def upload(filename, bytes, type: nil)
    described_class.call(uploaded(filename, bytes, type: type))
  end

  describe "what it accepts" do
    it "stores a PNG and records it as the live favicon" do
      result = upload("logo.png", png_bytes)

      expect(result).to be_success
      expect(favicon_root.join("favicon.png")).to exist
      expect(Branding::Favicon.current.content_type).to eq("image/png")
    end

    it "stores an SVG" do
      result = upload("logo.svg", svg_bytes)

      expect(result).to be_success
      expect(Branding::Favicon.current.content_type).to eq("image/svg+xml")
    end

    it "leaves no orphan behind when the format changes" do
      upload("logo.svg", svg_bytes)
      Current.reset

      upload("logo.png", png_bytes)

      expect(favicon_root.join("favicon.svg")).not_to exist
      expect(favicon_root.join("favicon.png")).to exist
    end
  end

  # The extension and the browser's content type are both supplied by whoever
  # is uploading. The file's own first bytes are not.
  describe "what it refuses" do
    it "refuses a format that is not PNG or SVG" do
      result = upload("photo.jpg", jpeg_bytes)

      expect(result).not_to be_success
      expect(result.errors.first).to match(/PNG or an SVG/)
    end

    it "refuses a file whose bytes disagree with its extension" do
      result = upload("logo.png", "this is not a png at all")

      expect(result).not_to be_success
      expect(result.errors.first).to match(/not a PNG/)
    end

    it "refuses an HTML document dressed as an SVG" do
      result = upload("logo.svg", "<html><body><script>alert(1)</script></body></html>")

      expect(result).not_to be_success
      expect(result.errors.first).to match(/not an SVG/)
    end

    it "refuses a PNG claiming a .svg extension" do
      expect(upload("logo.svg", png_bytes)).not_to be_success
    end

    it "refuses a file larger than the cap" do
      result = upload("logo.png", png_bytes + ("\x00".b * described_class::MAX_BYTES))

      expect(result).not_to be_success
      expect(result.errors.first).to match(/larger than/)
    end

    it "refuses a PNG with absurd dimensions" do
      oversized = described_class::MAX_PIXELS + 1
      result = upload("logo.png", png_bytes(width: oversized, height: 8))

      expect(result).not_to be_success
      expect(result.errors.first).to match(/#{described_class::MAX_PIXELS}/)
    end

    it "refuses an empty submission" do
      expect(described_class.call(nil)).not_to be_success
    end

    # params[:favicon] is whatever was posted. A form field carrying a plain
    # string instead of a file must be refused, not raise NoMethodError.
    it "refuses something that is not an uploaded file at all" do
      expect { described_class.call("not-a-file") }.not_to raise_error
      expect(described_class.call("not-a-file")).not_to be_success
    end

    # The point of a size cap is not to pull the file into memory in order to
    # discover it is too big. Themes::Installer checks the same way.
    it "refuses an oversized upload without reading it" do
      file = uploaded("logo.png", png_bytes)
      allow(file).to receive(:size).and_return(described_class::MAX_BYTES + 1)
      expect(file).not_to receive(:read)

      expect(described_class.call(file)).not_to be_success
    end

    # Nothing is written until every check has passed, so a bad upload cannot
    # take out the favicon that was already working.
    it "leaves the favicon that was already there untouched" do
      install_favicon(extension: ".png")
      Current.reset

      expect(upload("logo.svg", "<html>nope</html>")).not_to be_success
      expect(Branding::Favicon.current.extension).to eq(".png")
      expect(favicon_root.join("favicon.png")).to exist
    end
  end
end
