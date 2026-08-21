require "rails_helper"

RSpec.describe "theme drops" do
  # Liquid does not escape output, so the drops do it. Anything a theme author
  # can reach with {{ }} must already be safe, and raw HTML must be reachable
  # only through a field whose name says so.
  def render(template, assigns)
    Liquid::Template.parse(template).render!(assigns)
  end

  describe Themes::Drops::PostDrop do
    let(:post) { create(:post, title: "Kantan Dev", slug: "kantan-dev", published_at: Time.utc(2026, 7, 30, 14, 47)) }

    it "exposes the fields a theme needs" do
      drop = described_class.new(post)

      expect(render("{{ post.title }}|{{ post.slug }}|{{ post.url }}", "post" => drop))
        .to eq("Kantan Dev|kantan-dev|/kantan-dev")
    end

    it "escapes a title that contains markup" do
      post.update!(title: %(Bold <script>alert("x")</script>))

      expect(render("{{ post.title }}", "post" => described_class.new(post)))
        .to eq("Bold &lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;")
    end

    it "serves the body as raw block markup through a name that says so" do
      post.update!(content: "<!-- wp:paragraph -->\n<p>Hi there.</p>\n<!-- /wp:paragraph -->")

      output = render("{{ post.body_html }}", "post" => described_class.new(post))

      expect(output).to include("<!-- wp:paragraph -->", "<p>Hi there.</p>")
    end

    it "renders oEmbed URLs the same way the site always has" do
      post.update!(content: %(<div class="wp-block-embed__wrapper">\nhttps://www.youtube.com/watch?v=abc123\n</div>))

      expect(render("{{ post.body_html }}", "post" => described_class.new(post))).to include("<iframe")
    end

    it "gives a plain-text escaped excerpt and a raw one separately" do
      post.update!(excerpt: "<em>Hand written</em>")
      drop = described_class.new(post)

      expect(render("{{ post.excerpt }}", "post" => drop)).to eq("Hand written")
      expect(render("{{ post.excerpt_html }}", "post" => drop)).to eq("<em>Hand written</em>")
    end

    it "escapes an apostrophe once, not twice" do
      post.update!(excerpt: nil, content: "<p>All&#39;s well that ends well</p>")

      expect(render("{{ post.excerpt_html }}", "post" => described_class.new(post)))
        .to eq("All&#39;s well that ends well")
    end

    it "counts words in the body, ignoring block delimiters and markup" do
      post.update!(content: "<!-- wp:paragraph -->\n<p>one two three four five</p>\n<!-- /wp:paragraph -->")

      expect(render("{{ post.word_count }}", "post" => described_class.new(post))).to eq("5")
    end

    it "exposes published_at as a time the date filter can format" do
      output = render(%({{ post.published_at | date: "%B %-d, %Y" }}), "post" => described_class.new(post))

      expect(output).to eq("July 30, 2026")
    end

    it "exposes categories and tags as drops" do
      post.categories << create(:category, name: "AI", slug: "ai")
      post.tags << create(:tag, name: "LLM", slug: "llm")

      output = render(
        "{% for c in post.categories %}{{ c.name }}@{{ c.url }}{% endfor %}" \
        "{% for t in post.tags %}{{ t.name }}@{{ t.url }}{% endfor %}",
        "post" => described_class.new(post)
      )

      expect(output).to eq("AI@/category/aiLLM@/tag/llm")
    end

    it "exposes a stored featured image, and nothing for an unstored one" do
      media = create(:media_item, :stored, key: "wp-content/uploads/2026/07/cover.jpg", alt_text: "A cover")
      post.update!(featured_media_item: media)

      expect(render("{{ post.featured_image.url }}|{{ post.featured_image.alt }}", "post" => described_class.new(post)))
        .to eq("/media/wp-content/uploads/2026/07/cover.jpg|A cover")

      post.update!(featured_media_item: create(:media_item))
      expect(render("{% if post.featured_image %}yes{% else %}no{% endif %}", "post" => described_class.new(post)))
        .to eq("no")
    end

    it "says whether it is a page" do
      expect(render("{{ post.page }}", "post" => described_class.new(create(:post, :page)))).to eq("true")
      expect(render("{{ post.page }}", "post" => described_class.new(post))).to eq("false")
    end

    it "does not expose the underlying record or anything undeclared" do
      drop = described_class.new(post)

      expect(render("{{ post.record }}{{ post.destroy }}{{ post.update }}", "post" => drop)).to eq("")
    end
  end

  describe Themes::Drops::CommentDrop do
    it "sanitizes comment content, because it is the one field the public wrote" do
      comment = create(:comment, content: %(Nice <script>alert(1)</script> post))

      output = render("{{ comment.content_html }}", "comment" => described_class.new(comment))

      expect(output).not_to include("<script>")
      expect(output).to include("Nice")
    end

    it "escapes the author name and drops a javascript: author URL" do
      comment = create(:comment, author_name: "<b>Spammer</b>", author_url: "javascript:alert(1)")
      drop = described_class.new(comment)

      expect(render("{{ comment.author_name }}", "comment" => drop)).to eq("&lt;b&gt;Spammer&lt;/b&gt;")
      expect(render("{{ comment.author_url }}", "comment" => drop)).to eq("")
    end

    it "keeps an ordinary http author URL" do
      comment = create(:comment, author_url: "https://example.com/me")

      expect(render("{{ comment.author_url }}", "comment" => described_class.new(comment)))
        .to eq("https://example.com/me")
    end
  end

  describe Themes::Drops::SiteDrop do
    it "exposes the site title, urls and category list" do
      create(:category, name: "AI", slug: "ai")

      output = render("{{ site.title }}|{{ site.url }}|{{ site.feed_url }}|{{ site.categories.first.name }}",
                      "site" => described_class.new)

      expect(output).to eq("Kantan Press|/|/feed|AI")
    end

    it "escapes a configured site title" do
      allow(KantanPress::Config).to receive(:site_title).and_return("<b>Blog</b>")

      expect(render("{{ site.title }}", "site" => described_class.new)).to eq("&lt;b&gt;Blog&lt;/b&gt;")
    end
  end

  describe Themes::Drops::PaginationDrop do
    it "gives urls for the neighbouring pages" do
      drop = described_class.new(current_page: 2, total_pages: 3, path_builder: ->(page) { "/?page=#{page}" })

      output = render("{{ pagination.current_page }}|{{ pagination.previous_url }}|{{ pagination.next_url }}",
                      "pagination" => drop)

      expect(output).to eq("2|/?page=1|/?page=3")
    end

    it "leaves the ends empty so a theme can test them" do
      drop = described_class.new(current_page: 1, total_pages: 1, path_builder: ->(page) { "/?page=#{page}" })

      expect(render("{% if pagination.next_url %}more{% endif %}", "pagination" => drop)).to eq("")
    end
  end
end

RSpec.describe KantanPress::PlainText do
  it "decodes the entities strip_tags leaves behind" do
    expect(described_class.call("<p>All&#39;s well &amp; good</p>")).to eq("All's well & good")
  end

  it "drops WordPress block delimiters without leaking their contents" do
    expect(described_class.call("<!-- wp:paragraph -->\n<p>Hi.</p>\n<!-- /wp:paragraph -->")).to eq("Hi.")
  end

  it "squishes whitespace" do
    expect(described_class.call("<p>one</p>\n\n<p>two</p>")).to eq("one two")
  end
end
