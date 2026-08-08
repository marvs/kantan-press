class Tag < ApplicationRecord
  include Sluggable

  has_many :post_tags, dependent: :destroy
  has_many :posts, through: :post_tags

  validates :name, presence: true

  scope :alphabetical, -> { order(:name) }
end
