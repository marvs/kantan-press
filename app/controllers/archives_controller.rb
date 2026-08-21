class ArchivesController < ApplicationController
  allow_unauthenticated_access

  # Serves WordPress's /YYYY/MM/ sidebar archive links.
  def show
    @year = params[:year].to_i
    @month = params[:month].to_i
    raise ActiveRecord::RecordNotFound unless @month.between?(1, 12)

    @posts = Post.live.type_post.in_month(@year, @month).newest_first
                .includes(:author, :categories, :featured_media_item)

    render_themed("archive", fallback: :show,
                  page: Themes::Drops::PageDrop.new(title: "#{Date::MONTHNAMES[@month]} #{@year}"),
                  posts: post_drops(@posts),
                  archive: { "title" => "#{Date::MONTHNAMES[@month]} #{@year}", "kind" => "month",
                             "year" => @year, "month" => @month })
  end
end
