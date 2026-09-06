module Themes
  module Drops
    class SiteDrop < BaseDrop
      def title = h(KantanPress::Config.site_title)
      def description = h(KantanPress::Config.site_description)
      def url = routes.root_path
      def feed_url = routes.feed_path

      # Every template gets `site`, so a theme can put the search field
      # wherever it likes rather than only on the search page itself.
      def search_url = routes.search_path

      # A theme renders the favicon; it never chooses it. The app hands over a
      # URL and a type, so installing a theme cannot quietly change the icon a
      # site has been wearing.
      def favicon_url = h(Branding::Favicon.current&.url || "/icon.png")
      def favicon_type = h(Branding::Favicon.current&.content_type || "image/png")

      # Only terms that have something published under them. A nav link to an
      # empty archive is a dead end, and WordPress hides empty terms from
      # wp_list_categories by default for the same reason.
      #
      # The count comes back with the row rather than a query per term.
      def categories
        with_live_posts(Category).map { |category| CategoryDrop.new(category) }
      end

      def tags
        with_live_posts(Tag).map { |tag| TagDrop.new(tag) }
      end

      def pages
        Post.live.type_page.order(:title).map { |page| PostDrop.new(page) }
      end

      private
        def with_live_posts(model)
          model.alphabetical
               .joins(:posts).merge(Post.live)
               .group("#{model.table_name}.id")
               .select("#{model.table_name}.*, COUNT(DISTINCT posts.id) AS live_posts_count")
        end
    end
  end
end
