require "rails_helper"

RSpec.describe Themes::Registry do
  let(:builtin_root) { Pathname.new(theme_tmpdir) }
  let(:uploaded_root) { Pathname.new(theme_tmpdir) }

  before do
    allow(described_class).to receive(:builtin_root).and_return(builtin_root)
    allow(described_class).to receive(:uploaded_root).and_return(uploaded_root)
  end

  describe ".all" do
    it "finds themes in both roots and labels where each came from" do
      write_theme(slug: "shipped", parent: builtin_root)
      write_theme(slug: "downloaded", parent: uploaded_root)

      by_slug = described_class.all.index_by(&:slug)

      expect(by_slug.keys).to contain_exactly("shipped", "downloaded")
      expect(by_slug["shipped"].source).to eq(:builtin)
      expect(by_slug["downloaded"].source).to eq(:uploaded)
    end

    it "returns nothing when neither root exists" do
      allow(described_class).to receive_messages(
        builtin_root: Pathname.new("/nonexistent/builtin"),
        uploaded_root: Pathname.new("/nonexistent/uploaded")
      )

      expect(described_class.all).to eq([])
    end

    it "skips a directory that is not a valid theme, and says so in the log" do
      write_theme(slug: "good", parent: uploaded_root)
      FileUtils.mkdir_p(uploaded_root.join("junk"))
      uploaded_root.join("junk", "theme.json").write("{ broken")

      allow(Rails.logger).to receive(:warn)

      expect(described_class.all.map(&:slug)).to eq([ "good" ])
      expect(Rails.logger).to have_received(:warn).with(/junk/)
    end

    it "ignores loose files sitting in a theme root" do
      write_theme(slug: "good", parent: uploaded_root)
      uploaded_root.join("README.md").write("not a theme")

      expect(described_class.all.map(&:slug)).to eq([ "good" ])
    end

    it "sorts by name" do
      write_theme(slug: "zebra", parent: uploaded_root, manifest: { "name" => "Zebra" })
      write_theme(slug: "alpha", parent: uploaded_root, manifest: { "name" => "Alpha" })

      expect(described_class.all.map(&:name)).to eq(%w[Alpha Zebra])
    end
  end

  describe "slug collisions" do
    it "lets the built-in theme win, so an upload cannot shadow it" do
      write_theme(slug: "independent", parent: builtin_root, manifest: { "name" => "The Real One" })
      write_theme(slug: "independent", parent: uploaded_root, manifest: { "name" => "Impostor" })

      expect(described_class.find("independent").name).to eq("The Real One")
      expect(described_class.find("independent").source).to eq(:builtin)
      expect(described_class.all.size).to eq(1)
    end
  end

  describe ".find" do
    it "returns the bundle for a slug" do
      write_theme(slug: "sample", parent: uploaded_root)

      expect(described_class.find("sample").slug).to eq("sample")
    end

    it "returns nil for an unknown slug" do
      expect(described_class.find("nope")).to be_nil
    end

    it "returns nil rather than walking the filesystem for a hostile slug" do
      write_theme(slug: "sample", parent: uploaded_root)

      expect(described_class.find("../sample")).to be_nil
      expect(described_class.find("/etc")).to be_nil
    end
  end

  describe ".default" do
    it "prefers the independent theme" do
      write_theme(slug: "independent", parent: builtin_root)
      write_theme(slug: "other", parent: uploaded_root)

      expect(described_class.default.slug).to eq("independent")
    end

    it "falls back to whatever is installed" do
      write_theme(slug: "other", parent: uploaded_root)

      expect(described_class.default.slug).to eq("other")
    end

    it "is nil when nothing is installed" do
      expect(described_class.default).to be_nil
    end
  end

  describe ".builtin_slugs" do
    it "lists only the themes that ship with the app" do
      write_theme(slug: "shipped", parent: builtin_root)
      write_theme(slug: "downloaded", parent: uploaded_root)

      expect(described_class.builtin_slugs).to eq([ "shipped" ])
    end
  end

  describe "the real roots" do
    it "points at themes/ and storage/themes/" do
      allow(described_class).to receive(:builtin_root).and_call_original
      allow(described_class).to receive(:uploaded_root).and_call_original

      expect(described_class.builtin_root).to eq(Rails.root.join("themes"))
      expect(described_class.uploaded_root).to eq(Rails.root.join("storage", "themes"))
    end
  end
end

RSpec.describe "Themes::Registry caching" do
  let(:builtin_root) { Pathname.new(theme_tmpdir) }
  let(:uploaded_root) { Pathname.new(theme_tmpdir) }

  before do
    allow(Themes::Registry).to receive_messages(builtin_root: builtin_root, uploaded_root: uploaded_root)
    Themes::Registry::CACHE.clear
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  after { Themes::Registry::CACHE.clear }

  it "does not rescan the filesystem on every call in production" do
    write_theme(slug: "sample", parent: uploaded_root)
    Themes::Registry.all

    allow(Themes::Registry).to receive(:scan_all).and_call_original
    3.times { Themes::Registry.all }

    expect(Themes::Registry).not_to have_received(:scan_all)
  end

  it "notices a theme being installed" do
    write_theme(slug: "first", parent: uploaded_root)
    expect(Themes::Registry.all.map(&:slug)).to eq([ "first" ])

    # Directory mtime has a one-second resolution, so move it on explicitly
    # rather than sleeping.
    write_theme(slug: "second", parent: uploaded_root)
    later = Time.now + 5
    File.utime(later, later, uploaded_root.to_s)

    expect(Themes::Registry.all.map(&:slug)).to contain_exactly("first", "second")
  end

  it "notices a theme being uninstalled" do
    write_theme(slug: "first", parent: uploaded_root)
    write_theme(slug: "second", parent: uploaded_root)
    expect(Themes::Registry.all.size).to eq(2)

    FileUtils.remove_entry(uploaded_root.join("second"))
    later = Time.now + 5
    File.utime(later, later, uploaded_root.to_s)

    expect(Themes::Registry.all.map(&:slug)).to eq([ "first" ])
  end
end
