require "rails_helper"

RSpec.describe Wordpress::Importer do
  let(:fixture) { Rails.root.join("spec/fixtures/wordpress/techandfi_sample.xml").to_s }

  # The rewriter needs a CDN host to point at; the default disk backend serves
  # from "/media", which is what production would replace with cdn.example.com.
  def import(**options)
    described_class.new(path: fixture, **options).call
  end

  describe "taxonomies" do
    it "imports categories and links nested ones to their parent" do
      import

      expect(Category.pluck(:slug)).to match_array(%w[ai web-development local-llms])
      expect(Category.find_by(slug: "local-llms").parent).to eq(Category.find_by(slug: "ai"))
      expect(Category.find_by(slug: "ai").wp_term_id).to eq(3)
    end

    it "imports tags" do
      import

      expect(Tag.find_by(slug: "llm")).to have_attributes(name: "LLM", wp_term_id: 21)
    end
  end

  describe "posts" do
    before { import }

    it "imports posts and pages but skips revisions" do
      expect(Post.pluck(:slug)).to match_array(
        %w[local-llm-tool-calls 2016-year-in-review about half-finished]
      )
      expect(Post.find_by(slug: "900-revision-v1")).to be_nil
    end

    it "maps WordPress statuses onto published and draft" do
      expect(Post.find_by(slug: "local-llm-tool-calls")).to be_published
      expect(Post.find_by(slug: "half-finished")).to be_draft
    end

    it "records the post type" do
      expect(Post.find_by(slug: "about")).to be_type_page
      expect(Post.find_by(slug: "local-llm-tool-calls")).to be_type_post
    end

    it "keeps the WordPress id so /?p=ID keeps resolving" do
      expect(Post.find_by(slug: "local-llm-tool-calls").wp_post_id).to eq(900)
    end

    it "parses the GMT publication time" do
      expect(Post.find_by(slug: "local-llm-tool-calls").published_at)
        .to eq(Time.utc(2026, 5, 27, 14, 51, 27))
    end

    it "leaves a never-published draft without a publication time" do
      expect(Post.find_by(slug: "half-finished").published_at).to be_nil
    end

    it "attaches categories and tags" do
      post = Post.find_by(slug: "local-llm-tool-calls")

      expect(post.categories.pluck(:slug)).to eq(%w[ai])
      expect(post.tags.pluck(:slug)).to eq(%w[llm])
    end

    it "resolves the featured image through _thumbnail_id" do
      post = Post.find_by(slug: "local-llm-tool-calls")

      expect(post.featured_media_item.key)
        .to eq("wp-content/uploads/2026/05/qwen3_web_search_result.png")
    end
  end

  describe "block markup" do
    before { import }

    it "preserves block delimiter comments verbatim" do
      content = Post.find_by(slug: "local-llm-tool-calls").content

      expect(content).to include("<!-- wp:paragraph -->", "<!-- /wp:paragraph -->")
      expect(content).to include("<!-- wp:code -->")
    end

    it "leaves article cross-links on the old domain alone" do
      content = Post.find_by(slug: "local-llm-tool-calls").content

      expect(content).to include('href="https://techandfi.com/running-llms-in-intel-laptops/"')
    end
  end

  describe "media" do
    before { import }

    it "registers the attachment under its original uploads key" do
      item = MediaItem.find_by(wp_attachment_id: 901)

      expect(item.key).to eq("wp-content/uploads/2026/05/qwen3_web_search_result.png")
      expect(item).to be_pending
    end

    it "pulls width and height out of the PHP-serialized metadata" do
      expect(MediaItem.find_by(wp_attachment_id: 901)).to have_attributes(width: 1920, height: 1080)
    end

    it "registers the sized variants classic-editor posts link directly" do
      # WordPress only exports the original as an attachment; the "-300x200"
      # file it generated is referenced from post content and nowhere else.
      expect(MediaItem.find_by(key: "wp-content/uploads/2016/12/chart-300x200.jpg")).to be_present
    end

    it "registers uploads that only appear as plain links" do
      expect(MediaItem.find_by(key: "wp-content/uploads/2016/12/chart.jpg")).to be_present
    end

    it "rewrites uploads URLs in block markup onto the media host" do
      content = Post.find_by(slug: "local-llm-tool-calls").content

      expect(content).not_to include("techandfi.com/wp-content/uploads")
      expect(content).to include('src="/media/wp-content/uploads/2026/05/qwen3_web_search_result.png"')
    end

    it "rewrites uploads URLs in classic-editor HTML too" do
      content = Post.find_by(slug: "2016-year-in-review").content

      expect(content).not_to include("techandfi.com/wp-content/uploads")
      expect(content).to include('src="/media/wp-content/uploads/2016/12/chart-300x200.jpg"')
      expect(content).to include('href="/media/wp-content/uploads/2016/12/chart.jpg"')
    end

    it "leaves the image block byte-identical apart from the host, so Gutenberg still validates it" do
      content = Post.find_by(slug: "local-llm-tool-calls").content

      # srcset/sizes are added by WordPress at render time, never stored. Adding
      # them here would make the block fail Gutenberg's validation on edit.
      expect(content).not_to include("srcset", "sizes=")
      expect(content).to include('<figure class="wp-block-image size-large">')
    end

    it "enqueues one fetch job per registered image" do
      expect(Wordpress::FetchMediaJob).to have_been_enqueued.exactly(MediaItem.count).times
    end
  end

  describe "comments" do
    before { import }

    it "imports comments and threads replies to their parent" do
      post = Post.find_by(slug: "local-llm-tool-calls")
      reply = Comment.find_by(wp_comment_id: 12)

      expect(post.comments.count).to eq(2)
      expect(reply.parent).to eq(Comment.find_by(wp_comment_id: 11))
    end

    it "carries the approval flag across so spam stays hidden" do
      expect(Comment.find_by(wp_comment_id: 13)).not_to be_approved
      expect(Comment.find_by(wp_comment_id: 11)).to be_approved
    end
  end

  describe "permalinks" do
    before { import }

    it "creates a redirect when the old permalink was date-based" do
      redirect = Redirect.find_by(from_path: "/2016/12/2016-year-in-review")

      expect(redirect.to_path).to eq("/2016-year-in-review")
      expect(redirect.status).to eq(301)
    end

    it "creates no redirect when the permalink already matches the slug" do
      expect(Redirect.find_by(from_path: "/local-llm-tool-calls")).to be_nil
    end
  end

  describe "when WordPress term IDs collide with existing records" do
    # Importing a second site — or a sample export followed by the real one —
    # brings term IDs already claimed under different slugs. This used to abort
    # the whole import with a UNIQUE constraint violation.
    it "imports anyway rather than aborting the run" do
      Category.create!(name: "Unrelated", slug: "unrelated", wp_term_id: 3)

      result = import

      expect(result[:errors]).to be_empty
      expect(Post.count).to eq(4)
      expect(Category.find_by(slug: "ai")).to be_present
    end

    it "treats the WordPress id as identity, so a renamed category updates in place" do
      Category.create!(name: "Old Name", slug: "old-name", wp_term_id: 3)

      import

      expect(Category.find_by(wp_term_id: 3)).to have_attributes(name: "AI", slug: "ai")
      expect(Category.find_by(slug: "old-name")).to be_nil
    end

    it "anchors on the slug when the id points at a different existing record" do
      # Exactly the shape a second import produces: term 3 belongs to one row
      # while the incoming slug belongs to another. Following the id would
      # rename "squatter" to "ai" and collide.
      Category.create!(name: "Squatter", slug: "squatter", wp_term_id: 3)
      Category.create!(name: "AI", slug: "ai")

      result = import

      expect(result[:errors]).to be_empty
      expect(Category.find_by(slug: "squatter")).to be_present
      expect(Category.find_by(slug: "ai")).to be_present
    end

    it "drops the incoming id when a different record already holds it" do
      # Matched by slug, but term 3 belongs to something else — the unique
      # index wins over provenance rather than aborting the import.
      Category.create!(name: "Squatter", slug: "squatter", wp_term_id: 3)
      Category.create!(name: "AI", slug: "ai")

      import

      expect(Category.find_by(slug: "squatter").wp_term_id).to eq(3)
      expect(Category.find_by(slug: "ai").wp_term_id).to be_nil
    end
  end

  describe "re-running the same export" do
    it "updates in place instead of duplicating" do
      import
      counts = { posts: Post.count, media: MediaItem.count, comments: Comment.count,
                 categories: Category.count, redirects: Redirect.count }

      import

      expect(Post.count).to eq(counts[:posts])
      expect(MediaItem.count).to eq(counts[:media])
      expect(Comment.count).to eq(counts[:comments])
      expect(Category.count).to eq(counts[:categories])
      expect(Redirect.count).to eq(counts[:redirects])
    end
  end

  describe "the returned summary" do
    it "reports per-kind tallies" do
      result = import

      expect(result[:stats]["posts"]["created"]).to eq(4)
      expect(result[:stats]["categories"]["created"]).to eq(3)
      expect(result[:stats]["comments"]["created"]).to eq(3)
      expect(result[:errors]).to be_empty
    end
  end
end
