class Current < ActiveSupport::CurrentAttributes
  attribute :session

  # Site settings are read several times per page (title, tagline, page size).
  # Holding them here means one query per request rather than one per lookup,
  # while still picking up a change made in another process on the next request
  # — which a process-level cache would not.
  attribute :site_settings

  # Branding::Favicon.current is asked by both layouts, the theme drop and the
  # manifest, and each ask is a settings read plus a stat. Held for the request
  # only, for the same reason as site_settings above.
  attribute :favicon
  delegate :user, to: :session, allow_nil: true
end
