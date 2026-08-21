module KantanPress
  # Central configuration for the parts of Kantan Press that talk to the outside
  # world. Everything reads from ENV first so a Kamal deploy only needs secrets,
  # with Rails credentials as a fallback for local work.
  module Config
    class Error < StandardError; end

    module_function

    # Host that appears in post content for every image, e.g.
    # "https://cdn.techandfi.com". Always a domain you control, never the raw
    # bucket endpoint, so the CDN can be repointed without rewriting posts.
    def media_base_url
      setting(:media_base_url) || default_media_base_url
    end

    # --- settings the site owner edits ------------------------------------
    #
    # These read the database first and ENV second, the opposite way round to
    # the credentials below. An admin form that silently lost to a deploy-time
    # variable would be worse than not having the form at all.

    # Shown by themes in the header, the browser title and the feed. Themes
    # cannot hardcode it, so it has to come from configuration.
    def site_title
      site_setting(:site_title) || "Kantan Press"
    end

    def site_description
      site_setting(:site_description)
    end

    DEFAULT_POSTS_PER_PAGE = 10
    POSTS_PER_PAGE_RANGE = (1..50).freeze

    def posts_per_page
      value = site_setting(:posts_per_page).to_i

      POSTS_PER_PAGE_RANGE.cover?(value) ? value : DEFAULT_POSTS_PER_PAGE
    end

    def site_setting(name)
      SiteSetting.get(name).presence || setting(name).presence
    end

    # Host the site was exported from, e.g. "https://techandfi.com". The
    # importer rewrites this to media_base_url in every <img src> and srcset.
    def legacy_site_url
      setting(:legacy_site_url)
    end

    def storage_backend
      explicit = setting(:storage_backend)
      return explicit.to_sym if explicit.present?

      s3_configured? ? :s3 : :disk
    end

    def s3_configured?
      %i[endpoint bucket access_key_id secret_access_key].all? { |key| s3_config[key].present? }
    end

    def s3_config
      {
        endpoint: setting(:s3_endpoint),
        bucket: setting(:s3_bucket),
        region: setting(:s3_region) || "auto",
        access_key_id: setting(:s3_access_key_id),
        secret_access_key: setting(:s3_secret_access_key)
      }
    end

    def s3_config!
      raise Error, <<~MESSAGE unless s3_configured?
        S3 storage is selected but not configured. Set KANTAN_S3_ENDPOINT,
        KANTAN_S3_BUCKET, KANTAN_S3_ACCESS_KEY_ID and KANTAN_S3_SECRET_ACCESS_KEY
        (or the matching kantan_press credentials).
      MESSAGE

      s3_config
    end

    def setting(name)
      ENV["KANTAN_#{name.to_s.upcase}"].presence ||
        Rails.application.credentials.dig(:kantan_press, name).presence
    end

    def default_media_base_url
      # Disk-backed media is served straight out of public/, so a root-relative
      # base is correct and keeps development working with no configuration.
      storage_backend == :disk ? "/media" : nil
    end
  end
end
