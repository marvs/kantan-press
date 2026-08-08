atom_feed do |feed|
  feed.title("Kantan Press")
  feed.updated(@posts.first&.published_at)

  @posts.each do |post|
    feed.entry(post, url: post_url(post.slug), published: post.published_at) do |entry|
      entry.title(post.title)
      entry.content(post.content.to_s, type: "html")
      entry.author { |author| author.name(post.author&.email_address.presence || "Kantan Press") }
    end
  end
end
