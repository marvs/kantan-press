# Handles an image uploaded from the block editor, as opposed to one pulled in
# by the WordPress importer.
#
# New uploads follow the same "wp-content/uploads/YYYY/MM/name.ext" convention
# as imported ones so the whole bucket has a single key scheme, and so an
# imported post and a new one produce indistinguishable URLs.
class MediaUploader
  class Error < StandardError; end

  MAX_BYTES = 25.megabytes
  PERMITTED_TYPES = %w[image/jpeg image/png image/gif image/webp image/avif image/svg+xml].freeze

  def initialize(store: ObjectStore.current, clock: Time)
    @store = store
    @clock = clock
  end

  def call(upload)
    raise Error, "No file was received." if upload.blank?

    content_type = normalize_type(upload)
    raise Error, "#{content_type} is not an allowed image type." unless PERMITTED_TYPES.include?(content_type)

    body = upload.read
    raise Error, "File is empty." if body.blank?
    raise Error, "File is larger than #{MAX_BYTES / 1.megabyte}MB." if body.bytesize > MAX_BYTES

    key = unique_key_for(upload.original_filename)
    @store.upload(key: key, io: StringIO.new(body), content_type: content_type)

    MediaItem.create!(
      key: key,
      filename: File.basename(key),
      content_type: content_type,
      byte_size: body.bytesize,
      title: File.basename(upload.original_filename.to_s, ".*"),
      status: :stored,
      uploaded_at: @clock.current
    )
  end

  private
    def normalize_type(upload)
      declared = upload.content_type.to_s.split(";").first&.strip
      return declared if declared.present? && declared != "application/octet-stream"

      Rack::Mime.mime_type(File.extname(upload.original_filename.to_s), "application/octet-stream")
    end

    # Mirrors WordPress's uploads layout, and appends a short suffix rather than
    # overwriting when a name is already taken.
    def unique_key_for(original_filename)
      now = @clock.current
      extension = File.extname(original_filename.to_s)
      base = File.basename(original_filename.to_s, ".*").parameterize.presence || "upload"
      prefix = format("wp-content/uploads/%04d/%02d", now.year, now.month)

      candidate = "#{prefix}/#{base}#{extension.downcase}"
      return candidate unless MediaItem.exists?(key: candidate)

      "#{prefix}/#{base}-#{SecureRandom.hex(4)}#{extension.downcase}"
    end
end
