module Themes
  # One entry in a theme's settings schema, as declared in theme.json.
  #
  # The schema is the allow-list for the settings form: a key the theme did not
  # declare cannot be stored, and a value outside the declared type cannot be
  # saved. That matters because these values are interpolated into CSS by the
  # theme's own layout template.
  class Setting
    TYPES = %w[color select boolean].freeze
    KEY_FORMAT = /\A[a-z][a-z0-9_]*\z/
    COLOR_FORMAT = /\A#\h{6}\z/

    Option = Struct.new(:value, :label)

    attr_reader :key, :type, :label, :description, :options

    def initialize(attributes)
      attributes = attributes.to_h.transform_keys(&:to_s)

      @key = attributes["key"].to_s
      @type = attributes["type"].to_s
      @label = attributes["label"].presence || @key.humanize
      @description = attributes["description"].presence
      @options = build_options(attributes["options"])
      @raw_default = attributes["default"]
    end

    def default
      case type
      when "boolean" then @raw_default.nil? ? false : cast(@raw_default)
      when "select"  then cast(@raw_default).presence || option_values.first
      else cast(@raw_default)
      end
    end

    def option_values = options.map(&:value)

    # Manifest-time validation. A theme with any of these is not installable.
    def errors
      problems = []
      problems << "setting key #{key.inspect} is not a valid identifier" unless key.match?(KEY_FORMAT)
      problems << "setting #{key}: unsupported type #{type.inspect}" unless TYPES.include?(type)
      problems << "setting #{key}: a select needs at least one option" if type == "select" && options.empty?

      if type == "select" && options.any? && !option_values.include?(default)
        problems << "setting #{key}: default #{default.inspect} is not one of its options"
      end

      problems << "setting #{key}: default must be a #rrggbb colour" if type == "color" && !valid_value?(default)
      problems
    end

    # Save-time validation, applied to whatever the settings form submitted.
    def valid_value?(value)
      case type
      when "boolean" then [ true, false ].include?(cast(value))
      when "color"   then cast(value).to_s.match?(COLOR_FORMAT)
      when "select"  then option_values.include?(cast(value))
      else false
      end
    end

    def cast(value)
      case type
      when "boolean" then value.nil? ? nil : ActiveModel::Type::Boolean.new.cast(value)
      when "color"   then value.to_s.strip.downcase.presence
      when "select"  then value.to_s.strip.presence
      else value
      end
    end

    private
      # Options may be given as {"value","label"} pairs or as bare strings.
      def build_options(raw)
        Array(raw).map do |option|
          if option.is_a?(Hash)
            option = option.transform_keys(&:to_s)
            Option.new(option["value"].to_s, option["label"].presence || option["value"].to_s)
          else
            Option.new(option.to_s, option.to_s)
          end
        end
      end
  end
end
