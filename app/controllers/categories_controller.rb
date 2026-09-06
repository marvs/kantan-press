class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.find_by!(slug: params[:slug])
    @posts = @category.posts.live.newest_first.includes(:author, :categories, :featured_media_item)

    render_themed("archive", fallback: :show,
                  page: Themes::Drops::PageDrop.new(title: @category.name,
                                                    description: @category.description,
                                                    canonical_url: category_url(@category.slug)),
                  posts: post_drops(@posts),
                  archive: Themes::Drops::ArchiveDrop.new(title: @category.name, kind: "category",
                                                          description: @category.description),
                  category: Themes::Drops::CategoryDrop.new(@category))
  end
end
