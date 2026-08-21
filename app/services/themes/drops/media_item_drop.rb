module Themes
  module Drops
    class MediaItemDrop < BaseDrop
      def initialize(media_item)
        @media_item = media_item
        super()
      end

      def url = @media_item.url
      def alt = h(@media_item.alt_text)
      def title = h(@media_item.title)
      def caption = h(@media_item.caption)
      def width = @media_item.width
      def height = @media_item.height
      def filename = h(@media_item.filename)
    end
  end
end
