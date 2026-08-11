require "cgi"

module Wordpress
  # WordPress stores an oEmbed block as the bare URL and resolves it to an
  # iframe at render time. A WXR export therefore contains only the URL, so
  # without this the video shows up as a line of plain text.
  #
  # The substitution is surgical rather than a Nokogiri round-trip: only the
  # matched wrapper is rewritten, so the rest of the post's block markup is
  # passed through byte-for-byte.
  class EmbedRenderer
    # <div class="wp-block-embed__wrapper">\n https://... \n</div>
    WRAPPER = %r{
      (<div\s+class="wp-block-embed__wrapper">)
      \s*
      (https?://[^\s<"]+)
      \s*
      (</div>)
    }xm

    YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be www.youtu.be].freeze

    # Privacy-preserving host: identical playback, but no cookie is set until
    # the viewer actually hits play.
    EMBED_HOST = "https://www.youtube-nocookie.com/embed".freeze

    def self.call(html) = new(html).call

    def initialize(html)
      @html = html.to_s
    end

    def call
      return @html unless @html.include?("wp-block-embed__wrapper")

      @html.gsub(WRAPPER) do
        opening, url, closing = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
        iframe = youtube_iframe(CGI.unescapeHTML(url))

        iframe ? "#{opening}#{iframe}#{closing}" : "#{opening}#{url}#{closing}"
      end
    end

    private
      def youtube_iframe(url)
        uri = parse(url)
        return nil unless uri && YOUTUBE_HOSTS.include?(uri.host.to_s.downcase)

        id = video_id(uri)
        return nil if id.blank?

        src = "#{EMBED_HOST}/#{id}"
        start = start_seconds(uri)
        src += "?start=#{start}" if start

        <<~HTML.strip
          <iframe src="#{CGI.escapeHTML(src)}" title="YouTube video player" loading="lazy" frameborder="0" referrerpolicy="strict-origin-when-cross-origin" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
        HTML
      end

      def parse(url)
        URI.parse(url)
      rescue URI::InvalidURIError
        nil
      end

      # youtu.be/ID and youtube.com/watch?v=ID are both common in exports;
      # /embed/ID turns up when someone pasted an embed URL directly.
      def video_id(uri)
        host = uri.host.to_s.downcase
        id =
          if host.end_with?("youtu.be")
            uri.path.to_s.delete_prefix("/")
          elsif uri.path.to_s.start_with?("/embed/")
            uri.path.to_s.delete_prefix("/embed/")
          else
            query_param(uri, "v")
          end

        id.to_s[/\A[A-Za-z0-9_-]{6,}\z/]
      end

      # WordPress keeps the timestamp in the URL: "?t=46", "&t=13s", "1h2m3s".
      def start_seconds(uri)
        raw = query_param(uri, "t") || query_param(uri, "start")
        return nil if raw.blank?

        return raw.to_i if raw.match?(/\A\d+\z/)

        match = raw.match(/\A(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?\z/)
        return nil unless match

        seconds = match[1].to_i * 3600 + match[2].to_i * 60 + match[3].to_i
        seconds.positive? ? seconds : nil
      end

      # URI.decode_www_form rather than CGI.parse: the cgi library lost parse in
      # Ruby 4.0 and only the escape helpers remain.
      def query_param(uri, key)
        return nil if uri.query.blank?

        URI.decode_www_form(uri.query).find { |name, _| name == key }&.last.presence
      rescue ArgumentError
        nil
      end
  end
end
