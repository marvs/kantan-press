module Wordpress
  # Checks that every image the database calls "stored" is really in the object
  # store.
  #
  # The two can drift apart without anything noticing: an object gets deleted
  # from the bucket, or media is fetched under one backend and the app is later
  # pointed at another. The row keeps saying "stored", retry_media skips it
  # because it is not awaiting_fetch, and the only symptom is a broken image on
  # the public site.
  class MediaVerifier
    Result = Struct.new(:checked, :missing, :reset, keyword_init: true) do
      def ok? = missing.empty?
    end

    def self.call(reset: false) = new(reset: reset).call

    def initialize(reset: false)
      @reset = reset
    end

    def call
      checked = 0
      missing = []

      MediaItem.stored.find_each do |item|
        checked += 1
        missing << item unless ObjectStore.current.exist?(item.key)
      end

      requeue(missing) if @reset

      Result.new(checked: checked, missing: missing, reset: @reset)
    end

    private
      # Back to pending so retry_media picks them up; the attempt counter is
      # cleared too, since a missing object is not a fetch that failed.
      def requeue(items)
        return if items.empty?

        MediaItem.where(id: items.map(&:id))
                 .update_all(status: "pending", uploaded_at: nil, fetch_attempts: 0,
                             fetch_error: nil, updated_at: Time.current)
      end
  end
end
