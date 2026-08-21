class TagsController < ApplicationController
  allow_unauthenticated_access

  def show
    @tag = Tag.find_by!(slug: params[:slug])
    @posts = @tag.posts.live.newest_first.includes(:author, :categories, :featured_media_item)

    render_themed("archive", fallback: :show,
                  page: Themes::Drops::PageDrop.new(title: @tag.name, canonical_url: tag_url(@tag.slug)),
                  posts: post_drops(@posts),
                  archive: { "title" => @tag.name, "kind" => "tag" },
                  tag: Themes::Drops::TagDrop.new(@tag))
  end
end
