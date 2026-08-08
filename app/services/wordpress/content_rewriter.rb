module Wordpress
  # Post content arrives full of absolute URLs pointing at the old site:
  #
  #   <img src="https://techandfi.com/wp-content/uploads/2024/01/foo.jpg"
  #        srcset="...foo-300x200.jpg 300w, ...foo-1024x683.jpg 1024w">
  #
  # Because uploads keep their original key in the bucket, making those work
  # again is a host substitution and nothing more — no markup parsing, and every
  # srcset variant is fixed by the same pass.
  class ContentRewriter
    # Matches an uploads URL up to the first character that can't appear in one.
    # The srcset separators (space and comma) terminate a match, so each
    # candidate in a srcset list is found individually.
    UPLOAD_URL = %r{
      https?://[^/\s"'<>]+ /wp-content/uploads/ [^\s"'<>\\)\]]+
    }xi

    attr_reader :legacy_hosts, :media_base_url

    def initialize(legacy_site_url:, media_base_url:)
      @legacy_hosts = Array(legacy_site_url).filter_map { |url| host_of(url) }.uniq
      @media_base_url = media_base_url.to_s.chomp("/")
    end

    # Every uploads URL in the content, de-duplicated, restricted to the hosts
    # this rewriter knows about. Trailing punctuation from prose is trimmed.
    def upload_urls(content)
      content.to_s.scan(UPLOAD_URL)
             .map { |url| url.sub(/[.,;:]+\z/, "") }
             .select { |url| legacy_host?(url) }
             .uniq
    end

    # Swaps the host on uploads URLs only. Other links to the old site are left
    # alone — those are article cross-references and keep working via the
    # public site's own routes.
    def rewrite(content)
      return content if content.blank? || media_base_url.blank?

      content.gsub(UPLOAD_URL) do |url|
        trailing = url[/[.,;:]+\z/].to_s
        bare = trailing.empty? ? url : url[0...-trailing.length]

        legacy_host?(bare) ? "#{media_base_url}#{path_of(bare)}#{trailing}" : url
      end
    end

    private
      def legacy_host?(url)
        return false if legacy_hosts.empty?

        legacy_hosts.include?(host_of(url))
      end

      def host_of(url)
        URI.parse(url.to_s).host&.downcase&.delete_prefix("www.")
      rescue URI::InvalidURIError
        nil
      end

      def path_of(url)
        URI.parse(url).path
      rescue URI::InvalidURIError
        url
      end
  end
end
