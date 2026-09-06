module ApplicationHelper
  # The <link rel="icon"> for the layouts the app renders itself, falling back
  # to the mark that ships in public/ when nobody has uploaded one.
  #
  # Deliberately not called favicon_link_tag: Rails already defines a helper by
  # that name, and shadowing it would make every call site ambiguous about which
  # one it meant.
  def site_favicon_tag
    favicon = Branding::Favicon.current

    tag.link(rel: "icon",
             href: favicon&.url || "/icon.png",
             type: favicon&.content_type || "image/png")
  end
end
