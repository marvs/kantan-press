module Branding
  # The one place that knows a site can have its own favicon. Both ERB layouts,
  # the theme drop, the PWA manifest and the admin screen ask here; nothing else
  # stats the filesystem or reads the setting.
  class Favicon
    SETTING = "favicon_extension".freeze

    # PNG and SVG only, and the extension is also the file's name on disk — so
    # this doubles as the allow-list for what may ever be written there.
    CONTENT_TYPES = { ".png" => "image/png", ".svg" => "image/svg+xml" }.freeze

    class << self
      # Beside storage/themes, on the volume Kamal mounts at /rails/storage.
      # Anything written anywhere else at runtime is gone on the next deploy.
      def root = Rails.root.join("storage", "branding")

      def path_for(extension) = root.join("favicon#{extension}")

      # Memoised per request, not per process: a layout, the manifest and the
      # admin can each ask within one render, but another Puma worker may have
      # replaced the file since — which a class-level cache would never see.
      # The array is the memo box, so a nil result is remembered too.
      def current = (Current.favicon ||= [ lookup ]).first

      # Clears every favicon this app could have written, rather than only the
      # one the setting names. Removing means "there is no custom favicon", so
      # an orphan left by an earlier failure should go too — and it keeps a
      # stored value out of a path handed to rm_f.
      def remove
        CONTENT_TYPES.each_key { |extension| FileUtils.rm_f(path_for(extension)) }

        SiteSetting.set(SETTING, "")
        Current.favicon = nil
      end

      private
        # A stored setting is not proof the file is there: a restored backup or
        # an unmounted volume leaves the row behind. Returning nil rather than
        # a URL keeps a broken <link> off every page of the site.
        def lookup
          extension = SiteSetting.get(SETTING)
          return nil unless CONTENT_TYPES.key?(extension)

          path = path_for(extension)
          path.file? ? new(path, extension) : nil
        end
    end

    attr_reader :path, :extension

    def initialize(path, extension)
      @path = path
      @extension = extension
    end

    def content_type = CONTENT_TYPES.fetch(@extension)

    # The path never changes, so the file's mtime is the only thing that can
    # tell a browser the icon is a different one.
    def version = path.mtime.to_i

    def url = "#{routes.favicon_path}?v=#{version}"

    private
      def routes = Rails.application.routes.url_helpers
  end
end
