class ObjectStore
  # Writes under public/media so Rails (and Thruster in production) can serve
  # the files directly with no controller in the request path. Used for local
  # development and tests; production points at S3Backend instead.
  class DiskBackend
    attr_reader :root

    def initialize(root: Rails.root.join("public", "media"))
      @root = Pathname.new(root)
    end

    def upload(key:, io:, content_type: nil)
      path = path_for(key)
      path.dirname.mkpath

      File.open(path, "wb") do |file|
        IO.copy_stream(io, file)
      end

      key
    end

    def exist?(key) = path_for(key).file?

    def delete(key)
      path = path_for(key)
      path.delete if path.file?
    end

    def url_for(key) = File.join(KantanPress::Config.media_base_url, key)

    def path_for(key)
      cleaned = key.to_s.delete_prefix("/")
      raise ArgumentError, "unsafe object key: #{key.inspect}" if cleaned.include?("..")

      root.join(cleaned)
    end
  end
end
