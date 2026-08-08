module Wordpress
  # One job per image. The WordPress import creates every MediaItem up front
  # with status "pending" and enqueues one of these for each, so a 200-image
  # migration doesn't block the import and individual failures are retryable
  # without re-running the whole thing.
  class FetchMediaJob < ApplicationJob
    queue_as :media

    retry_on MediaFetcher::FetchError, wait: :polynomially_longer, attempts: 5
    retry_on ObjectStore::UploadError, wait: :polynomially_longer, attempts: 5

    discard_on ActiveRecord::RecordNotFound

    def perform(media_item_id)
      media_item = MediaItem.find(media_item_id)
      return if media_item.stored?

      media_item.increment!(:fetch_attempts)
      MediaFetcher.new.fetch!(media_item)
    rescue MediaFetcher::FetchError, ObjectStore::UploadError => e
      # Record the reason before re-raising so a failure is visible in the admin
      # while Active Job is still backing off, and readable after it gives up.
      media_item&.update_columns(status: "failed", fetch_error: e.message)
      raise
    end
  end
end
