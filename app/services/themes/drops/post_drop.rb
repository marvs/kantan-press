module Themes
  module Drops
    class PostDrop < BaseDrop
      def initialize(post)
        @post = post
        super()
      end

      def id = @post.id
      def title = h(@post.title)
      def slug = @post.slug
      def url = routes.post_path(@post.slug)
      def published_at = @post.published_at
      def updated_at = @post.updated_at
      def page = @post.type_page?
      def author_name = h(@post.author&.email_address.to_s.split("@").first)

      # The author's own content, emitted exactly as WordPress served it. The
      # embed pass is the one transformation, matching PostsHelper#render_post_body.
      def body_html = Wordpress::EmbedRenderer.call(@post.content)

      def excerpt = h(plain_excerpt)

      # A hand-written excerpt may legitimately contain markup, as WordPress
      # allows; without one this falls back to the trimmed plain body.
      def excerpt_html
        @post.excerpt.presence || h(plain_excerpt)
      end

      def word_count = plain_body.split.size

      def categories = @post.categories.map { |category| CategoryDrop.new(category) }
      def tags = @post.tags.map { |tag| TagDrop.new(tag) }
      # Memoised: a theme is free to ask for the count and then loop the
      # comments, and each call would otherwise be another query.
      def comments = comment_drops
      def comment_count = comment_drops.size

      def featured_image
        media = @post.featured_media_item
        MediaItemDrop.new(media) if media&.stored?
      end

      private
        def comment_drops
          @comment_drops ||= @post.approved_comments.map { |comment| CommentDrop.new(comment) }
        end

        # String#truncate, not the view helper: the helper escapes its result,
        # and this text is escaped once on the way out by #excerpt.
        def plain_excerpt
          source = @post.excerpt.presence || @post.content

          KantanPress::PlainText.call(source).truncate(220, separator: " ")
        end

        def plain_body
          @plain_body ||= KantanPress::PlainText.call(@post.content)
        end
    end
  end
end
