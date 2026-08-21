require "rails_helper"

# Exercises the theme that ships with the app, against the real files in
# themes/independent rather than a fixture.
RSpec.describe "the Independent theme" do
  let(:cover) do
    create(:media_item, :stored, key: "wp-content/uploads/2026/07/cover.jpg", alt_text: "A cover photo")
  end

  def create_post(**attributes)
    create(:post, { slug: "kantan-dev", title: "Kantan Dev", published_at: Time.utc(2026, 7, 30) }.merge(attributes))
  end

  it "is the default theme, and is what an untouched install renders" do
    expect(Themes::Registry.default.slug).to eq("independent")
    expect(Theme.selection.bundle.name).to eq("Independent")
  end

  describe "a post with a featured image" do
    before { create_post(featured_media_item: cover).categories << create(:category, name: "AI", slug: "ai") }

    it "puts the title and byline inside a full-width cover" do
      get "/kantan-dev"

      expect(response.body).to include('<div class="post-cover">')
      expect(response.body).to include('src="/media/wp-content/uploads/2026/07/cover.jpg"')
      expect(response.body).to include('alt="A cover photo"')
      expect(response.body).to match(%r{<div class="cover-meta">.*<h1 class="entry-title">Kantan Dev</h1>}m)
      expect(response.body).to include('<div class="post-cover__scrim"></div>')
    end

    it "shows the byline the reference site shows" do
      get "/kantan-dev"

      expect(response.body).to include("/category/ai", "AI", "July 30, 2026")
    end

    it "loads the fade-on-scroll script and the stylesheet, both versioned" do
      get "/kantan-dev"

      expect(response.body).to match(%r{/themes/independent/assets/theme\.css\?v=\w+})
      expect(response.body).to match(%r{<script src="/themes/independent/assets/theme\.js\?v=\w+" defer>})
    end

    it "emits the head metadata the ERB view used to" do
      get "/kantan-dev"

      expect(response.body).to include("<title>Kantan Dev</title>")
      expect(response.body).to include('<link rel="canonical" href="http://www.example.com/kantan-dev">')
      expect(response.body).to include('<meta property="og:type" content="article">')
      expect(response.body).to include('<meta property="og:image" content="/media/wp-content/uploads/2026/07/cover.jpg">')
    end
  end

  describe "a post with no featured image" do
    it "falls back to a titled header instead of an empty black band" do
      create_post

      get "/kantan-dev"

      expect(response.body).not_to include('class="post-cover"')
      expect(response.body).to include('<header class="entry-header">')
      expect(response.body).to match(%r{<h1 class="entry-title">Kantan Dev</h1>})
    end
  end

  describe "the word count setting" do
    before { create_post(content: "<!-- wp:paragraph -->\n<p>one two three four five</p>\n<!-- /wp:paragraph -->", featured_media_item: cover) }

    it "shows a delimited word count by default" do
      get "/kantan-dev"

      expect(response.body).to include("5 Words")
    end

    it "hides it when the setting is switched off" do
      Theme.create!(slug: "independent", settings: { "show_word_count" => false })

      get "/kantan-dev"

      expect(response.body).not_to include("Words")
    end
  end

  describe "the other settings" do
    it "drives the accent colour, cover height and body font from :root" do
      create_post
      Theme.create!(slug: "independent",
                    settings: { "accent_color" => "#101010", "cover_height" => "tall", "body_font" => "sans" })

      get "/kantan-dev"

      expect(response.body).to include("--accent: #101010;")
      expect(response.body).to include("--cover-pad: 35vh;")
      expect(response.body).to include("--body-font: var(--sans);")
    end
  end

  describe "the home page" do
    it "gives the newest post a lead treatment and the rest ordinary cards" do
      create(:post, slug: "newest", title: "The Newest One", published_at: 1.hour.ago,
             featured_media_item: cover)
      create(:post, title: "An Older One", published_at: 3.days.ago)

      get root_path

      expect(response.body).to include('<article class="post-lead">')
      expect(response.body).to match(%r{post-lead__eyebrow">\s*Latest})
      expect(response.body).to match(%r{<article class="post-lead">[\s\S]*The Newest One}m)
      expect(response.body.scan('<article class="post-summary">').size).to eq(1)
      expect(response.body).to include("An Older One")
    end

    it "does not repeat the lead post further down the list" do
      create(:post, slug: "newest", title: "The Newest One", published_at: 1.hour.ago)
      create(:post, title: "An Older One", published_at: 3.days.ago)

      get root_path

      expect(response.body.scan("The Newest One").size).to eq(1)
    end

    it "drops the lead treatment beyond page one, where nothing is the latest" do
      create_list(:post, 12)

      get root_path(page: 2)

      expect(response.body).not_to include('<article class="post-lead">')
      expect(response.body.scan('<article class="post-summary">').size).to eq(2)
    end

    it "shows the tagline and a count beside every category" do
      allow(KantanPress::Config).to receive(:site_description).and_return("Notes on code")
      category = create(:category, name: "AI", slug: "ai")
      create_list(:post, 3, categories: [ category ])

      get root_path

      expect(response.body).to include("Notes on code")
      expect(response.body).to match(%r{AI <span class="site-nav__count">3</span>})
    end

    it "leads with a titled card when the newest post has no featured image" do
      create(:post, slug: "newest", title: "The Newest One")

      get root_path

      expect(response.body).to include('<article class="post-lead">', "The Newest One")
      expect(response.body).not_to include("post-lead__thumb")
    end
  end

  describe "the rest of the site" do
    it "renders the index, a page and an archive" do
      create_post(title: "Kantan Dev")
      create(:post, :page, slug: "about", title: "About this blog")
      create(:category, name: "AI", slug: "ai")

      get root_path
      expect(response.body).to include('class="post-list"', "Kantan Dev", "Continue reading")

      get "/about"
      expect(response.body).to include("About this blog")
      expect(response.body).not_to include("Continue reading")

      get "/category/ai"
      expect(response.body).to include('<h1 class="page-title">AI</h1>')
    end

    it "renders imported block markup verbatim" do
      create_post(content: "<!-- wp:paragraph -->\n<p>Hi there.</p>\n<!-- /wp:paragraph -->")

      get "/kantan-dev"

      expect(response.body).to include("<!-- wp:paragraph -->", "<p>Hi there.</p>")
    end
  end

  describe "its assets" do
    it "serves the stylesheet, the script and a font" do
      get "/themes/independent/assets/theme.css"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/css")

      get "/themes/independent/assets/theme.js"
      expect(response).to have_http_status(:ok)

      get "/themes/independent/assets/fonts/pt-serif-400-normal-latin.woff2"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("font/woff2")
    end

    it "serves its own screenshot to the themes page" do
      get "/themes/independent/screenshot"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/svg+xml")
      expect(response.body).to include("<svg")
    end

    it "carries the WordPress block styles, or imported posts lose their layout" do
      get "/themes/independent/assets/theme.css"

      expect(response.body).to include(
        ".entry-content .wp-block-image",
        ".entry-content .wp-block-table",
        ".entry-content .wp-block-quote",
        ".entry-content .aligncenter",
        ".entry-content .alignwide"
      )
      expect(response.body).not_to include(".post-body")
    end

    it "self-hosts both font families rather than calling out to Google" do
      get "/themes/independent/assets/theme.css"

      expect(response.body).to include("font-family: 'PT Sans'", "font-family: 'PT Serif'")
      expect(response.body).to include("url(fonts/pt-sans-400-normal-latin.woff2)")
      expect(response.body).not_to include("fonts.googleapis.com", "fonts.gstatic.com")
    end

    # Both of these were wrong on the first cut: the body copy stayed at the
    # small-screen size on every viewport, and the reading column never widened.
    it "steps the body copy up to the base size on wider screens" do
      get "/themes/independent/assets/theme.css"

      expect(response.body).to match(/@media \(min-width: 518px\)/)
      expect(response.body).to include(".entry-content { font-size: inherit; }")
    end

    it "widens the reading column on desktop" do
      get "/themes/independent/assets/theme.css"

      expect(response.body).to include("--measure: 700px;")
      expect(response.body).to match(/@media \(min-width: 992px\)[^}]*\{[\s\S]*?--measure: 1000px;/)
    end

    it "never uses a fixed background attachment, which is broken on iOS" do
      get "/themes/independent/assets/theme.css"

      expect(response.body).not_to include("background-attachment: fixed")
    end
  end
end
