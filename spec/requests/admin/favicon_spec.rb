require "rails_helper"

RSpec.describe "Admin::Favicon" do
  before { favicon_root }

  it "keeps uploading behind the login" do
    post admin_favicon_path, params: { favicon: rack_upload("logo.png", png_bytes) }

    expect(response).to redirect_to(new_session_path)
    expect(Branding::Favicon.current).to be_nil
  end

  it "keeps removal behind the login" do
    install_favicon
    Current.reset

    delete admin_favicon_path

    expect(response).to redirect_to(new_session_path)
    expect(Branding::Favicon.current).not_to be_nil
  end

  context "when signed in" do
    before { sign_in }

    it "accepts an upload and reports it" do
      post admin_favicon_path, params: { favicon: rack_upload("logo.png", png_bytes) }

      expect(response).to redirect_to(admin_settings_path)
      follow_redirect!
      expect(response.body).to include("Favicon updated")
      expect(Branding::Favicon.current.extension).to eq(".png")
    end

    it "replaces one format with another" do
      post admin_favicon_path, params: { favicon: rack_upload("logo.svg", svg_bytes) }
      Current.reset
      post admin_favicon_path, params: { favicon: rack_upload("logo.png", png_bytes) }

      expect(Branding::Favicon.current.extension).to eq(".png")
      expect(favicon_root.join("favicon.svg")).not_to exist
    end

    it "removes one, putting the shipped mark back" do
      install_favicon
      Current.reset

      delete admin_favicon_path

      expect(response).to redirect_to(admin_settings_path)
      follow_redirect!
      expect(response.body).to include("Favicon removed")
      expect(Branding::Favicon.current).to be_nil
    end

    it "says why it refused an upload, and changes nothing" do
      install_favicon(extension: ".png")
      Current.reset

      post admin_favicon_path, params: { favicon: rack_upload("logo.svg", "<html>not an svg</html>") }
      follow_redirect!

      expect(response.body).to include("not an SVG")
      expect(Branding::Favicon.current.extension).to eq(".png")
    end

    it "offers the control on the settings page" do
      get admin_settings_path

      expect(response.body).to include('name="favicon"', "Favicon")
    end
  end
end
