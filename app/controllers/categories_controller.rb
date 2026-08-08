class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.find_by!(slug: params[:slug])
    @posts = @category.posts.live.newest_first.includes(:featured_media_item)
  end
end
