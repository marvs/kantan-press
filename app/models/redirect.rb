class Redirect < ApplicationRecord
  validates :from_path, presence: true, uniqueness: true
  validates :to_path, presence: true
  validates :status, inclusion: { in: [ 301, 302 ] }

  # Normalised so lookups don't depend on a trailing slash.
  def self.lookup(path)
    find_by(from_path: normalize(path))
  end

  def self.normalize(path)
    "/#{path.to_s.strip.delete_prefix('/').delete_suffix('/')}"
  end

  before_validation { self.from_path = self.class.normalize(from_path) }
end
