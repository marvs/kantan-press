require "rails_helper"

RSpec.describe "Admin::Settings" do
  before { SiteSetting.reset_cache! }

  it "keeps the settings page behind the login" do
    get admin_settings_path

    expect(response).to redirect_to(new_session_path)
  end

  context "when signed in" do
    before { sign_in }

    it "shows the current values" do
      SiteSetting.set(:site_title, "Tech and FI")
      SiteSetting.set(:site_description, "Notes on code and money")

      get admin_settings_path

      expect(response.body).to include('value="Tech and FI"', "Notes on code and money")
    end

    it "appears in the admin navigation" do
      get admin_posts_path

      expect(response.body).to include(admin_settings_path)
    end

    it "saves the site title and tagline" do
      patch admin_settings_path, params: { settings: { site_title: "Tech and FI", site_description: "Notes" } }

      expect(response).to redirect_to(admin_settings_path)
      expect(KantanPress::Config.site_title).to eq("Tech and FI")
      expect(KantanPress::Config.site_description).to eq("Notes")
    end

    it "shows the new title on the public site" do
      patch admin_settings_path, params: { settings: { site_title: "Tech and FI" } }
      SiteSetting.reset_cache!

      get root_path

      expect(response.body).to include("Tech and FI")
      expect(response.body).not_to include("<title>Kantan Press</title>")
    end

    it "escapes a title containing markup" do
      patch admin_settings_path, params: { settings: { site_title: "<script>alert(1)</script>" } }
      SiteSetting.reset_cache!

      get root_path

      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("&lt;script&gt;")
    end

    it "falls back to the default when the title is cleared" do
      SiteSetting.set(:site_title, "Tech and FI")

      patch admin_settings_path, params: { settings: { site_title: "" } }
      SiteSetting.reset_cache!

      expect(KantanPress::Config.site_title).to eq("Kantan Press")
    end

    describe "posts per page" do
      it "changes how many posts the index shows" do
        create_list(:post, 5)

        patch admin_settings_path, params: { settings: { posts_per_page: "2" } }
        SiteSetting.reset_cache!
        get root_path

        # The newest post is the lead card, so two per page is one lead plus one summary.
        entries = response.body.scan('<article class="post-lead">').size +
                  response.body.scan('<article class="post-summary">').size
        expect(entries).to eq(2)
        expect(response.body).to include("Page 1 of 3")
      end

      it "refuses a value outside the allowed range" do
        patch admin_settings_path, params: { settings: { posts_per_page: "500" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match(/between 1 and 50/i)
        expect(SiteSetting.get(:posts_per_page)).to be_nil
      end

      it "refuses something that is not a number" do
        patch admin_settings_path, params: { settings: { posts_per_page: "lots" } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it "ignores a key that is not a known setting" do
      patch admin_settings_path, params: { settings: { site_title: "Tech and FI", s3_secret_access_key: "stolen" } }

      expect(SiteSetting.get(:s3_secret_access_key)).to be_nil
      expect(SiteSetting.get(:site_title)).to eq("Tech and FI")
    end
  end
end
