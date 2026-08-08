module Wordpress
  # Turns a WordPress WXR export into Kantan Press records.
  #
  # Order matters: taxonomies first, then attachments (so a post's featured
  # image can be resolved), then posts. Images are *registered* here and
  # downloaded by Wordpress::FetchMediaJob afterwards, which keeps a 200-image
  # migration from blocking the import and makes individual failures retryable.
  #
  # Re-running over the same export updates in place rather than duplicating —
  # records are matched on their WordPress IDs.
  class Importer
    # WordPress has more states than we care about; anything not publicly
    # visible lands as a draft rather than being dropped.
    STATUS_MAP = {
      "publish" => "published",
      "draft" => "draft",
      "pending" => "draft",
      "private" => "draft",
      "future" => "draft",
      "auto-draft" => "draft"
    }.freeze

    IMPORTABLE_TYPES = %w[post page].freeze

    attr_reader :document, :legacy_site_url, :author, :stats, :errors

    def initialize(path:, legacy_site_url: nil, author: nil, enqueue_media: true)
      @document = WxrDocument.open(path)
      @legacy_site_url = legacy_site_url.presence ||
                         KantanPress::Config.legacy_site_url.presence ||
                         document.base_blog_url
      @author = author
      @enqueue_media = enqueue_media
      @stats = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @errors = []
      # An image is commonly registered twice — once as an <item> attachment and
      # again from the <img src> in a post body. Track what this run already
      # queued so it downloads once, while a later re-run can still retry
      # anything left pending or failed.
      @enqueued_media_ids = Set.new
    end

    def call
      import_categories
      import_tags
      import_attachments
      import_posts

      { stats: stats.transform_values(&:to_h), errors: errors }
    end

    def rewriter
      @rewriter ||= ContentRewriter.new(
        legacy_site_url: legacy_site_url,
        media_base_url: KantanPress::Config.media_base_url
      )
    end

    private
      def enqueue_media? = @enqueue_media

      def track(kind, outcome) = stats[kind.to_s][outcome.to_s] += 1

      def note_error(context, exception)
        errors << "#{context}: #{exception.class} #{exception.message}"
      end

      # --- taxonomies -----------------------------------------------------

      def import_categories
        # Two passes so a child can reference a parent defined after it.
        document.categories.each do |term|
          record = Category.find_or_initialize_by(slug: term.slug)
          existed = record.persisted?
          record.assign_attributes(name: term.name.presence || term.slug,
                                   description: term.description.presence,
                                   wp_term_id: term.wp_term_id)
          record.save!
          track(:categories, existed ? :updated : :created)
        rescue ActiveRecord::RecordInvalid => e
          note_error("category #{term.slug}", e)
          track(:categories, :failed)
        end

        document.categories.each do |term|
          next if term.parent_slug.blank?

          child = Category.find_by(slug: term.slug)
          parent = Category.find_by(slug: term.parent_slug)
          child.update(parent: parent) if child && parent
        end
      end

      def import_tags
        document.tags.each do |term|
          record = Tag.find_or_initialize_by(slug: term.slug)
          existed = record.persisted?
          record.assign_attributes(name: term.name.presence || term.slug,
                                   wp_term_id: term.wp_term_id)
          record.save!
          track(:tags, existed ? :updated : :created)
        rescue ActiveRecord::RecordInvalid => e
          note_error("tag #{term.slug}", e)
          track(:tags, :failed)
        end
      end

      # --- media ----------------------------------------------------------

      def import_attachments
        document.attachments.each do |item|
          url = item.attachment_url
          next track(:media, :skipped) if url.blank?

          width, height = dimensions_from(item.meta["_wp_attachment_metadata"])
          register_media(url,
                         wp_attachment_id: item.wp_post_id,
                         title: item.title,
                         alt_text: item.meta["_wp_attachment_image_alt"],
                         width: width,
                         height: height)
        rescue StandardError => e
          note_error("attachment #{item.attachment_url}", e)
          track(:media, :failed)
        end
      end

      # Creates the row and queues the download. Returns the MediaItem, or nil
      # if the URL yields no usable key.
      def register_media(url, wp_attachment_id: nil, title: nil, alt_text: nil, width: nil, height: nil)
        key = MediaFetcher.key_for(url)
        return nil if key.blank?

        item = MediaItem.find_or_initialize_by(key: key)
        existed = item.persisted?

        item.filename = File.basename(key)
        item.source_url ||= url
        item.wp_attachment_id ||= wp_attachment_id
        item.title = title.presence if item.title.blank?
        item.alt_text = alt_text.presence if item.alt_text.blank?
        item.width ||= width
        item.height ||= height
        item.save!

        track(:media, existed ? :existing : :created)

        if enqueue_media? && !item.stored? && @enqueued_media_ids.add?(item.id)
          FetchMediaJob.perform_later(item.id)
          track(:media, :enqueued)
        end

        item
      end

      # _wp_attachment_metadata is a PHP-serialized hash. Only the top-level
      # width and height are worth pulling out; every generated size variant is
      # discovered from post content instead, which is what actually gets used.
      def dimensions_from(serialized)
        return [ nil, nil ] if serialized.blank?

        [ serialized[/s:5:"width";i:(\d+)/, 1]&.to_i,
          serialized[/s:6:"height";i:(\d+)/, 1]&.to_i ]
      end

      # --- posts ----------------------------------------------------------

      def import_posts
        document.posts.each do |item|
          next track(:posts, :skipped) unless IMPORTABLE_TYPES.include?(item.post_type)

          import_post(item)
        rescue StandardError => e
          note_error("post #{item.slug.presence || item.title}", e)
          track(:posts, :failed)
        end
      end

      def import_post(item)
        post = find_or_initialize_post(item)
        existed = post.persisted?

        # Any uploads URL in the body — including srcset variants WordPress
        # generated but never listed as attachments — becomes a media row.
        rewriter.upload_urls(item.content).each { |url| register_media(url) }

        post.assign_attributes(
          title: item.title.presence || "(untitled)",
          slug: item.slug.presence || item.title.to_s.parameterize.presence || "post-#{item.wp_post_id}",
          content: rewriter.rewrite(item.content),
          excerpt: item.excerpt.presence,
          status: STATUS_MAP.fetch(item.status, "draft"),
          post_type: item.post_type,
          published_at: item.published_at,
          wp_post_id: item.wp_post_id,
          author: author,
          featured_media_item: featured_media_for(item)
        )
        post.save!

        assign_terms(post, item)
        import_comments(post, item)
        record_permalink_redirect(post, item)

        track(:posts, existed ? :updated : :created)
      end

      def find_or_initialize_post(item)
        (item.wp_post_id && Post.find_by(wp_post_id: item.wp_post_id)) ||
          (item.slug.present? && Post.find_by(slug: item.slug)) ||
          Post.new
      end

      def featured_media_for(item)
        thumbnail_id = item.meta["_thumbnail_id"].presence
        return nil if thumbnail_id.blank?

        MediaItem.find_by(wp_attachment_id: thumbnail_id.to_i)
      end

      def assign_terms(post, item)
        post.categories = Category.where(slug: item.category_slugs) if item.category_slugs.any?
        post.tags = Tag.where(slug: item.tag_slugs) if item.tag_slugs.any?
      end

      def import_comments(post, item)
        return if item.comments.empty?

        by_wp_id = {}

        item.comments.each do |source|
          comment = Comment.find_or_initialize_by(wp_comment_id: source.wp_comment_id) if source.wp_comment_id
          comment ||= Comment.new
          existed = comment.persisted?

          comment.assign_attributes(
            post: post,
            author_name: source.author_name.presence,
            author_email: source.author_email.presence,
            author_url: source.author_url.presence,
            content: source.content,
            approved: source.approved,
            published_at: source.published_at
          )
          comment.save!

          by_wp_id[source.wp_comment_id] = comment if source.wp_comment_id
          track(:comments, existed ? :updated : :created)
        rescue ActiveRecord::RecordInvalid => e
          note_error("comment #{source.wp_comment_id} on #{post.slug}", e)
          track(:comments, :failed)
        end

        # Second pass so a reply can point at a parent defined after it.
        item.comments.each do |source|
          next if source.wp_parent_id.to_i.zero?

          child = by_wp_id[source.wp_comment_id]
          parent = by_wp_id[source.wp_parent_id]
          child.update(parent: parent) if child && parent
        end
      end

      # If the old permalink structure differs from "/slug" — date-based URLs,
      # for instance — keep the old path working with a 301.
      def record_permalink_redirect(post, item)
        old_path = begin
          URI.parse(item.link.to_s).path.presence
        rescue URI::InvalidURIError
          nil
        end
        return if old_path.blank?

        normalized_old = Redirect.normalize(old_path)
        return if normalized_old == Redirect.normalize("/#{post.slug}")

        redirect = Redirect.find_or_initialize_by(from_path: normalized_old)
        redirect.to_path = "/#{post.slug}"
        redirect.save!
        track(:redirects, :created)
      rescue ActiveRecord::RecordInvalid => e
        note_error("redirect for #{post.slug}", e)
      end
  end
end
