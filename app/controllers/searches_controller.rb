class SearchesController < ApplicationController
  allow_unauthenticated_access

  def show
    @query = params[:q].to_s.strip
    matches = Posts::Search.call(@query)

    per_page = KantanPress::Config.posts_per_page
    @page = [ params[:page].to_i, 1 ].max
    @total_count = matches.count
    @total_pages = (@total_count / per_page.to_f).ceil
    @posts = matches.includes(:author, :categories, :featured_media_item)
                    .offset((@page - 1) * per_page).limit(per_page)

    render_themed("search", fallback: :show,
                  page: Themes::Drops::PageDrop.new(title: heading, canonical_url: canonical_url,
                                                    robots: "noindex, follow"),
                  posts: post_drops(@posts),
                  pagination: pagination_drop(@page, @total_pages) { |page| search_path(q: @query, page: page) },
                  search: Themes::Drops::SearchDrop.new(query: @query, total_count: @total_count),
                  archive: Themes::Drops::ArchiveDrop.new(title: heading, kind: "search"))
  end

  private
    def heading
      @query.present? ? "Search results for \"#{@query}\"" : "Search"
    end

    def canonical_url
      @query.present? ? search_url(q: @query) : search_url
    end
end
