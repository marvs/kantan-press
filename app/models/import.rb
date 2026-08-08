class Import < ApplicationRecord
  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, validate: true

  validates :filename, presence: true
  validates :source_path, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def duration
    return unless started_at && finished_at
    finished_at - started_at
  end

  def counts_for(kind)
    stats.fetch(kind.to_s, {})
  end
end
