class MediaItem < ApplicationRecord
  has_many :posts, foreign_key: :featured_media_item_id, dependent: :nullify, inverse_of: :featured_media_item

  # Rows are created up front by the WordPress import and filled in by
  # Wordpress::FetchMediaJob, so each one carries its own fetch state.
  enum :status, { pending: "pending", stored: "stored", failed: "failed" }, validate: true

  validates :key, presence: true, uniqueness: true
  validates :filename, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :awaiting_fetch, -> { where(status: %w[pending failed]) }

  # Public URL as it appears in post content. Built from the CDN host rather
  # than the bucket endpoint so the provider can change without another pass
  # over every post body.
  def url
    File.join(KantanPress::Config.media_base_url, key)
  end

  def image? = content_type.to_s.start_with?("image/")

  def dimensions = [ width, height ].compact.join("x").presence
end
