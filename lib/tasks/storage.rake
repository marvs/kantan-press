namespace :kantan do
  desc "Check the object store configuration and do a real upload round-trip"
  task storage_check: :environment do
    config = KantanPress::Config

    puts "Configuration"
    puts format("  %-18s %s", "backend", config.storage_backend)
    puts format("  %-18s %s", "media base URL", config.media_base_url.presence || "(not set)")
    puts format("  %-18s %s", "legacy site URL", config.legacy_site_url.presence || "(read from export)")

    if config.storage_backend == :s3
      s3 = config.s3_config
      puts format("  %-18s %s", "endpoint", s3[:endpoint])
      puts format("  %-18s %s", "bucket", s3[:bucket])
      puts format("  %-18s %s", "region", s3[:region])
      puts format("  %-18s %s", "access key", mask(s3[:access_key_id]))
      puts format("  %-18s %s", "secret", mask(s3[:secret_access_key]))
    end

    if config.media_base_url.blank?
      abort "\n  KANTAN_MEDIA_BASE_URL is not set. Importing now would rewrite image URLs to nothing."
    end

    if config.storage_backend == :s3 && config.media_base_url.to_s.include?("r2.cloudflarestorage.com")
      warn "\n  Warning: KANTAN_MEDIA_BASE_URL points at the S3 API endpoint, which is not"
      warn "  publicly readable. Use your bucket's custom domain (e.g. https://cdn.example.com)."
    end

    key = "kantan-press-storage-check/#{SecureRandom.hex(8)}.txt"
    body = "kantan press storage check #{Time.current.iso8601}"

    puts "\nRound-trip"
    store = ObjectStore.current
    print "  uploading #{key} ... "
    store.upload(key: key, io: StringIO.new(body), content_type: "text/plain")
    puts "ok"

    print "  confirming it exists ... "
    exists = store.exist?(key)
    puts exists ? "ok" : "FAILED"

    print "  deleting ... "
    store.delete(key)
    puts "ok"

    puts "\n  Public URL for uploads will look like:"
    puts "    #{File.join(config.media_base_url, 'wp-content/uploads/2026/05/example.png')}"
    puts "\n  Storage is ready." if exists
  rescue KantanPress::Config::Error => e
    abort "\n  #{e.message}"
  rescue StandardError => e
    abort "\n  #{e.class}: #{e.message}"
  end

  def mask(value)
    return "(not set)" if value.blank?

    "#{value[0, 4]}…#{value[-4, 4]} (#{value.length} chars)"
  end
end
