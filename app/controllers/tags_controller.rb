class TagsController < ApplicationController
  allow_unauthenticated_access

  def show
    @tag = Tag.find_by!(slug: params[:slug])
    @posts = @tag.posts.live.newest_first.includes(:featured_media_item)
  end
end
