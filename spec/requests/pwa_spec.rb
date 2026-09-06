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
end
