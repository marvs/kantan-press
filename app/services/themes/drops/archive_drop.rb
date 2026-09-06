module Themes
  module Drops
    # The heading on a listing that is not the home page: a category, a tag, a
    # month, or a set of search results.
    #
    # This is a drop rather than the plain Hash it began as, because a Hash
    # handed to a template reaches the page raw — only a drop escapes. Term
    # names come out of a WordPress import, so the Hash meant an imported
    # category called <script>…</script> put that script into the archive page.
    class ArchiveDrop < BaseDrop
      def initialize(title:, kind:, description: nil, year: nil, month: nil)
        @title = title
        @kind = kind
        @description = description
        @year = year
        @month = month
        super()
      end

      def title = h(@title)
      def kind = h(@kind)
      def description = optional(@description)

      # Numbers the controller derived, not text anyone typed, and a theme wants
      # them as numbers for {{ archive.year | archive_url: archive.month }}.
      def year = @year
      def month = @month
    end
  end
end
