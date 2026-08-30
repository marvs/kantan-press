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

      # What the browser tab shows. Separate from #title because og:title wants
      # the bare one — a share card that repeats the site name reads as noise.
      # The home page passes the site title as its own title, so guard against
      # saying it twice.
      def browser_title
        site_title = KantanPress::Config.site_title

        return h(site_title) if @title.blank? || @title == site_title

        "#{h(@title)} - #{h(site_title)}"
      end
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
