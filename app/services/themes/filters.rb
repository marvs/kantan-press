module Themes
  # The filters a theme template can call, on top of Liquid's own.
  #
  # URLs are built through the route helpers rather than string interpolation so
  # a theme cannot hardcode a permalink structure that the app later changes.
  module Filters
    def asset_url(path)
      bundle = @context.registers[:bundle]
      return "" if bundle.nil?

      version = bundle.asset_version(path)
      return "" if version.nil? # the theme does not ship this file

      "#{routes.theme_asset_path(slug: bundle.slug, path: path.to_s)}?v=#{version}"
    end

    def post_url(slug) = routes.post_path(slug.to_s)
    def category_url(slug) = routes.category_path(slug.to_s)
    def tag_url(slug) = routes.tag_path(slug.to_s)
    def feed_url = routes.feed_path

    def archive_url(year, month)
      routes.archive_path(year: year, month: format("%02d", month.to_i))
    end

    def number_with_delimiter(number)
      ActiveSupport::NumberHelper.number_to_delimited(number)
    end

    private
      def routes = Rails.application.routes.url_helpers
  end
end
