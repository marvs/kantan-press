module Themes
  module Drops
    class CategoryDrop < BaseDrop
      def initialize(category)
        @category = category
        super()
      end

      def name = h(@category.name)
      def slug = @category.slug
      def url = routes.category_path(@category.slug)
      def description = h(@category.description)

      # Present when the term came from SiteDrop, which selects it alongside the
      # row; falls back to a query for a term reached any other way.
      def post_count
        return @category.live_posts_count if @category.has_attribute?(:live_posts_count)

        @category.posts.live.count
      end
    end
  end
end
