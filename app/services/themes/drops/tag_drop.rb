module Themes
  module Drops
    class TagDrop < BaseDrop
      def initialize(tag)
        @tag = tag
        super()
      end

      def name = h(@tag.name)
      def slug = @tag.slug
      def url = routes.tag_path(@tag.slug)

      # Present when the term came from SiteDrop, which selects it alongside the
      # row; falls back to a query for a term reached any other way.
      def post_count
        return @tag.live_posts_count if @tag.has_attribute?(:live_posts_count)

        @tag.posts.live.count
      end
    end
  end
end
