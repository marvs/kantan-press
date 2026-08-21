require "rails_helper"

RSpec.describe Themes::Uninstaller do
  let(:uploaded_root) { Pathname.new(theme_tmpdir).join("themes") }
  let(:builtin_root) { Pathname.new(theme_tmpdir).join("builtin") }

  before do
    FileUtils.mkdir_p([ uploaded_root, builtin_root ])
    allow(Themes::Registry).to receive_messages(builtin_root: builtin_root, uploaded_root: uploaded_root)
  end

  it "removes the theme's directory and its row" do
    write_theme(slug: "downloaded", parent: uploaded_root)
    write_theme(slug: "independent", parent: builtin_root)
    create(:theme, slug: "downloaded", settings: {})

    result = described_class.call("downloaded")

    expect(result).to be_success
    expect(uploaded_root.join("downloaded")).not_to exist
    expect(Theme.where(slug: "downloaded")).to be_empty
  end

  it "refuses to uninstall the active theme" do
    write_theme(slug: "downloaded", parent: uploaded_root)
    create(:theme, slug: "downloaded", active: true)

    result = described_class.call("downloaded")

    expect(result).not_to be_success
    expect(result.errors.join).to match(/active theme/)
    expect(uploaded_root.join("downloaded")).to exist
  end

  it "refuses to uninstall a theme that ships with the app" do
    write_theme(slug: "independent", parent: builtin_root)

    result = described_class.call("independent")

    expect(result).not_to be_success
    expect(result.errors.join).to match(/ships with the app/)
    expect(builtin_root.join("independent")).to exist
  end

  it "refuses a theme that is not installed" do
    expect(described_class.call("nope")).not_to be_success
  end

  it "refuses a hostile slug without touching the filesystem" do
    write_theme(slug: "downloaded", parent: uploaded_root)

    expect(described_class.call("../downloaded")).not_to be_success
    expect(uploaded_root.join("downloaded")).to exist
  end
end
