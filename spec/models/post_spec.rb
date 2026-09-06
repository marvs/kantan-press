require "rails_helper"

RSpec.describe Post do
  # The body is Gutenberg block markup, so it cannot be searched directly: a
  # reader looking for "image" would match every wp-block-image wrapper rather
  # than the writing. content_plain holds the readable text instead.
  describe "content_plain" do
    it "is set from the body when the post is created" do
      post = create(:post, content: "<!-- wp:paragraph -->\n<p>Kamal deploys the app.</p>\n<!-- /wp:paragraph -->")

      expect(post.content_plain).to eq("Kamal deploys the app.")
    end

    it "keeps block markup out of the text" do
      post = create(:post, content: "<!-- wp:image {\"id\":12} --><figure class=\"wp-block-image\"><img src=\"a.png\"></figure><!-- /wp:image -->")

      expect(post.content_plain).not_to include("wp-block-image", "wp:image")
    end

    it "decodes entities so a search for the readable word matches" do
      post = create(:post, content: "<p>All&#39;s well &amp; good</p>")

      expect(post.content_plain).to eq("All's well & good")
    end

    it "is refreshed when the body changes" do
      post = create(:post, content: "<p>First body.</p>")

      post.update!(content: "<p>Second body.</p>")

      expect(post.content_plain).to eq("Second body.")
    end

    it "is blank when there is no body" do
      post = create(:post, content: nil)

      expect(post.content_plain).to be_blank
    end
  end
end
