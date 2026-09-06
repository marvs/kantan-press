module Themes
  module Drops
    # What a search result page needs beyond the posts themselves.
    #
    # `query` is the one field on any drop that carries input straight from a
    # stranger's URL back onto the page, so the escaping BaseDrop does is what
    # stands between a crafted link and reflected XSS.
    class SearchDrop < BaseDrop
      def initialize(query:, total_count:)
        @query = query.to_s
        @total_count = total_count
        super()
      end

      def query = h(@query)
      def total_count = @total_count

      # False when the reader has not typed anything yet, so a theme can show a
      # prompt rather than "no results" on a page nobody has searched from.
      def performed = @query.present?
    end
  end
end
