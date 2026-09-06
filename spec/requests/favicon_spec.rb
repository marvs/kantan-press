require "rails_helper"

RSpec.describe "the uploaded favicon" do
  before { favicon_root }

  it "is not there on an install where nobody has uploaded one" do
    get favicon_path

    expect(response).to have_http_status(:not_found)
  end

  it "serves an uploaded PNG as a PNG" do
    install_favicon(extension: ".png")

    get favicon_path

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
  end

  it "serves an uploaded SVG as an SVG" do
    install_favicon(extension: ".svg")

    get favicon_path

    expect(response.media_type).to eq("image/svg+xml")
  end

  # An SVG opened as a document runs its own <script> on this origin. The file
  # was uploaded by an admin, but "the admin is trusted" is not a defence worth
  # relying on for content served to every visitor.
  it "serves an SVG so it can neither load nor run anything" do
    install_favicon(extension: ".svg")

    get favicon_path

    expect(response.headers["Content-Security-Policy"]).to eq("default-src 'none'; sandbox")
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
  end

  # The path never changes, so the ?v= in the URL is what makes a replacement
  # visible — which is what lets the response itself be cached forever.
  it "is cacheable forever, because the URL carries the version" do
    install_favicon

    get favicon_path

    expect(response.headers["Cache-Control"]).to include("max-age=31536000", "immutable")
  end

  it "is not mistaken for a post slug" do
    create(:post, slug: "favicon", title: "A post that wants the favicon slug")

    get "/favicon"

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("A post that wants the favicon slug")
  end
end
