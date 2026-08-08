require "rails_helper"

RSpec.describe "the public site" do
  describe "GET /" do
    it "lists published posts newest first" do
      create(:post, title: "Older", published_at: 2.days.ago)
      create(:post, title: "Newer", published_at: 1.hour.ago)

      get root_path

      expect(response.body.index("Newer")).to be < response.body.index("Older")
    end

    it "hides drafts and scheduled posts" do
      create(:post, :draft, title: "Not ready")
      create(:post, :scheduled, title: "Next week")

      get root_path

      expect(response.body).not_to include("Not ready", "Next week")
    end

    it "keeps pages out of the post list" do
      create(:post, :page, title: "About this blog")

      get root_path

      expect(response.body).not_to include("About this blog")
    end

    it "redirects a WordPress /?p=ID permalink to the slug" do
      post = create(:post, wp_post_id: 900, slug: "local-llm-tool-calls")

      get root_path(p: 900)

      expect(response).to redirect_to("/#{post.slug}")
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe "GET /:slug" do
    it "renders stored block markup verbatim, comments and all" do
      create(:post, slug: "hello", content: "<!-- wp:paragraph -->\n<p>Hi there.</p>\n<!-- /wp:paragraph -->")

      get "/hello"

      expect(response.body).to include("<!-- wp:paragraph -->", "<p>Hi there.</p>")
    end

    it "shows approved comments and hides held ones" do
      post = create(:post, slug: "commented")
      create(:comment, post: post, content: "Visible comment")
      create(:comment, post: post, content: "Spam comment", approved: false)

      get "/commented"

      expect(response.body).to include("Visible comment")
      expect(response.body).not_to include("Spam comment")
    end

    it "serves a page at its slug" do
      create(:post, :page, slug: "about", title: "About")

      get "/about"

      expect(response).to have_http_status(:ok)
    end

    it "404s an unknown slug" do
      get "/nope"

      expect(response).to have_http_status(:not_found)
    end

    it "follows a redirect recorded during import" do
      create(:post, slug: "2016-year-in-review")
      Redirect.create!(from_path: "/old-name", to_path: "/2016-year-in-review")

      get "/old-name"

      expect(response).to redirect_to("/2016-year-in-review")
      expect(response).to have_http_status(:moved_permanently)
    end

    it "follows a multi-segment legacy permalink" do
      create(:post, slug: "2016-year-in-review")
      Redirect.create!(from_path: "/2016/12/2016-year-in-review", to_path: "/2016-year-in-review")

      get "/2016/12/2016-year-in-review"

      expect(response).to redirect_to("/2016-year-in-review")
    end
  end

  describe "archives and taxonomy" do
    it "lists a month's posts at /YYYY/MM" do
      create(:post, title: "December post", published_at: Time.utc(2016, 12, 15))
      create(:post, title: "January post", published_at: Time.utc(2017, 1, 15))

      get "/2016/12"

      expect(response.body).to include("December post")
      expect(response.body).not_to include("January post")
    end

    it "404s an impossible month" do
      get "/2016/13"

      expect(response).to have_http_status(:not_found)
    end

    it "lists posts in a category" do
      category = create(:category, name: "AI", slug: "ai")
      create(:post, title: "About LLMs", categories: [ category ])
      create(:post, title: "Unrelated")

      get "/category/ai"

      expect(response.body).to include("About LLMs")
      expect(response.body).not_to include("Unrelated")
    end

    it "lists posts with a tag" do
      tag = create(:tag, name: "LLM", slug: "llm")
      create(:post, title: "Tagged post", tags: [ tag ])

      get "/tag/llm"

      expect(response.body).to include("Tagged post")
    end
  end

  describe "GET /feed" do
    it "serves an Atom feed of published posts" do
      create(:post, title: "In the feed")

      get feed_path

      expect(response.media_type).to eq("application/atom+xml")
      expect(response.body).to include("In the feed")
    end
  end
end
