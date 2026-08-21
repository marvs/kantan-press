module Themes
  module Drops
    # Neighbouring-page links for an index or archive. The urls come back nil at
    # the ends, so a theme tests them with {% if pagination.next_url %}.
    class PaginationDrop < BaseDrop
      def initialize(current_page:, total_pages:, path_builder:)
        @current_page = current_page
        @total_pages = total_pages
        @path_builder = path_builder
        super()
      end

      attr_reader :current_page, :total_pages

      def previous_page
        current_page - 1 if current_page > 1
      end

      def next_page
        current_page + 1 if current_page < total_pages
      end

      def previous_url
        @path_builder.call(previous_page) if previous_page
      end

      def next_url
        @path_builder.call(next_page) if next_page
      end
    end
  end
end
