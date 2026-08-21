module Themes
  # Renders one theme template inside that theme's layout.
  #
  # Liquid is the sandbox: a template can only reach what it is handed as a
  # drop, so a theme downloaded from a stranger cannot read the database, ENV or
  # the S3 credentials. This class is where that boundary is drawn.
  class Renderer
    # A theme should not be able to take the box down by accident or on purpose.
    # Liquid enforces these per render, and each render gets its own budget.
    RESOURCE_LIMITS = {
      render_length_limit: 4_000_000,
      render_score_limit: 400_000,
      assign_score_limit: 200_000
    }.freeze

    LAYOUT = "layout".freeze

    def self.call(bundle:, template:, assigns: {}, settings: {})
      new(bundle: bundle, settings: settings).render(template, assigns)
    end

    def initialize(bundle:, settings: {})
      @bundle = bundle
      @settings = settings
    end

    def render(template_name, assigns = {})
      assigns = assigns.merge("settings" => @settings, "theme" => theme_info)

      inner = render_template(@bundle.resolve_template(template_name), assigns)
      render_template(LAYOUT, assigns.merge("content_for_layout" => inner))
    end

    private
      def render_template(name, assigns)
        # A fresh context per render, so each one gets its own resource budget:
        # a cached template would otherwise carry the previous render's tally
        # and start failing for no reason.
        context = Liquid::Context.build(
          environments: [ assigns ],
          registers: { bundle: @bundle },
          rethrow_errors: true,
          resource_limits: Liquid::ResourceLimits.new(RESOURCE_LIMITS)
        )
        context.add_filters([ Filters ])

        parse(name).render!(context)
      end

      # Templates are parsed once and kept until the file changes, which only
      # happens when a theme is installed or edited in place.
      def parse(name)
        path = @bundle.root.join("templates", "#{name}.liquid")
        key = [ path.to_s, path.mtime.to_i, path.size ]

        cache = self.class.template_cache
        cached = cache[key]
        return cached if cached

        # Puma serves requests on several threads, so the cache is a
        # Concurrent::Map rather than a Hash: a plain Hash rehashing while
        # another thread reads it is not safe.
        cache.clear if cache.size > 200
        cache[key] = Liquid::Template.parse(@bundle.template(name), error_mode: :strict)
      end

      def theme_info
        { "name" => @bundle.name, "version" => @bundle.version, "slug" => @bundle.slug }
      end

      def self.template_cache
        @template_cache ||= Concurrent::Map.new
      end
  end
end
