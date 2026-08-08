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
      @post = Post.new(post_params)
      @post.author ||= Current.user

      if @post.save
        redirect_to edit_admin_post_path(@post), notice: "Post created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @post.update(post_params)
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

      def post_params
        params.expect(post: [ :title, :slug, :content, :excerpt, :status, :post_type,
                              :published_at, :featured_media_item_id,
                              { category_ids: [], tag_ids: [] } ])
      end
  end
end
