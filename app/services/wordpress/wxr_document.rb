require "nokogiri"

module Wordpress
  # Reads a WordPress eXtended RSS export (Tools -> Export -> All content).
  #
  # WXR is RSS with a wp: namespace bolted on. Everything interesting lives
  # either on <channel> (the taxonomy definitions) or in <item> elements, which
  # are overloaded: posts, pages, attachments, nav menu items and revisions all
  # share the same shape and are told apart by <wp:post_type>.
  class WxrDocument
    # WXR 1.1 and 1.2 differ only in the namespace URI, so the real ones are
    # read off the document and these are a fallback for hand-made fixtures.
    FALLBACK_NAMESPACES = {
      "wp" => "http://wordpress.org/export/1.2/",
      "content" => "http://purl.org/rss/1.0/modules/content/",
      "excerpt" => "http://wordpress.org/export/1.2/excerpt/",
      "dc" => "http://purl.org/dc/elements/1.1/"
    }.freeze

    Term = Data.define(:wp_term_id, :name, :slug, :description, :parent_slug)
    Comment = Data.define(:wp_comment_id, :author_name, :author_email, :author_url,
                          :content, :published_at, :approved, :wp_parent_id)
    Item = Data.define(:wp_post_id, :title, :slug, :content, :excerpt, :status,
                       :post_type, :published_at, :link, :attachment_url,
                       :category_slugs, :tag_slugs, :meta, :comments)

    attr_reader :doc

    def self.open(path)
      new(File.read(path))
    end

    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      @doc.remove_namespaces! if @doc.root.nil?
    end

    # The site the export came from, e.g. "https://techandfi.com". Used as the
    # default for URL rewriting so the operator rarely has to supply it.
    def base_blog_url
      text_at(channel, "wp:base_blog_url").presence || text_at(channel, "link")
    end

    def site_title = text_at(channel, "title")

    def categories
      channel.xpath("wp:category", namespaces).map do |node|
        Term.new(
          wp_term_id: text_at(node, "wp:term_id").presence&.to_i,
          name: text_at(node, "wp:cat_name"),
          slug: text_at(node, "wp:category_nicename"),
          description: text_at(node, "wp:category_description"),
          parent_slug: text_at(node, "wp:category_parent").presence
        )
      end
    end

    def tags
      channel.xpath("wp:tag", namespaces).map do |node|
        Term.new(
          wp_term_id: text_at(node, "wp:term_id").presence&.to_i,
          name: text_at(node, "wp:tag_name"),
          slug: text_at(node, "wp:tag_slug"),
          description: text_at(node, "wp:tag_description"),
          parent_slug: nil
        )
      end
    end

    # Every <item>, already typed. Callers filter by post_type.
    def items
      channel.xpath("item", namespaces).map { |node| build_item(node) }
    end

    def attachments = items.select { |item| item.post_type == "attachment" }

    def posts = items.select { |item| %w[post page].include?(item.post_type) }

    private
      def channel
        @channel ||= doc.at_xpath("//channel") or
          raise ArgumentError, "not a WordPress export: no <channel> element found"
      end

      def namespaces
        @namespaces ||= begin
          declared = doc.collect_namespaces.transform_keys { |key| key.delete_prefix("xmlns:") }
          FALLBACK_NAMESPACES.merge(declared.slice(*FALLBACK_NAMESPACES.keys))
        end
      end

      def build_item(node)
        Item.new(
          wp_post_id: text_at(node, "wp:post_id").presence&.to_i,
          title: text_at(node, "title"),
          slug: text_at(node, "wp:post_name"),
          content: text_at(node, "content:encoded"),
          excerpt: text_at(node, "excerpt:encoded"),
          status: text_at(node, "wp:status"),
          post_type: text_at(node, "wp:post_type"),
          published_at: parse_time(text_at(node, "wp:post_date_gmt"), text_at(node, "wp:post_date")),
          link: text_at(node, "link"),
          attachment_url: text_at(node, "wp:attachment_url").presence,
          category_slugs: term_slugs(node, "category"),
          tag_slugs: term_slugs(node, "post_tag"),
          meta: postmeta(node),
          comments: comments(node)
        )
      end

      def term_slugs(node, domain)
        node.xpath("category", namespaces)
            .select { |el| el["domain"] == domain }
            .filter_map { |el| el["nicename"].presence }
            .uniq
      end

      def postmeta(node)
        node.xpath("wp:postmeta", namespaces).each_with_object({}) do |meta, acc|
          key = text_at(meta, "wp:meta_key")
          acc[key] = text_at(meta, "wp:meta_value") if key.present?
        end
      end

      def comments(node)
        node.xpath("wp:comment", namespaces).map do |comment|
          Comment.new(
            wp_comment_id: text_at(comment, "wp:comment_id").presence&.to_i,
            author_name: text_at(comment, "wp:comment_author"),
            author_email: text_at(comment, "wp:comment_author_email"),
            author_url: text_at(comment, "wp:comment_author_url"),
            content: text_at(comment, "wp:comment_content"),
            published_at: parse_time(text_at(comment, "wp:comment_date_gmt"),
                                     text_at(comment, "wp:comment_date")),
            approved: text_at(comment, "wp:comment_approved") == "1",
            wp_parent_id: text_at(comment, "wp:comment_parent").presence&.to_i
          )
        end
      end

      def text_at(node, path)
        node.at_xpath(path, namespaces)&.text.to_s.strip
      end

      # WordPress writes "0000-00-00 00:00:00" for records that were never
      # published, and _gmt is empty on some older exports.
      def parse_time(gmt, local)
        [ [ gmt, "UTC" ], [ local, nil ] ].each do |value, zone|
          next if value.blank? || value.start_with?("0000-00-00")

          parsed = zone ? Time.find_zone("UTC").parse(value) : Time.zone.parse(value)
          return parsed if parsed
        end
        nil
      end
  end
end
