module Themes
  # Installs a theme from an uploaded .zip.
  #
  # This is the only path in the app where a browser upload causes files to be
  # written and then read back as code-ish content, so it is deliberately
  # suspicious of everything in the archive. Nothing is written to the themes
  # directory until the whole archive has been checked and the extracted result
  # validates as a theme, and the last step is a rename inside the same
  # filesystem so a half-installed theme is never visible.
  class Installer
    MAX_UPLOAD_BYTES = 10.megabytes
    MAX_UNCOMPRESSED_BYTES = 50.megabytes
    MAX_ENTRIES = 2_000

    ALLOWED_EXTENSIONS = (Bundle::ASSET_EXTENSIONS + %w[.json .liquid .md .txt]).freeze

    # Files a theme may ship with no extension at all.
    ALLOWED_BARE_NAMES = %w[LICENSE LICENCE COPYING NOTICE README CHANGELOG].freeze

    # Archive noise that macOS adds to every zip. Skipped rather than refused,
    # because refusing would reject most themes zipped on a Mac.
    IGNORED = ->(name) {
      name.start_with?("__MACOSX/") ||
        File.basename(name) == ".DS_Store" ||
        File.basename(name).start_with?("._")
    }

    Result = Struct.new(:bundle, :errors, keyword_init: true) do
      def success? = errors.empty?
    end

    def self.call(file, overwrite: false) = new(file, overwrite: overwrite).call

    def initialize(file, overwrite: false)
      @file = file
      @overwrite = overwrite
      @errors = []
    end

    def call
      path = source_path
      return failure("the upload is missing") if path.blank?
      return failure("the theme is larger than #{MAX_UPLOAD_BYTES / 1.megabyte}MB") if File.size(path) > MAX_UPLOAD_BYTES

      stage { |staging| extract_and_install(path, staging) }
    rescue Zip::Error => e
      failure("that file is not a readable zip archive (#{e.message})")
    rescue SystemCallError => e
      # A full disk or a permissions problem, rather than a bad archive. Report
      # it instead of raising: the theme directory is already back the way it
      # was, so there is nothing for a 500 page to add.
      Rails.logger.error("Theme install failed: #{e.class}: #{e.message}")
      failure("the theme could not be written to disk (#{e.message})")
    end

    private
      attr_reader :errors

      def source_path
        return @file.path if @file.respond_to?(:path)

        @file.to_s.presence
      end

      # Staging happens inside the themes root so the final move is a rename on
      # the same filesystem, and is removed whatever happens.
      def stage
        staging = nil
        root = Themes::Registry.uploaded_root
        FileUtils.mkdir_p(root)
        staging = root.join(".staging-#{SecureRandom.hex(8)}")
        FileUtils.mkdir_p(staging)

        yield staging
      ensure
        FileUtils.remove_entry(staging, true) if staging
      end

      def extract_and_install(zip_path, staging)
        extracted = staging.join("extracted")
        FileUtils.mkdir_p(extracted)

        Zip::File.open(zip_path) do |zip|
          prefix = wrapper_prefix(zip)
          problem = entry_problem(zip, prefix)
          return failure(problem) if problem

          zip.each { |entry| write_entry(entry, extracted, prefix) }
        end

        finalise(extracted, staging)
      end

      # A zip made by GitHub wraps everything in one directory. Strip it, but
      # only when it really is the single top-level directory holding the
      # manifest, so a theme that legitimately has a top-level folder is safe.
      def wrapper_prefix(zip)
        names = zip.map(&:name).reject { |name| IGNORED.call(name) }
        return "" if names.any? { |name| name == "theme.json" }

        tops = names.filter_map { |name| name.split("/").first }.uniq
        return "" unless tops.one?

        candidate = "#{tops.first}/"
        names.include?("#{candidate}theme.json") ? candidate : ""
      end

      # Returns the first thing wrong with the archive, or nil if it is safe to
      # unpack. Every check runs before a single byte is written.
      def entry_problem(zip, prefix)
        entries = zip.reject { |entry| IGNORED.call(entry.name) }

        return "the archive has more than #{MAX_ENTRIES} files" if entries.size > MAX_ENTRIES

        # Uncompressed size, not compressed: a zip bomb is small on disk and
        # enormous once unpacked, so the compressed size proves nothing.
        if entries.sum(&:size) > MAX_UNCOMPRESSED_BYTES
          return "the archive unpacks to more than #{MAX_UNCOMPRESSED_BYTES / 1.megabyte}MB, which is too large"
        end

        entries.each do |entry|
          name = relative_name(entry.name, prefix)

          return "#{entry.name} is a symlink, which a theme may not contain" if entry.ftype == :symlink
          return "#{entry.name} would write outside the theme directory" unless safe_name?(name)
          next if entry.directory?
          return "#{entry.name} is not a file a theme may contain" unless allowed_file?(name)
        end

        nil
      end

      def relative_name(name, prefix)
        prefix.present? && name.start_with?(prefix) ? name.delete_prefix(prefix) : name
      end

      def safe_name?(name)
        return false if name.blank? || name.start_with?("/") || name.include?("\0")
        return false if name.split("/").include?("..")

        # Windows-style absolute paths and drive letters.
        !name.match?(/\A[a-zA-Z]:/) && !name.include?("\\")
      end

      def allowed_file?(name)
        base = File.basename(name)
        extension = File.extname(base).downcase

        return ALLOWED_BARE_NAMES.include?(base.upcase) if extension.blank?

        ALLOWED_EXTENSIONS.include?(extension)
      end

      def write_entry(entry, extracted, prefix)
        return if IGNORED.call(entry.name)

        name = relative_name(entry.name, prefix)
        return if name.blank?

        target = extracted.join(name)

        if entry.directory?
          FileUtils.mkdir_p(target)
        else
          FileUtils.mkdir_p(target.dirname)
          entry.extract(target.to_s) { true }
        end
      end

      # The extracted directory has to be named after the manifest's slug, since
      # that is how Themes::Bundle ties a theme to its directory.
      def finalise(extracted, staging)
        manifest_path = extracted.join("theme.json")
        return failure("the archive has no theme.json at its root") unless manifest_path.file?

        slug = JSON.parse(manifest_path.read)["slug"].to_s
        return failure("the theme's slug is not a valid directory name") unless slug.match?(Bundle::SLUG_FORMAT)
        return failure("#{slug} ships with the app and cannot be replaced by an upload") if Registry.builtin?(slug)

        named = staging.join(slug)
        FileUtils.mv(extracted, named)

        bundle = Bundle.new(named, source: :uploaded)
        return failure(*bundle.errors) unless bundle.valid?

        move_into_place(named, slug)
      rescue JSON::ParserError => e
        failure("theme.json is not valid JSON: #{e.message}")
      end

      def move_into_place(named, slug)
        target = Themes::Registry.uploaded_root.join(slug)
        previous = nil

        if target.exist?
          return failure("#{slug} is already installed; tick replace to overwrite it") unless @overwrite

          # Move the old one aside rather than deleting it, so the theme can be
          # put back if the rename below fails. Whatever is left in the staging
          # directory is removed once this returns.
          previous = named.dirname.join("previous")
          FileUtils.mv(target, previous)
        end

        begin
          FileUtils.mv(named, target)
        rescue SystemCallError
          FileUtils.mv(previous, target) if previous&.exist?
          raise
        end

        Result.new(bundle: Bundle.new(target, source: :uploaded), errors: [])
      end

      def failure(*messages)
        Result.new(bundle: nil, errors: errors + messages.flatten)
      end
  end
end
