require "rails_helper"

RSpec.describe Themes::Bundle do
  def bundle_for(dir, source: :uploaded)
    described_class.new(dir, source: source)
  end

  describe "manifest" do
    it "reads name, version and author from theme.json" do
      dir = write_theme(slug: "sample", manifest: { "name" => "Sample Theme", "version" => "2.1.0", "author" => "Raam" })

      bundle = bundle_for(dir)

      expect(bundle).to be_valid
      expect(bundle.slug).to eq("sample")
      expect(bundle.name).to eq("Sample Theme")
      expect(bundle.version).to eq("2.1.0")
      expect(bundle.author).to eq("Raam")
      expect(bundle.source).to eq(:uploaded)
    end

    it "is invalid when theme.json is missing" do
      dir = write_theme(manifest: nil)

      expect(bundle_for(dir)).not_to be_valid
      expect(bundle_for(dir).errors.join).to match(/theme\.json/i)
    end

    it "is invalid when theme.json is not JSON" do
      dir = write_theme
      write_raw_manifest(dir, "{ not json")

      expect(bundle_for(dir)).not_to be_valid
      expect(bundle_for(dir).errors.join).to match(/json/i)
    end

    it "is invalid when the theme API version is unknown" do
      dir = write_theme(manifest: { "kantan_theme_api" => 99 })

      expect(bundle_for(dir)).not_to be_valid
      expect(bundle_for(dir).errors.join).to match(/kantan_theme_api/)
    end

    it "is invalid when the manifest slug does not match the directory name" do
      dir = write_theme(slug: "sample")
      write_raw_manifest(dir, JSON.generate(ThemeFixtures::DEFAULT_MANIFEST.merge("slug" => "different")))

      expect(bundle_for(dir)).not_to be_valid
      expect(bundle_for(dir).errors.join).to match(/slug/i)
    end

    it "is invalid when the slug is not a safe path segment" do
      dir = write_theme(slug: "sample")
      write_raw_manifest(dir, JSON.generate(ThemeFixtures::DEFAULT_MANIFEST.merge("slug" => "../evil")))

      expect(bundle_for(dir)).not_to be_valid
    end

    it "is invalid when a required template is missing" do
      dir = write_theme(templates: { "layout" => nil })

      expect(bundle_for(dir)).not_to be_valid
      expect(bundle_for(dir).errors.join).to match(/layout/)
    end
  end

  describe "#settings_schema" do
    it "builds settings from the manifest" do
      dir = write_theme(manifest: {
        "settings" => [
          { "key" => "accent_color", "type" => "color", "label" => "Accent", "default" => "#57ad68" },
          { "key" => "show_word_count", "type" => "boolean", "label" => "Word count", "default" => true },
          { "key" => "body_font", "type" => "select", "label" => "Body font", "default" => "serif",
            "options" => [ { "value" => "serif", "label" => "Serif" }, { "value" => "sans", "label" => "Sans" } ] }
        ]
      })

      schema = bundle_for(dir).settings_schema

      expect(schema.map(&:key)).to eq(%w[accent_color show_word_count body_font])
      expect(schema.first.type).to eq("color")
      expect(schema.last.option_values).to eq(%w[serif sans])
    end

    it "exposes the defaults as a hash" do
      dir = write_theme(manifest: {
        "settings" => [ { "key" => "accent_color", "type" => "color", "label" => "Accent", "default" => "#57ad68" } ]
      })

      expect(bundle_for(dir).default_settings).to eq("accent_color" => "#57ad68")
    end

    it "is invalid when a setting declares an unsupported type" do
      dir = write_theme(manifest: {
        "settings" => [ { "key" => "spacing", "type" => "slider", "label" => "Spacing" } ]
      })

      expect(bundle_for(dir)).not_to be_valid
      expect(bundle_for(dir).errors.join).to match(/slider/)
    end

    it "is invalid when a select declares no options" do
      dir = write_theme(manifest: {
        "settings" => [ { "key" => "body_font", "type" => "select", "label" => "Font" } ]
      })

      expect(bundle_for(dir)).not_to be_valid
    end

    it "has an empty schema when the manifest declares no settings" do
      expect(bundle_for(write_theme).settings_schema).to eq([])
    end
  end

  describe "#template" do
    it "returns the template source" do
      dir = write_theme(templates: { "post" => "Hello {{ post.title }}" })

      expect(bundle_for(dir).template("post")).to eq("Hello {{ post.title }}")
    end

    it "raises for a template the theme does not ship" do
      expect { bundle_for(write_theme).template("nope") }.to raise_error(Themes::Bundle::MissingTemplate)
    end

    it "refuses a template name that tries to escape the templates directory" do
      expect { bundle_for(write_theme).template("../theme") }.to raise_error(Themes::Bundle::MissingTemplate)
    end
  end

  describe "#asset_path" do
    it "resolves a file inside the assets directory" do
      dir = write_theme(assets: { "theme.css" => "body{}" })

      expect(bundle_for(dir).asset_path("theme.css").read).to eq("body{}")
    end

    it "resolves a nested file" do
      dir = write_theme(assets: { "fonts/pt-sans.woff2" => "binary" })

      expect(bundle_for(dir).asset_path("fonts/pt-sans.woff2")).to be_present
    end

    it "refuses a traversal path" do
      dir = write_theme(assets: { "theme.css" => "body{}" })

      expect(bundle_for(dir).asset_path("../theme.json")).to be_nil
      expect(bundle_for(dir).asset_path("../../etc/passwd")).to be_nil
    end

    it "refuses an absolute path" do
      dir = write_theme(assets: { "theme.css" => "body{}" })

      expect(bundle_for(dir).asset_path("/etc/passwd")).to be_nil
    end

    it "refuses a symlink that points outside the theme" do
      dir = write_theme(assets: { "theme.css" => "body{}" })
      outside = Pathname.new(theme_tmpdir).join("secret.css")
      outside.write("secret")
      File.symlink(outside.to_s, dir.join("assets", "escape.css").to_s)

      expect(bundle_for(dir).asset_path("escape.css")).to be_nil
    end

    it "refuses an extension that is not a web asset" do
      dir = write_theme(assets: { "config.rb" => "puts 1" })

      expect(bundle_for(dir).asset_path("config.rb")).to be_nil
    end

    it "refuses a path containing a null byte" do
      dir = write_theme(assets: { "theme.css" => "body{}" })

      expect(bundle_for(dir).asset_path("theme.css\0.png")).to be_nil
    end

    it "returns nil for a file that does not exist" do
      expect(bundle_for(write_theme).asset_path("missing.css")).to be_nil
    end
  end

  describe "#asset_version" do
    it "changes when the file changes" do
      dir = write_theme(assets: { "theme.css" => "body{}" })
      bundle = bundle_for(dir)
      before = bundle.asset_version("theme.css")

      dir.join("assets", "theme.css").write("body{color:red}")
      later = Time.now + 5
      File.utime(later, later, dir.join("assets", "theme.css").to_s)

      expect(bundle.asset_version("theme.css")).not_to eq(before)
    end
  end
end
