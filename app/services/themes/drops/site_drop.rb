module Themes
  module Drops
    class SiteDrop < BaseDrop
      def title = h(KantanPress::Config.site_title)
      def description = h(KantanPress::Config.site_description)
      def url = routes.root_path
      def feed_url = routes.feed_path

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
