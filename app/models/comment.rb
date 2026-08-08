class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  validates :content, presence: true

  scope :approved, -> { where(approved: true) }
  scope :oldest_first, -> { order(:published_at) }
end
