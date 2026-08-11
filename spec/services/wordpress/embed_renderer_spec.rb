require "rails_helper"

RSpec.describe Wordpress::EmbedRenderer do
  def wrap(url, classes: "wp-block-embed is-provider-youtube wp-embed-aspect-16-9")
    %(<figure class="#{classes}"><div class="wp-block-embed__wrapper">\n#{url}\n</div></figure>)
  end

  def render(url, **options) = described_class.call(wrap(url, **options))

  describe "YouTube URLs found in the wild" do
    it "rewrites a standard watch URL" do
      expect(render("https://www.youtube.com/watch?v=oZLR2HVQj9A"))
        .to include('src="https://www.youtube-nocookie.com/embed/oZLR2HVQj9A"')
    end

    it "rewrites a youtu.be short URL" do
      expect(render("https://youtu.be/4VrOYVyZIuQ"))
        .to include("/embed/4VrOYVyZIuQ")
    end

    it "rewrites an /embed/ URL that was pasted directly" do
      expect(render("https://www.youtube.com/embed/oZLR2HVQj9A"))
        .to include("/embed/oZLR2HVQj9A")
    end

    it "ignores unrelated query parameters" do
      expect(render("https://www.youtube.com/watch?v=36m1o-tM05g&vl=en"))
        .to include("/embed/36m1o-tM05g")
    end

    it "handles an HTML-escaped ampersand, which is how the export stores it" do
      expect(render("https://www.youtube.com/watch?v=rvJTFwB-otU&amp;t=13s"))
        .to include("/embed/rvJTFwB-otU?start=13")
    end
  end

  describe "timestamps" do
    it "carries ?t=seconds across as start" do
      expect(render("https://youtu.be/6AsLHH0s2iw?t=7282")).to include("?start=7282")
    end

    it "strips the trailing s from t=13s" do
      expect(render("https://www.youtube.com/watch?v=abcdefg&t=13s")).to include("?start=13")
    end

    it "converts an h/m/s timestamp to seconds" do
      expect(render("https://www.youtube.com/watch?v=abcdefg&t=1h2m3s")).to include("?start=3723")
    end

    it "omits start when there is no timestamp" do
      expect(render("https://youtu.be/4VrOYVyZIuQ")).not_to include("start=")
    end
  end

  describe "the emitted iframe" do
    subject(:html) { render("https://youtu.be/4VrOYVyZIuQ") }

    it "keeps the wrapper so the responsive CSS box still applies" do
      expect(html).to include('<div class="wp-block-embed__wrapper">')
      expect(html).to include("</div></figure>")
    end

    it "lazy-loads and allows fullscreen" do
      expect(html).to include('loading="lazy"', "allowfullscreen")
    end

    it "does not leak a referrer" do
      expect(html).to include('referrerpolicy="strict-origin-when-cross-origin"')
    end
  end

  describe "content it must not touch" do
    it "leaves a non-YouTube provider as a plain URL" do
      html = render("https://vimeo.com/123456789")

      expect(html).not_to include("<iframe")
      expect(html).to include("https://vimeo.com/123456789")
    end

    it "leaves a URL that has no video id alone" do
      html = render("https://www.youtube.com/feed/subscriptions")

      expect(html).not_to include("<iframe")
    end

    it "returns content with no embeds byte-for-byte" do
      content = "<!-- wp:paragraph -->\n<p>Nothing to see.</p>\n<!-- /wp:paragraph -->"

      expect(described_class.call(content)).to eq(content)
    end

    it "leaves the rest of a post's block markup untouched" do
      content = <<~HTML
        <!-- wp:paragraph -->
        <p>Before</p>
        <!-- /wp:paragraph -->
        #{wrap('https://youtu.be/4VrOYVyZIuQ')}
        <!-- wp:code -->
        <pre class="wp-block-code"><code>curl example.com</code></pre>
        <!-- /wp:code -->
      HTML

      result = described_class.call(content)

      expect(result).to include("<!-- wp:paragraph -->", "<p>Before</p>", "<!-- wp:code -->")
      expect(result).to include("<code>curl example.com</code>")
      expect(result).to include("<iframe")
    end

    it "handles malformed URLs without raising" do
      expect { described_class.call(wrap("http://[bad")) }.not_to raise_error
    end
  end
end
