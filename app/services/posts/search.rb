module Posts
  # Finds published articles whose title or body contains every word the reader
  # typed, in any order.
  #
  # The body is matched against posts.content_plain rather than posts.content,
  # because content is Gutenberg block markup: a query for "image" would
  # otherwise match every wp-block-image wrapper instead of the writing.
  #
  # LIKE '%term%' cannot use an index in SQLite, so this is a scan. That is the
  # right trade at this size — a blog of a few hundred posts is a megabyte or so
  # of text — but it is also the ceiling: there is no relevance ranking and no
  # stemming, and results come back newest-first like every other listing.
  class Search
    # Two caps bound the cost of a hostile query without changing what an
    # ordinary one does. Ten words is far past what anyone types.
    MAX_TERMS = 10
    MAX_QUERY_LENGTH = 100

    # ESCAPE is not optional: sanitize_sql_like escapes with a backslash, and
    # SQLite only honours it when the clause says so. Without this a reader who
    # types "%" would get the whole blog back.
    MATCH_SQL = <<~SQL.squish.freeze
      posts.title LIKE :pattern ESCAPE '\\'
        OR posts.content_plain LIKE :pattern ESCAPE '\\'
    SQL

    def self.call(query) = new(query).results

    def initialize(query)
      @terms = query.to_s.first(MAX_QUERY_LENGTH).split.first(MAX_TERMS)
    end

    def results
      return Post.none if @terms.empty?

      @terms.reduce(Post.live.type_post.newest_first) do |scope, term|
        scope.where(MATCH_SQL, pattern: "%#{Post.sanitize_sql_like(term)}%")
      end
    end
  end
end
