module Themes
  module Drops
    class SiteDrop < BaseDrop
      def title = h(KantanPress::Config.site_title)
      def description = h(KantanPress::Config.site_description)
      def url = routes.root_path
      def feed_url = routes.feed_path

      def categories
        Category.alphabetical.map { |category| CategoryDrop.new(category) }
      end

      def tags
        Tag.alphabetical.map { |tag| TagDrop.new(tag) }
      end

      def pages
        Post.live.type_page.order(:title).map { |page| PostDrop.new(page) }
      end
    end
  end
end
