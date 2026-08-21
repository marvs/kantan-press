# Settings the site owner edits in the admin, as opposed to the deploy-time
# configuration in KantanPress::Config.
#
# Key/value rather than columns so adding a setting is a form field, not a
# migration.
class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  class << self
    def get(key)
      cache[key.to_s].presence
    end

    def set(key, value)
      find_or_initialize_by(key: key.to_s).update!(value: value.to_s)
      reset_cache!
      value
    end

    def to_h = cache.dup

    def reset_cache!
      Current.site_settings = nil
    end

    private
      def cache
        Current.site_settings ||= load_all
      end

      # One query for the lot. Rescued because KantanPress::Config is read at
      # times when the table may not be there — asset precompile on a fresh
      # image, or before the first migration has run.
      def load_all
        pluck(:key, :value).to_h
      rescue ActiveRecord::ActiveRecordError
        {}
      end
  end
end
