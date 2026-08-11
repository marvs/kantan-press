class Post < ApplicationRecord
  include Sluggable

  belongs_to :author, class_name: "User", optional: true
  belongs_to :featured_media_item, class_name: "MediaItem", optional: true

  has_many :post_categories, dependent: :destroy
  has_many :categories, through: :post_categories
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_many :comments, dependent: :destroy

  enum :status, { draft: "draft", published: "published" }, validate: true
  enum :post_type, { post: "post", page: "page" }, prefix: :type, validate: true

  validates :title, presence: true

  scope :live, -> { published.where(published_at: ..Time.current) }
  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
  scope :in_month, ->(year, month) {
    start = Date.new(year.to_i, month.to_i, 1)
    where(published_at: start.beginning_of_day..start.end_of_month.end_of_day)
  }

  before_save :set_published_at

  def approved_comments = comments.where(approved: true).order(:published_at)

  # Comma-separated tag names, so the admin can create tags inline instead of
  # only picking from ones that already exist.
  def add_tag_names(names)
    Array(names.to_s.split(",")).filter_map do |raw|
      name = raw.strip
      next if name.blank?

      tag = Tag.find_by(slug: name.parameterize) || Tag.create!(name: name)
      tags << tag unless tags.include?(tag)
    end
  end

  private
    def set_published_at
      self.published_at ||= Time.current if published?
    end
end
