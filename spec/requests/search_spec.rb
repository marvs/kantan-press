require "rails_helper"

RSpec.describe "article search" do
  describe "GET /search" do
    it "finds an article by its title" do
      create(:post, title: "Deploying with Kamal")
      create(:post, title: "Something else entirely")

      get search_path(q: "kamal")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Deploying with Kamal")
      expect(response.body).not_to include("Something else entirely")
    end

    it "finds an article by its body" do
      create(:post, title: "A quiet title", content: "<p>The bucket lives in Singapore.</p>")

      get search_path(q: "singapore")

      expect(response.body).to include("A quiet title")
    end

    it "paginates like the home page does" do
      create_list(:post, 11, title: "Kamal note")

      get search_path(q: "kamal", page: 2)

      expect(response.body).to include("Page 2 of 2")
    end

    it "prompts instead of listing when no query was given" do
      create(:post, title: "Deploying with Kamal")

      get search_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Deploying with Kamal")
      expect(response.body).to include("Search the articles")
    end

    it "says so when nothing matches, and names what was searched for" do
      create(:post, title: "Deploying with Kamal")

      get search_path(q: "gardening")

      expect(response.body).to include("No articles match")
      expect(response.body).to include("gardening")
    end

    # The query is reflected back onto the page, which puts it in the same class
    # as an imported WordPress title.
    it "escapes the query it echoes back" do
      get search_path(q: "<script>alert(1)</script>")

      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("&lt;script&gt;")
    end

    it "is not mistaken for a post slug" do
      create(:post, slug: "search", title: "A post that wants the search slug")

      get "/search"

      expect(response.body).to include("Search the articles")
      expect(response.body).not_to include("A post that wants the search slug")
    end

    it "puts the field on the home page" do
      create(:post, title: "Deploying with Kamal")

      get root_path

      expect(response.body).to include("action=\"/search\"")
    end

    # The field sits with the article list, so a blog with nothing published
    # shows no search box. There would be nothing to search.
    it "leaves the field off a home page with nothing published" do
      get root_path

      expect(response.body).not_to include("action=\"/search\"")
    end
  end
end
