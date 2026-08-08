require "net/http"
require "uri"

module Wordpress
  # Downloads one WordPress upload over HTTP and pushes it to the object store,
  # preserving its original "wp-content/uploads/YYYY/MM/name.ext" key.
  #
  # Keeping the key identical is what lets the importer fix every <img src> and
  # every srcset entry in a post with a single host substitution, instead of
  # parsing markup and rewriting attributes.
  class MediaFetcher
    class FetchError < StandardError; end

    MAX_REDIRECTS = 5
    TIMEOUT = 30
    USER_AGENT = "KantanPress/1.0 (WordPress importer)".freeze

    attr_reader :store

    def initialize(store: ObjectStore.current)
      @store = store
    end

    # Downloads media_item.source_url and uploads it under media_item.key.
    # Returns the updated record; raises FetchError so the caller (the job) can
    # decide whether to retry.
    def fetch!(media_item)
      url = media_item.source_url.presence or
        raise FetchError, "media item #{media_item.id} has no source_url"

      body, content_type = http_get(url)

      store.upload(key: media_item.key, io: StringIO.new(body), content_type: content_type)

      media_item.update!(
        status: :stored,
        content_type: content_type,
        byte_size: body.bytesize,
        fetch_error: nil,
        uploaded_at: Time.current
      )

      media_item
    end

    # "https://techandfi.com/wp-content/uploads/2024/01/foo.jpg"
    #   => "wp-content/uploads/2024/01/foo.jpg"
    #
    # Percent escapes are decoded so the stored key is the real filename, while
    # the URLs left in post content keep their original encoding and still
    # resolve through the CDN.
    def self.key_for(url)
      path = URI.parse(url.to_s).path.to_s
      return nil if path.blank?

      URI::DEFAULT_PARSER.unescape(path).delete_prefix("/")
    rescue URI::InvalidURIError
      nil
    end

    private
      def http_get(url, redirects_left: MAX_REDIRECTS)
        uri = URI.parse(url)
        raise FetchError, "unsupported scheme for #{url.inspect}" unless uri.is_a?(URI::HTTP)

        response = Net::HTTP.start(uri.host, uri.port,
                                   use_ssl: uri.scheme == "https",
                                   open_timeout: TIMEOUT,
                                   read_timeout: TIMEOUT) do |http|
          http.get(uri.request_uri, "User-Agent" => USER_AGENT)
        end

        case response
        when Net::HTTPSuccess
          [ response.body, content_type_from(response, uri) ]
        when Net::HTTPRedirection
          raise FetchError, "too many redirects for #{url}" if redirects_left.zero?

          http_get(URI.join(url, response["location"]).to_s, redirects_left: redirects_left - 1)
        else
          raise FetchError, "#{response.code} #{response.message} for #{url}"
        end
      rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET,
             OpenSSL::SSL::SSLError, URI::InvalidURIError => e
        raise FetchError, "#{e.class}: #{e.message} for #{url}"
      end

      # Prefer what the server says, minus any "; charset=" parameter, and fall
      # back to the file extension when the header is missing or unhelpful.
      def content_type_from(response, uri)
        header = response["content-type"].presence&.split(";")&.first&.strip
        return header if header.present? && header != "application/octet-stream"

        Rack::Mime.mime_type(File.extname(uri.path), header || "application/octet-stream")
      end
  end
end
