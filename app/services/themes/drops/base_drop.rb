module Themes
  module Drops
    # Base class for everything a theme can reach with {{ }}.
    #
    # Two rules hold across every drop, and both exist because Liquid does not
    # escape output the way ERB does:
    #
    #   1. Text fields come back already HTML-escaped, so a theme author who
    #      forgets `| escape` cannot turn an imported WordPress title into
    #      stored XSS.
    #   2. Raw HTML is only ever reachable through a field whose name ends in
    #      _html, so emitting it is always a deliberate act.
    #
    # Every public method here is callable from a template, so helpers are
    # private without exception.
    class BaseDrop < Liquid::Drop
      private
        def h(value) = CGI.escapeHTML(value.to_s)

        def routes = Rails.application.routes.url_helpers

        # ActionView helpers, reached without `include` — including them would
        # make strip_tags and sanitize callable from a theme template.
        def view = ActionController::Base.helpers
    end
  end
end
