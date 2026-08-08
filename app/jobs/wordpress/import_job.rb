module Wordpress
  # Runs a WXR import in the background so the admin upload returns immediately.
  # Parsing and record creation take seconds; the images they register are
  # downloaded separately by FetchMediaJob.
  class ImportJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(import_id)
      import = Import.find(import_id)
      return unless import.pending?

      import.update!(status: :running, started_at: Time.current)

      result = Importer.new(
        path: import.source_path,
        legacy_site_url: KantanPress::Config.legacy_site_url,
        author: User.first
      ).call

      import.update!(
        status: :completed,
        stats: result[:stats],
        error_log: result[:errors].join("\n").presence,
        finished_at: Time.current
      )
    rescue StandardError => e
      import&.update(
        status: :failed,
        error_log: "#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}",
        finished_at: Time.current
      )
      raise
    end
  end
end
