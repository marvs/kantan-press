# Thin façade over an object store. Two backends share one interface so the
# WordPress import can run locally against disk and in production against any
# S3-compatible endpoint (Cloudflare R2, AWS S3, DigitalOcean Spaces) with no
# code change — only configuration.
class ObjectStore
  class UploadError < StandardError; end

  def self.current
    @current ||= build
  end

  # Lets tests and the console swap in a backend without touching ENV.
  def self.current=(backend)
    @current = backend
  end

  def self.reset!
    @current = nil
  end

  def self.build
    case KantanPress::Config.storage_backend
    when :s3   then S3Backend.new(**KantanPress::Config.s3_config!)
    when :disk then DiskBackend.new
    else
      raise KantanPress::Config::Error,
            "Unknown storage backend #{KantanPress::Config.storage_backend.inspect} (expected :s3 or :disk)"
    end
  end

  # Backends implement:
  #   upload(key:, io:, content_type:) -> key
  #   exist?(key)                      -> Boolean
  #   delete(key)                      -> void
  #   url_for(key)                     -> String
end
