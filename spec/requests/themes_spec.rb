require "rails_helper"

RSpec.describe "the public site rendered through a theme" do
  let(:themes_root) { Pathname.new(theme_tmpdir) }

  before do
    allow(Themes::Registry).to receive_messages(builtin_root: themes_root, uploaded_root: themes_root)
  end

  def install(slug: "independent", templates: {}, settings: [], assets: {})
    write_theme(slug: slug, parent: themes_root, manifest: { "settings" => settings },
                templates: templates, assets: assets)
  end

  describe "with a theme installed" do
    before do
      install(templates: {
        "layout" => "<html><head><title>{{ site.title }}</title></head><body>{{ content_for_layout }}</body></html>",
        "index" => "INDEX{% for post in posts %}[{{ post.title }}]{% endfor %}" \
                   "{% if pagination.next_url %}<a href='{{ pagination.next_url }}'>older</a>{% endif %}",
        "post" => "POST:{{ post.title }}:{{ post.body_html }}" \
                  "{% for c in post.comments %}<div>{{ c.content_html }}</div>{% endfor %}",
        "page" => "PAGE:{{ post.title }}",
        "archive" => "ARCHIVE:{{ archive.title }}{% for post in posts %}[{{ post.title }}]{% endfor %}"
      })
    end

    it "renders the index through the theme instead of the ERB view" do
      create(:post, title: "Kantan Dev")

      get root_path

      expect(response.body).to include("INDEX[Kantan Dev]")
      expect(response.body).to include("<title>Kantan Press</title>")
      expect(response.body).not_to include("post-list")
    end

    it "paginates through the theme" do
      create_list(:post, 11)

      get root_path

      expect(response.body).to include("older")
    end

    it "renders a post, its body markup and its comments" do
      post = create(:post, slug: "kantan-dev", title: "Kantan Dev",
                    content: "<!-- wp:paragraph -->\n<p>Hi there.</p>\n<!-- /wp:paragraph -->")
      create(:comment, post: post, content: "Visible comment")
      create(:comment, post: post, content: "Spam comment", approved: false)

      get "/kantan-dev"

      expect(response.body).to include("POST:Kantan Dev:", "<p>Hi there.</p>", "Visible comment")
      expect(response.body).not_to include("Spam comment")
    end

    it "uses the page template for a page" do
      create(:post, :page, slug: "about", title: "About")

      get "/about"

      expect(response.body).to include("PAGE:About")
    end

    it "renders category, tag and month archives" do
      category = create(:category, name: "AI", slug: "ai")
      tag = create(:tag, name: "LLM", slug: "llm")
      create(:post, title: "About LLMs", categories: [ category ], tags: [ tag ],
             published_at: Time.utc(2016, 12, 15))

      get "/category/ai"
      expect(response.body).to include("ARCHIVE:AI[About LLMs]")

      get "/tag/llm"
      expect(response.body).to include("ARCHIVE:LLM[About LLMs]")

      get "/2016/12"
      expect(response.body).to include("ARCHIVE:December 2016[About LLMs]")
    end

    it "leaves the Atom feed alone" do
      create(:post, title: "In the feed")

      get feed_path

      expect(response.media_type).to eq("application/atom+xml")
      expect(response.body).to include("In the feed")
      expect(response.body).not_to include("INDEX")
    end

    it "still 404s an unknown slug" do
      get "/nope"

      expect(response).to have_http_status(:not_found)
    end

    it "still follows an imported redirect" do
      create(:post, slug: "2016-year-in-review")
      Redirect.create!(from_path: "/old-name", to_path: "/2016-year-in-review")

      get "/old-name"

      expect(response).to redirect_to("/2016-year-in-review")
    end
  end

  describe "settings" do
    it "reaches the rendered page" do
      install(
        templates: { "layout" => "{{ content_for_layout }}", "post" => "accent={{ settings.accent_color }}" },
        settings: [ { "key" => "accent_color", "type" => "color", "label" => "Accent", "default" => "#57ad68" } ]
      )
      create(:post, slug: "hello")

      get "/hello"
      expect(response.body).to include("accent=#57ad68")

      Theme.create!(slug: "independent", active: true, settings: { "accent_color" => "#101010" })

      get "/hello"
      expect(response.body).to include("accent=#101010")
    end
  end

  describe "when the active theme is broken" do
    before do
      install(templates: { "post" => "{{ post.title }" }) # unclosed output tag
      create(:post, slug: "hello", title: "Kantan Dev")
    end

    it "raises outside production, so a broken theme cannot go unnoticed" do
      expect { get "/hello" }.to raise_error(Liquid::Error)
    end

    it "falls back to the ERB view in production and logs why" do
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(Rails.logger).to receive(:error)

      get "/hello"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("post-article", "Kantan Dev")
      expect(Rails.logger).to have_received(:error).with(/failed to render post/)
    end
  end

  describe "when no theme is installed at all" do
    it "renders the ERB views exactly as before" do
      create(:post, slug: "hello", title: "Kantan Dev")

      get "/hello"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("post-article", "Kantan Dev")
    end
  end
end
