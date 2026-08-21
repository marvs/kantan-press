module Themes
  module Drops
    # Head metadata for whatever page is being rendered.
    #
    # The app computes this rather than the theme, because a WordPress migration
    # lives or dies on its canonical URLs and og: tags, and those should not
    # depend on a theme author getting them right.
    class PageDrop < BaseDrop
      def initialize(title:, description: nil, canonical_url: nil, image_url: nil, kind: "website")
        @title = title
        @description = description
        @canonical_url = canonical_url
        @image_url = image_url
        @kind = kind
        super()
      end

      def title = h(@title)
      def kind = h(@kind)
      def description = optional(@description)
      def canonical_url = optional(@canonical_url)
      def image_url = optional(@image_url)

      private
        # nil rather than "" so a theme can write {% if page.image_url %}.
        def optional(value)
          h(value) if value.present?
        end
    end
  end
end
