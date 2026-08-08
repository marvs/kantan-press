class PostsController < ApplicationController
  allow_unauthenticated_access

  PER_PAGE = 10

  def index
    # WordPress's /?p=123 permalinks land here; resolve them before rendering.
    if params[:p].present? && (post = Post.find_by(wp_post_id: params[:p]))
      return redirect_to post_path(post.slug), status: :moved_permanently
    end

    @page = [ params[:page].to_i, 1 ].max
    @posts = Post.live.type_post.newest_first.includes(:categories, :featured_media_item)
                 .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @total_pages = (Post.live.type_post.count / PER_PAGE.to_f).ceil
  end

  def show
    @post = Post.live.includes(:categories, :tags).find_by(slug: params[:slug])
    return render :show if @post

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
end
