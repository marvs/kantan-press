module Themes
  module Drops
    class CommentDrop < BaseDrop
      # Comment bodies are the one field on the public site that was written by
      # someone other than the author, so this is the only drop that sanitizes
      # rather than escapes: simple_format matches how the site has always
      # rendered imported comments.
      SAFE_URL_SCHEMES = %w[http https].freeze

      def initialize(comment)
        @comment = comment
        super()
      end

      def id = @comment.id
      def author_name = h(@comment.author_name.presence || "Anonymous")
      def content_html = view.simple_format(@comment.content.to_s).to_s
      def published_at = @comment.published_at
      def reply = @comment.parent_id.present?

      def author_url
        url = @comment.author_url.to_s
        return "" if url.blank?

        parsed = URI.parse(url)
        SAFE_URL_SCHEMES.include?(parsed.scheme) ? h(url) : ""
      rescue URI::InvalidURIError
        ""
      end
    end
  end
end
