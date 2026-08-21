require "rails_helper"

RSpec.describe Theme do
  let(:themes_root) { Pathname.new(theme_tmpdir) }

  # Themes are read off disk, so the model specs need real directories rather
  # than only rows.
  before do
    allow(Themes::Registry).to receive_messages(builtin_root: themes_root, uploaded_root: themes_root)
  end

  def install(slug, settings: [])
    write_theme(slug: slug, parent: themes_root, manifest: { "settings" => settings })
  end

  let(:colour_setting) do
    { "key" => "accent_color", "type" => "color", "label" => "Accent", "default" => "#57ad68" }
  end
  let(:font_setting) do
    { "key" => "body_font", "type" => "select", "label" => "Body font", "default" => "serif",
      "options" => [ { "value" => "serif", "label" => "Serif" }, { "value" => "sans", "label" => "Sans" } ] }
  end
  let(:word_count_setting) do
    { "key" => "show_word_count", "type" => "boolean", "label" => "Word count", "default" => true }
  end

  describe "validations" do
    it "requires a theme that is actually installed" do
      theme = build(:theme, slug: "not-installed")

      expect(theme).not_to be_valid
      expect(theme.errors[:slug].join).to match(/installed/i)
    end

    it "accepts an installed theme" do
      install("sample")

      expect(build(:theme, slug: "sample")).to be_valid
    end

    it "refuses a slug that is not a safe path segment" do
      expect(build(:theme, slug: "../etc")).not_to be_valid
    end

    it "refuses a duplicate slug" do
      install("sample")
      create(:theme, slug: "sample")

      expect(build(:theme, slug: "sample")).not_to be_valid
    end
  end

  describe "settings" do
    before { install("sample", settings: [ colour_setting, font_setting, word_count_setting ]) }

    it "fills in the schema defaults" do
      theme = create(:theme, slug: "sample")

      expect(theme.settings_with_defaults).to eq(
        "accent_color" => "#57ad68", "body_font" => "serif", "show_word_count" => true
      )
    end

    it "lets a stored value override its default" do
      theme = create(:theme, slug: "sample", settings: { "accent_color" => "#112233" })

      expect(theme.settings_with_defaults).to include("accent_color" => "#112233", "body_font" => "serif")
    end

    it "rejects a key the theme never declared" do
      theme = build(:theme, slug: "sample", settings: { "evil" => "1" })

      expect(theme).not_to be_valid
      expect(theme.errors[:settings].join).to match(/evil/)
    end

    it "rejects a colour that is not #rrggbb" do
      theme = build(:theme, slug: "sample", settings: { "accent_color" => "red; }" })

      expect(theme).not_to be_valid
    end

    it "rejects a select value outside its options" do
      theme = build(:theme, slug: "sample", settings: { "body_font" => "comic-sans" })

      expect(theme).not_to be_valid
    end

    it "accepts valid values for every declared type" do
      theme = build(:theme, slug: "sample",
                    settings: { "accent_color" => "#ffffff", "body_font" => "sans", "show_word_count" => false })

      expect(theme).to be_valid
    end
  end

  describe "#assign_settings" do
    before { install("sample", settings: [ colour_setting, word_count_setting ]) }

    it "casts form strings to the declared types" do
      theme = create(:theme, slug: "sample")

      theme.assign_settings({ "accent_color" => "  #ABCDEF  ", "show_word_count" => "0" })

      expect(theme.settings).to eq("accent_color" => "#abcdef", "show_word_count" => false)
      expect(theme).to be_valid
    end

    it "records a submitted key the theme does not declare" do
      theme = create(:theme, slug: "sample")

      theme.assign_settings({ "accent_color" => "#ffffff" }, submitted_keys: %w[accent_color rogue])

      expect(theme).not_to be_valid
      expect(theme.errors[:settings].join).to match(/rogue/)
    end

    it "resets to the schema defaults" do
      theme = create(:theme, slug: "sample", settings: { "accent_color" => "#000000" })

      theme.reset_settings!

      expect(theme.reload.settings).to eq({})
      expect(theme.settings_with_defaults).to include("accent_color" => "#57ad68")
    end
  end

  describe "#activate!" do
    before do
      install("one")
      install("two")
    end

    it "makes this theme active and deactivates the others" do
      first = create(:theme, slug: "one", active: true)
      second = create(:theme, slug: "two")

      second.activate!

      expect(second.reload).to be_active
      expect(first.reload).not_to be_active
    end

    it "leaves exactly one active row" do
      create(:theme, slug: "one", active: true)
      create(:theme, slug: "two").activate!

      expect(described_class.where(active: true).count).to eq(1)
    end
  end

  describe ".selection" do
    it "returns the active theme and its merged settings" do
      install("chosen", settings: [ colour_setting ])
      install("independent")
      create(:theme, slug: "chosen", active: true, settings: { "accent_color" => "#101010" })

      selection = described_class.selection

      expect(selection.bundle.slug).to eq("chosen")
      expect(selection.settings).to eq("accent_color" => "#101010")
    end

    it "falls back to the default theme when no row is active" do
      install("independent")

      expect(described_class.selection.bundle.slug).to eq("independent")
      expect(described_class.selection.theme).to be_nil
    end

    it "applies settings saved for the default theme even though no row is active" do
      install("independent", settings: [ colour_setting ])
      create(:theme, slug: "independent", active: false, settings: { "accent_color" => "#101010" })

      selection = described_class.selection

      expect(selection.bundle.slug).to eq("independent")
      expect(selection.settings).to eq("accent_color" => "#101010")
    end

    it "falls back when the active theme's directory has been deleted" do
      install("independent")
      install("gone")
      create(:theme, slug: "gone", active: true)
      FileUtils.remove_entry(themes_root.join("gone"))

      expect(described_class.selection.bundle.slug).to eq("independent")
    end

    it "is nil when no theme is installed at all" do
      expect(described_class.selection).to be_nil
    end
  end
end
