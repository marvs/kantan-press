# Serves the favicon an admin uploaded.
#
# It lives under storage/ rather than public/, because public/ is baked into the
# image and anything written there at runtime is gone on the next deploy. That
# puts it outside anything Propshaft or the web server will serve, so it needs a
# controller — the same position theme assets are in.
class FaviconsController < ApplicationController
  allow_unauthenticated_access

  # An SVG opened as a document runs its own <script> on this origin. This one
  # came from an admin rather than a stranger, but it is served to every visitor
  # on every page, so it gets the same policy a theme's assets get: load
  # nothing, run nothing, and do not let a browser second-guess the type.
  ASSET_POLICY = "default-src 'none'; sandbox".freeze

  def show
    favicon = Branding::Favicon.current
    return head :not_found if favicon.nil?

    response.headers["Content-Security-Policy"] = ASSET_POLICY
    response.headers["X-Content-Type-Options"] = "nosniff"

    # Safe to cache forever because Branding::Favicon#url puts the file's mtime
    # in the query string, so a replacement is a different URL.
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable"

    send_file favicon.path, type: favicon.content_type, disposition: "inline"
  end
end
