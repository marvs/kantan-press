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

  # A hand-written excerpt may contain markup, as WordPress allows, so it is
  # rendered rather than escaped. Falls back to trimming the body, which
  # WordPress leaves empty unless an excerpt was written by hand.
  def post_excerpt(post, length: 220)
    return post.excerpt.html_safe if post.excerpt.present?

    truncate(excerpt_plain_text(post), length: length, separator: " ")
  end

  # Plain text version for meta tags and anywhere markup would be wrong.
  def excerpt_plain_text(post, length: 220)
    source = post.excerpt.presence || post.content.to_s.gsub(/<!--.*?-->/m, " ")

    truncate(strip_tags(source).squish, length: length, separator: " ")
  end

  def post_date(post)
    return nil unless post.published_at

    tag.time(l(post.published_at.to_date, format: :long),
             datetime: post.published_at.iso8601)
  end
end
