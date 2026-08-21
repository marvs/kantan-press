# Which theme the site is wearing, and what its settings are set to.
#
# Theme *content* is never stored here — that lives on disk and is read through
# Themes::Registry. This table holds only the choice, so uninstalling a theme is
# deleting a directory and a row, and a theme upgrade is replacing files.
class Theme < ApplicationRecord
  # The active bundle plus the settings that go with it. Kept together so a
  # caller cannot accidentally render one theme with another's settings.
  Selection = Struct.new(:bundle, :settings, :theme, keyword_init: true)

  # Keys the settings form submitted that the theme never declared. Held in
  # memory only, so the form can report them instead of silently dropping them.
  attr_accessor :submitted_setting_keys

  validates :slug, presence: true, uniqueness: true,
                   format: { with: Themes::Bundle::SLUG_FORMAT,
                             message: "must be lowercase letters, numbers and dashes" }
  validate :theme_must_be_installed
  validate :settings_must_match_schema

  scope :active, -> { where(active: true) }

  # Memoised per slug: validations and the settings merge each ask for it, and
  # resolving means a look through the themes directory.
  def bundle
    return @bundle if defined?(@bundle) && @bundle_slug == slug

    @bundle_slug = slug
    @bundle = Themes::Registry.find(slug)
  end

  # Stored values win over the theme's declared defaults; anything the theme
  # declares but the user never touched falls back to the default.
  def settings_with_defaults
    defaults = bundle&.default_settings || {}
    defaults.merge(settings.to_h.compact)
  end

  def activate!
    transaction do
      self.class.active.where.not(id: id).update_all(active: false, updated_at: Time.current)
      update!(active: true)
    end
  end

  # Takes the raw settings form values, casts each through its declared type,
  # and remembers any key the theme does not declare so validation can reject it.
  def assign_settings(values, submitted_keys: nil)
    schema = (bundle&.settings_schema || []).index_by(&:key)
    values = values.to_h.transform_keys(&:to_s)

    self.submitted_setting_keys = Array(submitted_keys || values.keys).map(&:to_s)
    self.settings = values.filter_map { |key, value|
      [ key, schema[key].cast(value) ] if schema[key]
    }.to_h
  end

  def reset_settings!
    update!(settings: {})
  end

  def self.selection
    record = active.first
    bundle = record&.bundle

    return Selection.new(bundle: bundle, settings: record.settings_with_defaults, theme: record) if bundle

    fallback = Themes::Registry.default
    return nil if fallback.nil?

    # Nothing is marked active, so the default theme is active by implication.
    # Its row may still exist — saving settings creates one without activating
    # anything — and those settings have to apply, or they would silently do
    # nothing until someone pressed Activate.
    saved = find_by(slug: fallback.slug)

    Selection.new(bundle: fallback,
                  settings: saved ? saved.settings_with_defaults : fallback.default_settings,
                  theme: saved)
  end

  private
    def theme_must_be_installed
      return if slug.blank? || bundle.present?

      errors.add(:slug, "is not installed")
    end

    def settings_must_match_schema
      return if (schema = bundle&.settings_schema).nil?

      declared = schema.index_by(&:key)

      Array(submitted_setting_keys).uniq.each do |key|
        errors.add(:settings, "#{key} is not a setting this theme declares") unless declared.key?(key)
      end

      settings.to_h.each do |key, value|
        setting = declared[key]

        if setting.nil?
          errors.add(:settings, "#{key} is not a setting this theme declares")
        elsif !setting.valid_value?(value)
          errors.add(:settings, "#{key} is not a valid #{setting.type}")
        end
      end
    end
end
