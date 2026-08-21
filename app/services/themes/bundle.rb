module Themes
  # One theme, read straight off disk.
  #
  # A theme is a directory, whether it shipped with the app or arrived as a zip,
  # so both kinds are read through this one class. It knows nothing about the
  # database: which theme is active and what its settings are lives in the
  # +themes+ table, never here.
  class Bundle
    API_VERSION = 1
    SLUG_FORMAT = /\A[a-z0-9][a-z0-9\-]*\z/
    TEMPLATE_NAME_FORMAT = /\A[a-z0-9_\-]+\z/

    # A theme must ship these three. +page+ falls back to +post+ and +archive+
    # to +index+, so a minimal theme stays minimal.
    REQUIRED_TEMPLATES = %w[layout index post].freeze
    TEMPLATE_FALLBACKS = { "page" => "post", "archive" => "index" }.freeze

    # Extensions the asset route will serve. Deliberately excludes .liquid,
    # .json and anything executable, so a theme cannot serve its own source.
    ASSET_EXTENSIONS = %w[
      .css .js .map
      .woff2 .woff .ttf .otf .eot
      .png .jpg .jpeg .gif .svg .webp .avif .ico
    ].freeze

    class MissingTemplate < StandardError; end

    attr_reader :root, :source

    def initialize(root, source: :uploaded)
      @root = Pathname.new(root)
      @source = source.to_sym
    end

    def directory_name = root.basename.to_s

    def slug = manifest["slug"].presence || directory_name
    def name = manifest["name"].presence || directory_name.titleize
    def version = manifest["version"].to_s
    def author = manifest["author"].presence
    def author_url = manifest["author_url"].presence
    def description = manifest["description"].presence
    def builtin? = source == :builtin

    def manifest
      @manifest ||= parse_manifest
    end

    def settings_schema
      @settings_schema ||= Array(manifest["settings"]).map { |attrs| Setting.new(attrs) }
    end

    def default_settings
      settings_schema.to_h { |setting| [ setting.key, setting.default ] }
    end

    def valid? = errors.empty?

    def errors
      @errors ||= validate
    end

    def template?(name)
      path = template_path(name)
      path.present? && path.file?
    end

    def template(name)
      path = template_path(name)
      raise MissingTemplate, "#{directory_name} has no #{name}.liquid" unless path&.file?

      path.read
    end

    # Applies the fallbacks above, so the renderer can ask for "page" without
    # knowing whether this theme bothered to ship one.
    def resolve_template(name)
      return name.to_s if template?(name)

      fallback = TEMPLATE_FALLBACKS[name.to_s]
      return fallback if fallback && template?(fallback)

      raise MissingTemplate, "#{directory_name} has no #{name}.liquid"
    end

    def screenshot
      %w[screenshot.svg screenshot.png screenshot.jpg screenshot.webp]
        .map { |file| root.join(file) }
        .find(&:file?)
    end

    # The single chokepoint for path safety. Everything that reads a file out of
    # a theme goes through here, so traversal, symlink escapes and unexpected
    # extensions are all refused in one place rather than at each call site.
    def asset_path(relative)
      relative = relative.to_s
      return nil if relative.blank? || relative.include?("\0")

      base = assets_root.realpath
      candidate = base.join(relative).realpath
      return nil unless candidate.to_s.start_with?("#{base}#{File::SEPARATOR}")
      return nil unless candidate.file?
      return nil unless ASSET_EXTENSIONS.include?(candidate.extname.downcase)

      candidate
    rescue SystemCallError, ArgumentError
      # Missing file, a path that cannot be resolved, or a null byte.
      nil
    end

    # Cache-busting token for an asset URL. mtime is enough: theme files only
    # change when a theme is installed or edited in place.
    def asset_version(relative)
      asset_path(relative)&.mtime&.to_i&.to_s(36)
    end

    def ==(other) = other.is_a?(Bundle) && other.root == root
    alias eql? ==
    def hash = root.hash

    private
      def assets_root = root.join("assets")
      def manifest_path = root.join("theme.json")

      def template_path(name)
        name = name.to_s
        return nil unless name.match?(TEMPLATE_NAME_FORMAT)

        root.join("templates", "#{name}.liquid")
      end

      def parse_manifest
        JSON.parse(manifest_path.read)
      rescue JSON::ParserError => e
        @manifest_error = e.message
        {}
      rescue SystemCallError
        @manifest_error = nil
        {}
      end

      def validate
        return [ "theme.json is missing" ] unless manifest_path.file?

        manifest # populates @manifest_error when the JSON is broken
        return [ "theme.json is not valid JSON: #{@manifest_error}" ] if @manifest_error

        problems = []
        problems << "kantan_theme_api must be #{API_VERSION}" unless manifest["kantan_theme_api"] == API_VERSION
        problems << "name is required" if manifest["name"].blank?
        problems << "version is required" if manifest["version"].blank?
        problems.concat(slug_errors)

        REQUIRED_TEMPLATES.each do |required|
          problems << "templates/#{required}.liquid is missing" unless template?(required)
        end

        problems.concat(settings_schema.flat_map(&:errors))
        problems
      end

      def slug_errors
        declared = manifest["slug"].to_s

        return [ "slug #{declared.inspect} may only contain lowercase letters, numbers and dashes" ] unless declared.match?(SLUG_FORMAT)
        return [ "slug #{declared.inspect} does not match the directory name #{directory_name.inspect}" ] unless declared == directory_name

        []
      end
  end
end
