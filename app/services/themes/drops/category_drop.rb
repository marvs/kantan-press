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
    end
  end
end
