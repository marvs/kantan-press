# Serves a theme's CSS, JavaScript, fonts and images.
#
# Theme files live outside public/, so Propshaft never sees them and they cannot
# be fingerprinted at precompile time. Cache busting comes from the ?v= that
# Themes::Filters#asset_url appends, which is why the response can be cached
# forever.
class ThemeAssetsController < ApplicationController
  allow_unauthenticated_access

  # Rails refuses to serve a JavaScript response to a non-XHR request, to stop a
  # dynamic JS response carrying user data from being read cross-origin with a
  # <script src>. A theme's theme.js is a static public file with nothing
  # private in it, exactly like anything under public/, so that guard does not
  # apply and would otherwise 422 every theme script.
  skip_forgery_protection

  # Rack's table is missing a few of these, and guessing by sniffing the file
  # would hand a theme control over its own content type.
  CONTENT_TYPES = {
    ".css" => "text/css",
    ".js" => "text/javascript",
    ".map" => "application/json",
    ".woff2" => "font/woff2",
    ".woff" => "font/woff",
    ".ttf" => "font/ttf",
    ".otf" => "font/otf",
    ".svg" => "image/svg+xml",
    ".webp" => "image/webp",
    ".avif" => "image/avif",
    ".ico" => "image/x-icon"
  }.freeze

  # An SVG opened as a document runs its own <script> on this origin, and a
  # theme is untrusted code. Every response here is a static file that needs to
  # load nothing and run nothing, so it is served under a policy that says
  # exactly that.
  ASSET_POLICY = "default-src 'none'; style-src 'unsafe-inline'; sandbox".freeze

  def show
    path = asset_path
    return head :not_found if path.nil?

    # Safe to cache forever because Themes::Filters#asset_url puts an mtime in
    # the query string.
    serve(path, cache: "public, max-age=31536000, immutable")
  end

  # The screenshot has no cache-busting parameter, so it gets a short life
  # instead — otherwise replacing a theme would leave the old picture on the
  # themes page.
  def screenshot
    path = Themes::Registry.find(params[:slug])&.screenshot
    return head :not_found if path.nil?

    serve(path, cache: "public, max-age=60")
  end

  private
    def serve(path, cache:)
      response.headers["Cache-Control"] = cache
      response.headers["Content-Security-Policy"] = ASSET_POLICY
      response.headers["X-Content-Type-Options"] = "nosniff"

      send_file path, type: content_type_for(path), disposition: "inline"
    end

    # Themes::Bundle#asset_path is the one place path safety is decided:
    # traversal, symlinks pointing out of the theme, and non-asset extensions
    # are all refused there rather than being re-checked here.
    def asset_path
      Themes::Registry.find(params[:slug])&.asset_path(params[:path])
    end

    def content_type_for(path)
      extension = path.extname.downcase

      CONTENT_TYPES[extension] || Rack::Mime.mime_type(extension, "application/octet-stream")
    end
end
