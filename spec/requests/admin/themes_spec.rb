require "rails_helper"

RSpec.describe "Admin::Themes" do
  let(:builtin_root) { Pathname.new(theme_tmpdir).join("builtin") }
  let(:uploaded_root) { Pathname.new(theme_tmpdir).join("themes") }

  let(:accent) { { "key" => "accent_color", "type" => "color", "label" => "Accent colour", "default" => "#57ad68" } }
  let(:word_count) { { "key" => "show_word_count", "type" => "boolean", "label" => "Show word count", "default" => true } }
  let(:body_font) do
    { "key" => "body_font", "type" => "select", "label" => "Body font", "default" => "serif",
      "options" => [ { "value" => "serif", "label" => "Serif" }, { "value" => "sans", "label" => "Sans" } ] }
  end

  before do
    FileUtils.mkdir_p([ builtin_root, uploaded_root ])
    allow(Themes::Registry).to receive_messages(builtin_root: builtin_root, uploaded_root: uploaded_root)
    write_theme(slug: "independent", parent: builtin_root,
                manifest: { "name" => "Independent", "settings" => [ accent, word_count, body_font ] })
  end

  describe "authentication" do
    it "keeps every themes action behind the login" do
      get admin_themes_path
      expect(response).to redirect_to(new_session_path)

      post activate_admin_theme_path("independent")
      expect(response).to redirect_to(new_session_path)

      get edit_admin_theme_path("independent")
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when signed in" do
    before { sign_in }

    describe "GET index" do
      it "lists installed themes and marks the active one" do
        write_theme(slug: "downloaded", parent: uploaded_root, manifest: { "name" => "Downloaded" })

        get admin_themes_path

        expect(response.body).to include("Independent", "Downloaded")
      end

      it "treats the default theme as active when nothing has been chosen" do
        get admin_themes_path

        expect(response.body).to match(/Independent/)
        expect(response.body).to include("Active")
      end

      it "shows a screenshot, and the url it builds actually serves one" do
        builtin_root.join("independent", "screenshot.svg")
                    .write("<svg xmlns='http://www.w3.org/2000/svg'/>")

        get admin_themes_path
        expect(response.body).to include(theme_screenshot_path("independent"))

        get theme_screenshot_path("independent")
        expect(response).to have_http_status(:ok)
      end

      it "says so when a theme ships no screenshot" do
        get admin_themes_path

        expect(response.body).to include("No screenshot")
      end

      it "appears in the admin navigation" do
        get admin_posts_path

        expect(response.body).to include(admin_themes_path)
      end
    end

    describe "activating" do
      before { write_theme(slug: "downloaded", parent: uploaded_root, manifest: { "name" => "Downloaded" }) }

      it "makes a theme active" do
        post activate_admin_theme_path("downloaded")

        expect(response).to redirect_to(admin_themes_path)
        expect(Theme.find_by(slug: "downloaded")).to be_active
        expect(Theme.selection.bundle.slug).to eq("downloaded")
      end

      it "leaves only one theme active" do
        post activate_admin_theme_path("downloaded")
        post activate_admin_theme_path("independent")

        expect(Theme.where(active: true).pluck(:slug)).to eq([ "independent" ])
      end

      it "refuses a theme that is not installed" do
        post activate_admin_theme_path("ghost")

        expect(response).to redirect_to(admin_themes_path)
        expect(Theme.count).to eq(0)
      end
    end

    describe "installing a zip" do
      def upload(zip_path, overwrite: nil)
        post admin_themes_path, params: {
          file: Rack::Test::UploadedFile.new(zip_path.to_s, "application/zip"),
          overwrite: overwrite
        }.compact
      end

      it "installs a valid theme" do
        upload(build_theme_zip(zip_entries_for(slug: "downloaded", manifest: { "name" => "Downloaded" })))

        expect(response).to redirect_to(admin_themes_path)
        expect(Themes::Registry.find("downloaded")).to be_present
      end

      it "re-renders with the reason when the archive is refused" do
        entries = zip_entries_for(slug: "downloaded").merge("templates/hack.rb" => "system('rm -rf /')")

        upload(build_theme_zip(entries))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("hack.rb")
        expect(Themes::Registry.find("downloaded")).to be_nil
      end

      it "asks for a file when none was chosen" do
        post admin_themes_path

        expect(response).to redirect_to(admin_themes_path)
        expect(flash[:alert]).to be_present
      end

      it "refuses to overwrite an installed theme unless asked, then allows it" do
        upload(build_theme_zip(zip_entries_for(slug: "downloaded", manifest: { "version" => "1.0.0" })))

        upload(build_theme_zip(zip_entries_for(slug: "downloaded", manifest: { "version" => "2.0.0" })))
        expect(Themes::Registry.find("downloaded").version).to eq("1.0.0")

        upload(build_theme_zip(zip_entries_for(slug: "downloaded", manifest: { "version" => "2.0.0" })), overwrite: "1")
        expect(Themes::Registry.find("downloaded").version).to eq("2.0.0")
      end
    end

    describe "uninstalling" do
      before { write_theme(slug: "downloaded", parent: uploaded_root, manifest: { "name" => "Downloaded" }) }

      it "removes an uploaded theme" do
        delete admin_theme_path("downloaded")

        expect(response).to redirect_to(admin_themes_path)
        expect(Themes::Registry.find("downloaded")).to be_nil
      end

      it "refuses to remove the active theme" do
        post activate_admin_theme_path("downloaded")

        delete admin_theme_path("downloaded")

        expect(flash[:alert]).to match(/active theme/)
        expect(Themes::Registry.find("downloaded")).to be_present
      end

      it "refuses to remove a theme that ships with the app" do
        delete admin_theme_path("independent")

        expect(flash[:alert]).to match(/ships with the app/)
        expect(Themes::Registry.find("independent")).to be_present
      end
    end

    describe "settings" do
      it "renders a field for every setting the theme declares" do
        get edit_admin_theme_path("independent")

        expect(response.body).to include("Accent colour", "Show word count", "Body font")
        expect(response.body).to include('value="#57ad68"')
        expect(response.body).to include("Serif", "Sans")
      end

      it "saves valid values" do
        patch admin_theme_path("independent"),
              params: { settings: { accent_color: "#101010", body_font: "sans", show_word_count: "0" } }

        expect(response).to redirect_to(edit_admin_theme_path("independent"))
        expect(Theme.find_by(slug: "independent").settings)
          .to eq("accent_color" => "#101010", "body_font" => "sans", "show_word_count" => false)
      end

      it "rejects a colour that is not a colour" do
        patch admin_theme_path("independent"), params: { settings: { accent_color: "red; background:url(x)" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Theme.find_by(slug: "independent")&.settings).to be_blank
      end

      it "rejects a select value outside the declared options" do
        patch admin_theme_path("independent"), params: { settings: { body_font: "comic-sans" } }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects a key the theme never declared" do
        patch admin_theme_path("independent"),
              params: { settings: { accent_color: "#101010", rogue_key: "anything" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("rogue_key")
      end

      it "resets to the theme's defaults" do
        patch admin_theme_path("independent"), params: { settings: { accent_color: "#101010" } }
        patch admin_theme_path("independent"), params: { reset: "1" }

        expect(Theme.find_by(slug: "independent").settings).to eq({})
      end

      it "shows up on the public site" do
        write_theme(slug: "independent", parent: builtin_root,
                    manifest: { "name" => "Independent", "settings" => [ accent ] },
                    templates: { "layout" => "{{ content_for_layout }}", "post" => "accent={{ settings.accent_color }}" })
        create(:post, slug: "hello")

        patch admin_theme_path("independent"), params: { settings: { accent_color: "#101010" } }
        get "/hello"

        expect(response.body).to include("accent=#101010")
      end
    end
  end
end
