module Themes
  # Removes an uploaded theme: its directory and its row.
  #
  # Refuses the two cases that would leave the site in a worse state than it
  # started — deleting the theme currently in use, and deleting a theme that
  # ships with the app, which would come back on the next deploy anyway.
  class Uninstaller
    Result = Struct.new(:errors, keyword_init: true) do
      def success? = errors.empty?
    end

    def self.call(slug) = new(slug).call

    def initialize(slug)
      @slug = slug.to_s
    end

    def call
      bundle = Registry.find(@slug)
      return failure("that theme is not installed") if bundle.nil?
      return failure("#{bundle.name} ships with the app and cannot be uninstalled") if bundle.builtin?
      return failure("#{bundle.name} is the active theme; switch to another one first") if active?

      Theme.where(slug: @slug).destroy_all
      FileUtils.remove_entry(bundle.root)

      Result.new(errors: [])
    end

    private
      def active? = Theme.selection&.bundle&.slug == @slug

      def failure(message) = Result.new(errors: [ message ])
  end
end
