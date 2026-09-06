require "rails_helper"

RSpec.describe Branding::Favicon do
  before { favicon_root }

  describe ".current" do
    it "is nil on an install where nobody has uploaded one" do
      expect(described_class.current).to be_nil
    end

    it "describes an uploaded PNG" do
      install_favicon(extension: ".png")

      favicon = described_class.current

      expect(favicon.extension).to eq(".png")
      expect(favicon.content_type).to eq("image/png")
      expect(favicon.path).to eq(favicon_root.join("favicon.png"))
    end

    it "describes an uploaded SVG" do
      install_favicon(extension: ".svg")

      expect(described_class.current.content_type).to eq("image/svg+xml")
    end

    # The database and the disk can drift — a restored backup, a volume that
    # did not mount. A setting with no file behind it must not produce a link
    # to a 404.
    it "is nil when the setting names a file that is not there" do
      SiteSetting.set(described_class::SETTING, ".png")

      expect(described_class.current).to be_nil
    end
  end

  describe "#url" do
    it "carries a cache-busting version, since the path never changes" do
      install_favicon

      expect(described_class.current.url).to match(%r{\A/favicon\?v=\d+\z})
    end

    it "changes when the file changes, so a replacement is not served from cache" do
      path = install_favicon
      before = described_class.current.url

      later = Time.now + 60
      File.utime(later, later, path.to_s)
      Current.favicon = nil

      expect(described_class.current.url).not_to eq(before)
    end
  end

  describe ".remove" do
    it "deletes the file and the setting, so the shipped default comes back" do
      path = install_favicon
      Current.favicon = nil

      described_class.remove

      expect(path).not_to exist
      expect(SiteSetting.get(described_class::SETTING)).to be_nil
      expect(described_class.current).to be_nil
    end

    it "is safe to call when there is nothing to remove" do
      expect { described_class.remove }.not_to raise_error
    end
  end
end
