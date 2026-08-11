module Admin
  class PostsController < BaseController
    before_action :set_post, only: %i[edit update destroy publish unpublish]

    def index
      @posts = Post.includes(:categories, :tags)
                   .order(Arel.sql("COALESCE(published_at, created_at) DESC"))
      @posts = @posts.where(status: params[:status]) if Post.statuses.key?(params[:status])
      @posts = @posts.where("title LIKE ?", "%#{params[:q]}%") if params[:q].present?
      @counts = Post.group(:status).count
    end

    def new
      @post = Post.new(status: :draft, post_type: :post)
    end

    def create
      @post = Post.new(post_attributes)
      @post.author ||= Current.user

      if apply_media_and_tags(@post) && @post.save
        redirect_to edit_admin_post_path(@post), notice: "Post created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      @post.assign_attributes(post_attributes)

      if apply_media_and_tags(@post) && @post.save
        redirect_to edit_admin_post_path(@post), notice: "Post saved."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @post.destroy
      redirect_to admin_posts_path, notice: "Post deleted."
    end

    def publish
      @post.update(status: :published, published_at: @post.published_at || Time.current)
      redirect_back fallback_location: admin_posts_path, notice: "Post published."
    end

    def unpublish
      @post.update(status: :draft)
      redirect_back fallback_location: admin_posts_path, notice: "Post moved to drafts."
    end

    private
      def set_post
        @post = Post.find(params[:id])
      end

      # featured_image and new_tag_names are permitted so that a submission
      # carrying only one of them still satisfies expect, then dropped before
      # assignment since neither is a column.
      def post_params
        params.expect(post: [ :title, :slug, :content, :excerpt, :status, :post_type,
                              :published_at, :featured_media_item_id,
                              :featured_image, :new_tag_names,
                              { category_ids: [], tag_ids: [] } ])
      end

      def post_attributes
        post_params.except(:featured_image, :new_tag_names)
      end

      # The upload has to reach the object store before the post can reference
      # it, and tags may need creating, so both happen before save.
      def apply_media_and_tags(post)
        upload = post_params[:featured_image]

        post.featured_media_item = MediaUploader.new.call(upload) if upload.present?
        post.add_tag_names(post_params[:new_tag_names])
        true
      rescue MediaUploader::Error, ObjectStore::UploadError => e
        post.errors.add(:base, "Featured image: #{e.message}")
        false
      end
  end
end
