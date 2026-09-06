require "rails_helper"

# These paths sit above the /:slug catch-all, so a request for them must never
# reach PostsController and raise RecordNotFound. The browser fetches
# /service-worker on its own once a worker is registered for the origin.
RSpec.describe "the PWA files" do
  it "serves the service worker as JavaScript" do
    # The Accept header a browser sends when it re-checks a registered worker.
    get "/service-worker", headers: { "Accept" => "*/*" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/javascript")
  end

  it "serves the manifest as JSON" do
    get "/manifest"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to include("start_url" => "/")
  end

  describe "the icon it names" do
    before { favicon_root }

    it "is the shipped default until one is uploaded" do
      get "/manifest"

      icons = JSON.parse(response.body)["icons"]

      expect(icons.map { |i| i["src"] }.uniq).to eq([ "/icon.png" ])
      expect(icons.first["sizes"]).to eq("512x512")
    end

    # The app does not resize an upload, so it cannot honestly claim a size.
    it "is the uploaded one, at no declared size, once there is one" do
      install_favicon(extension: ".svg")

      get "/manifest"

      icons = JSON.parse(response.body)["icons"]

      expect(icons.first["src"]).to match(%r{\A/favicon\?v=\d+\z})
      expect(icons.first["type"]).to eq("image/svg+xml")
      expect(icons.first["sizes"]).to eq("any")
    end
  end
end
