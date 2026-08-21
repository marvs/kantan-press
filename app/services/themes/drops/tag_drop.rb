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
    end
  end
end
