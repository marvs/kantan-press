class PostsController < ApplicationController
  allow_unauthenticated_access

  def index
    # WordPress's /?p=123 permalinks land here; resolve them before rendering.
    if params[:p].present? && (post = Post.find_by(wp_post_id: params[:p]))
      return redirect_to post_path(post.slug), status: :moved_permanently
    end

    per_page = KantanPress::Config.posts_per_page
    @page = [ params[:page].to_i, 1 ].max
    @posts = Post.live.type_post.newest_first.includes(:author, :categories, :featured_media_item)
                 .offset((@page - 1) * per_page).limit(per_page)
    @total_pages = (Post.live.type_post.count / per_page.to_f).ceil

    render_themed("index", fallback: :index,
                  page: Themes::Drops::PageDrop.new(
                    title: KantanPress::Config.site_title,
                    description: KantanPress::Config.site_description,
                    canonical_url: @page > 1 ? root_url(page: @page) : root_url
                  ),
                  posts: post_drops(@posts),
                  pagination: pagination_drop(@page, @total_pages) { |page| root_path(page: page) })
  end

  def show
    @post = Post.live.includes(:author, :categories, :tags).find_by(slug: params[:slug])

    if @post
      return render_themed(@post.type_page? ? "page" : "post", fallback: :show,
                           page: post_page_drop(@post),
                           post: Themes::Drops::PostDrop.new(@post))
    end

    # An old permalink structure (date-based URLs, renamed slugs) resolves here.
    if (redirect = Redirect.lookup("/#{params[:slug]}"))
      return redirect_to redirect.to_path, status: redirect.status
    end

    raise ActiveRecord::RecordNotFound
  end

  def feed
    @posts = Post.live.type_post.newest_first.limit(20)

    respond_to do |format|
      format.atom
    end
  end

  private
    # The head metadata the ERB view used to set with content_for, moved here so
    # it does not depend on a theme author remembering the og: tags.
    def post_page_drop(post)
      Themes::Drops::PageDrop.new(
        title: post.title,
        description: helpers.excerpt_plain_text(post, length: 160),
        canonical_url: post_url(post.slug),
        image_url: (post.featured_media_item.url if post.featured_media_item&.stored?),
        kind: "article"
      )
    end
end
