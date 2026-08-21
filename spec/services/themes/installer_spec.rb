require "rails_helper"

RSpec.describe Themes::Installer do
  let(:uploaded_root) { Pathname.new(theme_tmpdir).join("themes") }
  let(:builtin_root) { Pathname.new(theme_tmpdir).join("builtin") }

  before do
    FileUtils.mkdir_p(builtin_root)
    allow(Themes::Registry).to receive_messages(builtin_root: builtin_root, uploaded_root: uploaded_root)
  end

  def install(entries, **options)
    described_class.call(build_theme_zip(entries), **options)
  end

  describe "a well-formed theme" do
    it "installs it and reports the bundle" do
      result = install(zip_entries_for(slug: "downloaded", manifest: { "name" => "Downloaded" }))

      expect(result).to be_success
      expect(result.bundle.slug).to eq("downloaded")
      expect(result.bundle.name).to eq("Downloaded")
      expect(result.bundle.source).to eq(:uploaded)
      expect(uploaded_root.join("downloaded", "theme.json")).to be_file
      expect(uploaded_root.join("downloaded", "templates", "post.liquid")).to be_file
      expect(uploaded_root.join("downloaded", "assets", "theme.css").read).to eq("body{}")
    end

    it "makes the theme visible to the registry straight away" do
      install(zip_entries_for(slug: "downloaded"))

      expect(Themes::Registry.find("downloaded")).to be_present
    end

    it "tolerates the single wrapper directory that GitHub zips add" do
      result = install(zip_entries_for(slug: "downloaded", prefix: "kantan-theme-downloaded-main/"))

      expect(result).to be_success
      expect(uploaded_root.join("downloaded", "theme.json")).to be_file
    end

    it "ignores the junk macOS puts in a zip" do
      entries = zip_entries_for(slug: "downloaded").merge(
        "__MACOSX/._theme.json" => "junk",
        ".DS_Store" => "junk",
        "assets/._theme.css" => "junk"
      )

      expect(install(entries)).to be_success
      expect(uploaded_root.join("downloaded", "__MACOSX")).not_to exist
      expect(uploaded_root.join("downloaded", ".DS_Store")).not_to exist
    end

    it "keeps a licence file that ships alongside the fonts" do
      entries = zip_entries_for(slug: "downloaded", extra: { "assets/fonts/LICENSE" => "OFL text" })

      expect(install(entries)).to be_success
      expect(uploaded_root.join("downloaded", "assets", "fonts", "LICENSE")).to be_file
    end
  end

  describe "refusing a hostile archive" do
    it "refuses an entry that climbs out of the theme directory" do
      entries = zip_entries_for(slug: "downloaded").merge("../../../etc/cron.d/pwned" => "* * * * * root sh")

      result = install(entries)

      expect(result).not_to be_success
      expect(result.errors.join).to match(/outside the theme/i)
    end

    # rubyzip refuses to even build an entry whose name starts with "/", so the
    # absolute-path cases that can actually reach us are the Windows ones.
    it "refuses a Windows absolute path or a backslash traversal" do
      expect(install(zip_entries_for(slug: "downloaded").merge("C:evil.css" => "x"))).not_to be_success
      expect(install(zip_entries_for(slug: "downloaded").merge(%q(..\..\evil.css) => "x"))).not_to be_success
    end

    it "refuses a symlink entry" do
      secret = Pathname.new(theme_tmpdir).join("secret.css")
      secret.write("secret")
      link = Pathname.new(theme_tmpdir).join("escape.css")
      File.symlink(secret.to_s, link.to_s)

      result = install(zip_entries_for(slug: "downloaded").merge("assets/escape.css" => link))

      expect(result).not_to be_success
      expect(result.errors.join).to match(/symlink/i)
    end

    it "refuses an executable file" do
      entries = zip_entries_for(slug: "downloaded").merge("templates/hack.rb" => "system('rm -rf /')")

      result = install(entries)

      expect(result).not_to be_success
      expect(result.errors.join).to match(/hack\.rb/)
    end

    it "refuses a zip bomb by its uncompressed size, not its compressed size" do
      stub_const("#{described_class}::MAX_UNCOMPRESSED_BYTES", 2_000)
      entries = zip_entries_for(slug: "downloaded").merge("assets/big.css" => "0" * 100_000)

      result = install(entries)

      expect(result).not_to be_success
      expect(result.errors.join).to match(/too large/i)
    end

    it "refuses an archive with too many entries" do
      stub_const("#{described_class}::MAX_ENTRIES", 3)

      expect(install(zip_entries_for(slug: "downloaded"))).not_to be_success
    end

    it "refuses an upload that is too big to bother opening" do
      stub_const("#{described_class}::MAX_UPLOAD_BYTES", 10)

      expect(install(zip_entries_for(slug: "downloaded"))).not_to be_success
    end

    it "refuses something that is not a zip at all" do
      path = Pathname.new(theme_tmpdir).join("not.zip")
      path.write("I am a jpeg, honest")

      result = described_class.call(path)

      expect(result).not_to be_success
      expect(result.errors.join).to match(/zip/i)
    end
  end

  describe "refusing an invalid theme" do
    it "refuses an archive with no theme.json" do
      entries = zip_entries_for(slug: "downloaded").except("theme.json")

      result = install(entries)

      expect(result).not_to be_success
      expect(result.errors.join).to match(/theme\.json/)
    end

    it "refuses a manifest that is not valid JSON" do
      entries = zip_entries_for(slug: "downloaded").merge("theme.json" => "{ nope")

      expect(install(entries)).not_to be_success
    end

    it "refuses a theme that is missing a required template" do
      entries = zip_entries_for(slug: "downloaded").except("templates/layout.liquid")

      result = install(entries)

      expect(result).not_to be_success
      expect(result.errors.join).to match(/layout/)
    end

    it "refuses a slug that would shadow a theme shipped with the app" do
      write_theme(slug: "independent", parent: builtin_root)

      result = install(zip_entries_for(slug: "independent"))

      expect(result).not_to be_success
      expect(result.errors.join).to match(/ships with/i)
    end

    it "refuses a slug that is not a safe directory name" do
      entries = zip_entries_for(slug: "downloaded")
      entries["theme.json"] = JSON.generate(
        ThemeFixtures::DEFAULT_MANIFEST.merge("slug" => "../escape")
      )

      expect(install(entries)).not_to be_success
    end
  end

  describe "reinstalling" do
    it "refuses to overwrite an installed theme unless asked" do
      install(zip_entries_for(slug: "downloaded", manifest: { "version" => "1.0.0" }))

      result = install(zip_entries_for(slug: "downloaded", manifest: { "version" => "2.0.0" }))

      expect(result).not_to be_success
      expect(result.errors.join).to match(/already installed/i)
      expect(Themes::Registry.find("downloaded").version).to eq("1.0.0")
    end

    it "replaces it when overwrite is asked for" do
      install(zip_entries_for(slug: "downloaded", manifest: { "version" => "1.0.0" }))

      result = install(zip_entries_for(slug: "downloaded", manifest: { "version" => "2.0.0" }), overwrite: true)

      expect(result).to be_success
      expect(Themes::Registry.find("downloaded").version).to eq("2.0.0")
    end
  end

  describe "a failed install" do
    it "leaves nothing behind" do
      entries = zip_entries_for(slug: "downloaded").merge("templates/hack.rb" => "boom")

      install(entries)

      expect(uploaded_root.join("downloaded")).not_to exist
      expect(uploaded_root.children).to eq([]) if uploaded_root.exist?
    end

    it "puts the old theme back when the final move fails" do
      fail_move = false
      allow(FileUtils).to receive(:mv).and_wrap_original do |original, source, dest, **options|
        raise Errno::ENOSPC if fail_move && File.basename(source.to_s) == "downloaded"

        original.call(source, dest, **options)
      end

      install(zip_entries_for(slug: "downloaded", manifest: { "version" => "1.0.0" }))
      fail_move = true

      result = install(zip_entries_for(slug: "downloaded", manifest: { "version" => "2.0.0" }), overwrite: true)

      expect(result).not_to be_success
      expect(Themes::Registry.find("downloaded").version).to eq("1.0.0")
    end

    it "leaves an already-installed theme untouched" do
      install(zip_entries_for(slug: "downloaded", manifest: { "version" => "1.0.0" }))
      bad = zip_entries_for(slug: "downloaded", manifest: { "version" => "2.0.0" }).merge("evil.rb" => "boom")

      install(bad, overwrite: true)

      expect(Themes::Registry.find("downloaded").version).to eq("1.0.0")
    end
  end
end
