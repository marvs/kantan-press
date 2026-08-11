require "rails_helper"

RSpec.describe "Admin::Posts" do
  describe "authentication" do
    it "sends an anonymous visitor to sign in" do
      get admin_posts_path

      expect(response).to redirect_to(new_session_path)
    end

    it "keeps every admin section behind the login" do
      [ admin_posts_path, admin_media_items_path, admin_imports_path, admin_comments_path ].each do |path|
        get path
        expect(response).to redirect_to(new_session_path), "#{path} was reachable while signed out"
      end
    end
  end

  context "when signed in" do
    before { sign_in }

    it "lists posts with their status" do
      create(:post, title: "Published thing")
      create(:post, :draft, title: "Draft thing")

      get admin_posts_path

      expect(response.body).to include("Published thing", "Draft thing")
    end

    it "filters by status" do
      create(:post, title: "Published thing")
      create(:post, :draft, title: "Draft thing")

      get admin_posts_path(status: "draft")

      expect(response.body).to include("Draft thing")
      expect(response.body).not_to include("Published thing")
    end

    it "searches by title" do
      create(:post, title: "Local LLM tool calls")
      create(:post, title: "Year in review")

      get admin_posts_path(q: "LLM")

      expect(response.body).to include("Local LLM tool calls")
      expect(response.body).not_to include("Year in review")
    end

    it "creates a post and derives its slug" do
      expect {
        post admin_posts_path, params: { post: { title: "A Brand New Post", content: "<p>Hi</p>", status: "draft" } }
      }.to change(Post, :count).by(1)

      expect(Post.last.slug).to eq("a-brand-new-post")
    end

    it "re-renders with errors when the title is missing" do
      post admin_posts_path, params: { post: { title: "", content: "x" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Title can&#39;t be blank")
    end

    it "updates content without mangling block markup" do
      record = create(:post)
      markup = "<!-- wp:heading -->\n<h2>Heading</h2>\n<!-- /wp:heading -->"

      patch admin_post_path(record), params: { post: { content: markup } }

      expect(record.reload.content).to eq(markup)
    end

    it "assigns categories and tags" do
      record = create(:post)
      category = create(:category)
      tag = create(:tag)

      patch admin_post_path(record), params: { post: { category_ids: [ category.id ], tag_ids: [ tag.id ] } }

      expect(record.reload.categories).to eq([ category ])
      expect(record.tags).to eq([ tag ])
    end

    it "publishes a draft and stamps a publication time" do
      record = create(:post, :draft)

      patch publish_admin_post_path(record)

      expect(record.reload).to be_published
      expect(record.published_at).to be_present
    end

    it "unpublishes without discarding the original date" do
      record = create(:post, published_at: Time.utc(2020, 1, 1))

      patch unpublish_admin_post_path(record)

      expect(record.reload).to be_draft
      expect(record.published_at).to eq(Time.utc(2020, 1, 1))
    end

    it "deletes a post" do
      record = create(:post)

      expect { delete admin_post_path(record) }.to change(Post, :count).by(-1)
    end

    it "offers a link to the live page for published posts only" do
      published = create(:post, slug: "live-one", title: "Live one")
      create(:post, :draft, title: "Draft one")

      get admin_posts_path

      expect(response.body).to include(%(href="/#{published.slug}"))
      expect(response.body).to include("View")
    end

    describe "taxonomy controls" do
      it "renders categories and tags as checkboxes rather than a multi-select" do
        create(:category, name: "AI")
        create(:tag, name: "LLM")

        get new_admin_post_path

        expect(response.body).to include('type="checkbox"')
        expect(response.body).to include("check-list")
        expect(response.body).not_to include("multiple=\"multiple\"")
      end

      it "creates and attaches tags typed inline" do
        record = create(:post)

        patch admin_post_path(record), params: { post: { new_tag_names: "Ruby, Local LLMs" } }

        expect(record.reload.tags.map(&:name)).to contain_exactly("Ruby", "Local LLMs")
      end

      it "reuses an existing tag rather than duplicating it" do
        existing = create(:tag, name: "Ruby")
        record = create(:post)

        expect {
          patch admin_post_path(record), params: { post: { new_tag_names: "ruby" } }
        }.not_to change(Tag, :count)

        expect(record.reload.tags).to eq([ existing ])
      end

      it "ignores blank entries in the tag list" do
        record = create(:post)

        patch admin_post_path(record), params: { post: { new_tag_names: "Ruby, , ,  " } }

        expect(record.reload.tags.map(&:name)).to eq([ "Ruby" ])
      end
    end

    describe "featured image" do
      def png_upload(filename: "hero.png")
        Rack::Test::UploadedFile.new(
          StringIO.new("\x89PNG\r\n\x1a\n data"), "image/png", original_filename: filename
        )
      end

      it "shows a thumbnail grid of existing media" do
        item = create(:media_item, :stored)

        get new_admin_post_path

        expect(response.body).to include("media-grid")
        expect(response.body).to include(item.url)
      end

      it "leaves unstored media out of the picker" do
        pending_item = create(:media_item)

        get new_admin_post_path

        expect(response.body).not_to include(pending_item.url)
      end

      it "uploads a new image and attaches it" do
        record = create(:post)

        expect {
          patch admin_post_path(record), params: { post: { featured_image: png_upload } }
        }.to change(MediaItem, :count).by(1)

        expect(record.reload.featured_media_item).to eq(MediaItem.last)
        expect(ObjectStore.current.exist?(MediaItem.last.key)).to be(true)
      end

      it "keeps other edits when the upload is rejected" do
        record = create(:post, title: "Original")
        bad = Rack::Test::UploadedFile.new(StringIO.new("x"), "application/pdf", original_filename: "a.pdf")

        patch admin_post_path(record), params: { post: { title: "Changed", featured_image: bad } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(record.reload.title).to eq("Original")
        expect(response.body).to include("not an allowed image type")
      end

      it "clears the featured image when None is chosen" do
        item = create(:media_item, :stored)
        record = create(:post, featured_media_item: item)

        patch admin_post_path(record), params: { post: { featured_media_item_id: "" } }

        expect(record.reload.featured_media_item).to be_nil
      end
    end
  end
end
