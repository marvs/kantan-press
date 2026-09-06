require "rails_helper"

RSpec.describe Posts::Search do
  def search(query) = described_class.call(query)

  it "matches on the title" do
    post = create(:post, title: "Deploying with Kamal")
    create(:post, title: "Something else")

    expect(search("kamal")).to contain_exactly(post)
  end

  it "matches on the body" do
    post = create(:post, title: "Untitled", content: "<p>The bucket lives in Singapore.</p>")
    create(:post, title: "Untitled", content: "<p>Nothing to see.</p>")

    expect(search("singapore")).to contain_exactly(post)
  end

  # The point of content_plain. Searching posts.content would match the markup.
  it "does not match the block markup around the body" do
    create(:post, content: "<!-- wp:image --><figure class=\"wp-block-image\"><img src=\"a.png\"></figure><!-- /wp:image -->")

    expect(search("wp-block-image")).to be_empty
    expect(search("figure")).to be_empty
  end

  it "requires every word, in any order" do
    both = create(:post, title: "Kamal", content: "<p>It deploys to Hetzner.</p>")
    create(:post, title: "Kamal", content: "<p>Nothing about the host.</p>")

    expect(search("hetzner kamal")).to contain_exactly(both)
  end

  it "ignores case" do
    post = create(:post, title: "Deploying with Kamal")

    expect(search("KAMAL")).to contain_exactly(post)
  end

  it "returns the newest first" do
    older = create(:post, title: "Kamal one", published_at: 3.days.ago)
    newer = create(:post, title: "Kamal two", published_at: 1.hour.ago)

    expect(search("kamal")).to eq([ newer, older ])
  end

  # A LIKE wildcard typed by a reader has to be a literal character, or "%"
  # would quietly return the whole blog.
  describe "wildcards in the query" do
    it "treats % as a literal" do
      create(:post, title: "Ordinary post")
      literal = create(:post, title: "100% cotton")

      expect(search("%")).to contain_exactly(literal)
    end

    it "treats _ as a literal" do
      create(:post, title: "Ordinary post")
      literal = create(:post, title: "Naming things", content: "<p>Prefer snake_case here.</p>")

      expect(search("_")).to contain_exactly(literal)
    end
  end

  describe "what it refuses to return" do
    it "excludes drafts" do
      create(:post, :draft, title: "Kamal draft")

      expect(search("kamal")).to be_empty
    end

    it "excludes posts published in the future" do
      create(:post, :scheduled, title: "Kamal later")

      expect(search("kamal")).to be_empty
    end

    it "excludes pages, because the reader asked for articles" do
      create(:post, :page, title: "Kamal page")

      expect(search("kamal")).to be_empty
    end

    it "returns nothing for a blank query" do
      create(:post, title: "Kamal")

      expect(search("")).to be_empty
      expect(search("   ")).to be_empty
      expect(search(nil)).to be_empty
    end
  end

  # Two caps keep a hostile query cheap without changing what an ordinary one does.
  describe "caps" do
    it "applies at most #{described_class::MAX_TERMS} words" do
      post = create(:post, title: "one two three four five six seven eight nine ten")

      # The eleventh word appears nowhere, and is dropped rather than required.
      expect(search("one two three four five six seven eight nine ten eleven")).to contain_exactly(post)
    end

    it "reads at most #{described_class::MAX_QUERY_LENGTH} characters" do
      post = create(:post, title: "Kamal")

      # "zebra" sits past the cap, so it is never treated as a required word.
      expect(search("kamal#{' ' * described_class::MAX_QUERY_LENGTH}zebra")).to contain_exactly(post)
    end
  end
end
