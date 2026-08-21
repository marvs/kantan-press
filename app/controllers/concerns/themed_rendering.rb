# Renders the public site through the active theme, with the app's own ERB
# views as the safety net.
#
# A theme is third-party code, so a broken one must not be able to take the
# public site down. In development and test a theme error is raised so it is
# impossible to miss; in production it is logged and the matching ERB view is
# rendered instead, which is exactly what the site did before themes existed.
module ThemedRendering
  extend ActiveSupport::Concern

  private
    def render_themed(template, fallback:, status: :ok, **assigns)
      selection = Theme.selection
      return render(fallback, status: status) if selection.nil?

      html = Themes::Renderer.call(
        bundle: selection.bundle,
        template: template,
        settings: selection.settings,
        assigns: theme_assigns(assigns)
      )

      render html: html.html_safe, layout: false, status: status
    rescue Liquid::Error, Themes::Bundle::MissingTemplate => e
      raise e unless Rails.env.production?

      Rails.logger.error("Theme #{selection&.bundle&.slug} failed to render #{template}: #{e.class}: #{e.message}")
      render fallback, status: status
    end

    def theme_assigns(assigns)
      assigns.transform_keys(&:to_s).merge("site" => Themes::Drops::SiteDrop.new)
    end

    def post_drops(posts)
      posts.map { |post| Themes::Drops::PostDrop.new(post) }
    end

    def pagination_drop(current_page, total_pages, &path_builder)
      Themes::Drops::PaginationDrop.new(
        current_page: current_page, total_pages: total_pages, path_builder: path_builder
      )
    end
end
