require "rails_helper"

RSpec.describe "theme assets" do
  let(:themes_root) { Pathname.new(theme_tmpdir) }

  before do
    allow(Themes::Registry).to receive_messages(builtin_root: themes_root, uploaded_root: themes_root)
    write_theme(slug: "sample", parent: themes_root, assets: {
      "theme.css" => "body{color:red}",
      "theme.js" => "console.log(1)",
      "fonts/pt-sans.woff2" => "not-really-a-font",
      "danger.rb" => "System.exit"
    })
  end

  it "serves a stylesheet with a far-future cache header, without signing in" do
    get "/themes/sample/assets/theme.css"

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("body{color:red}")
    expect(response.media_type).to eq("text/css")
    expect(response.headers["Cache-Control"]).to include("max-age=31536000", "immutable")
  end

  it "serves a nested font with the right content type" do
    get "/themes/sample/assets/fonts/pt-sans.woff2"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("font/woff2")
  end

  it "serves javascript" do
    get "/themes/sample/assets/theme.js"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/javascript").or eq("application/javascript")
  end

  it "refuses a file whose extension is not a web asset" do
    get "/themes/sample/assets/danger.rb"

    expect(response).to have_http_status(:not_found)
  end

  it "refuses the theme's own source" do
    get "/themes/sample/assets/../theme.json"
    expect(response).to have_http_status(:not_found)

    get "/themes/sample/assets/..%2Ftheme.json"
    expect(response).to have_http_status(:not_found)

    get "/themes/sample/assets/%2e%2e/templates/post.liquid"
    expect(response).to have_http_status(:not_found)
  end

  it "refuses a symlink that points outside the theme" do
    outside = Pathname.new(theme_tmpdir).join("secret.css")
    outside.write("secret")
    File.symlink(outside.to_s, themes_root.join("sample", "assets", "escape.css").to_s)

    get "/themes/sample/assets/escape.css"

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("secret")
  end

  it "404s an unknown file and an unknown theme" do
    get "/themes/sample/assets/missing.css"
    expect(response).to have_http_status(:not_found)

    get "/themes/nope/assets/theme.css"
    expect(response).to have_http_status(:not_found)
  end

  describe "the screenshot" do
    it "serves one that sits at the theme root, where themes conventionally put it" do
      themes_root.join("sample", "screenshot.svg").write("<svg xmlns='http://www.w3.org/2000/svg'/>")

      get "/themes/sample/screenshot"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/svg+xml")
    end

    it "serves a png screenshot too" do
      themes_root.join("sample", "screenshot.png").write("not really a png")

      get "/themes/sample/screenshot"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
    end

    it "404s when the theme ships none, and for an unknown theme" do
      get "/themes/sample/screenshot"
      expect(response).to have_http_status(:not_found)

      get "/themes/nope/screenshot"
      expect(response).to have_http_status(:not_found)
    end
  end

  # An SVG opened as a document runs its own <script>. A theme is untrusted, so
  # without this an uploaded theme could run script on this origin the moment
  # someone followed the link.
  describe "defusing an SVG that carries script" do
    it "sends a policy that stops it executing, and forbids sniffing" do
      themes_root.join("sample", "assets", "evil.svg")
        .write(%(<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>))

      get "/themes/sample/assets/evil.svg"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Security-Policy"]).to include("default-src 'none'", "sandbox")
      expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    end

    it "applies the same headers to the screenshot" do
      themes_root.join("sample", "screenshot.svg").write("<svg xmlns='http://www.w3.org/2000/svg'/>")

      get "/themes/sample/screenshot"

      expect(response.headers["Content-Security-Policy"]).to include("default-src 'none'")
    end
  end

  it "does not let the asset route be shadowed by the public slug catch-all" do
    create(:post, slug: "themes")

    get "/themes/sample/assets/theme.css"

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("body{color:red}")
  end
end
