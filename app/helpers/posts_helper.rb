module PostsHelper
  # Imported content is WordPress block markup: HTML with block delimiters in
  # comments. Browsers ignore comments, so it renders correctly verbatim — no
  # block renderer is needed for core blocks.
  #
  # This is the author's own content, so it is emitted unescaped, exactly as
  # WordPress served it.
  def render_post_body(post)
    post.content.to_s.html_safe
  end

  # Falls back to trimming the body when a post has no explicit excerpt —
  # WordPress leaves excerpt:encoded empty unless one was written by hand.
  def post_excerpt(post, length: 220)
    return post.excerpt if post.excerpt.present?

    plain = strip_tags(post.content.to_s.gsub(/<!--.*?-->/m, " ")).squish
    truncate(plain, length: length, separator: " ")
  end

  def post_date(post)
    return nil unless post.published_at

    tag.time(l(post.published_at.to_date, format: :long),
             datetime: post.published_at.iso8601)
  end
end
