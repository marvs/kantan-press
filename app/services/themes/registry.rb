module Themes
  # Finds the themes installed on this box.
  #
  # Built-in themes live in the repo at themes/; uploaded ones are extracted to
  # storage/themes/, which Kamal keeps on a persistent volume. Both are plain
  # directories, so discovery is the same scan twice.
  module Registry
    DEFAULT_SLUG = "independent".freeze

    # Concurrent::Map because Puma serves requests on several threads.
    CACHE = Concurrent::Map.new

    module_function

    def builtin_root = Rails.root.join("themes")
    def uploaded_root = Rails.root.join("storage", "themes")

    # Called on every page render and every theme-asset request, and each scan
    # lists two directories and parses a manifest per theme. In production that
    # is cached until a theme is added or removed, which is the only way the
    # set changes there. Outside production it always rescans, so editing a
    # theme in place shows up on the next reload.
    def all
      return scan_all unless cache?

      key = cache_key
      cached = CACHE[:all]
      return cached.last if cached && cached.first == key

      scan_all.tap { |bundles| CACHE[:all] = [ key, bundles ] }
    end

    def scan_all
      bundles = scan(uploaded_root, :uploaded) + scan(builtin_root, :builtin)

      # Later entries win, so a built-in always beats an upload of the same
      # slug: an uploaded zip must not be able to shadow a shipped theme.
      bundles.index_by(&:slug).values.sort_by { |bundle| bundle.name.downcase }
    end

    def cache? = Rails.env.production?

    # A directory's mtime changes when a child is added or removed, so this
    # notices an install or an uninstall without stat-ing every theme.
    def cache_key
      [ builtin_root, uploaded_root ].map { |root| File.exist?(root) ? File.mtime(root).to_i : 0 }
    end

    def find(slug)
      slug = slug.to_s
      return nil unless slug.match?(Bundle::SLUG_FORMAT)

      all.find { |bundle| bundle.slug == slug }
    end

    def default
      find(DEFAULT_SLUG) || all.first
    end

    def builtin_slugs
      all.select(&:builtin?).map(&:slug)
    end

    def builtin?(slug) = builtin_slugs.include?(slug.to_s)

    def scan(root, source)
      root = Pathname.new(root)
      return [] unless root.directory?

      # Dot-directories are skipped: the installer stages an upload in one of
      # these inside the same root so the final move is an atomic rename.
      root.children.select(&:directory?).reject { |dir| dir.basename.to_s.start_with?(".") }.filter_map do |dir|
        bundle = Bundle.new(dir, source: source)
        next bundle if bundle.valid?

        Rails.logger.warn("Skipping invalid theme at #{dir}: #{bundle.errors.join('; ')}")
        nil
      end
    end
  end
end
