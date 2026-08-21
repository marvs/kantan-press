namespace :wordpress do
  desc "Import a WordPress WXR export: rake wordpress:import[path/to/export.xml]"
  task :import, [ :path ] => :environment do |_task, args|
    path = args[:path] or abort "usage: rake wordpress:import[path/to/export.xml]"
    abort "no such file: #{path}" unless File.exist?(path)

    puts "Importing #{path}"
    puts "  storage backend: #{KantanPress::Config.storage_backend}"
    puts "  media base URL:  #{KantanPress::Config.media_base_url.inspect}"

    if KantanPress::Config.media_base_url.blank?
      abort "KANTAN_MEDIA_BASE_URL is not set — image URLs in post content would be rewritten to nothing."
    end

    result = Wordpress::Importer.new(
      path: path,
      legacy_site_url: ENV["KANTAN_LEGACY_SITE_URL"],
      author: User.first
    ).call

    puts
    result[:stats].sort.each do |kind, tallies|
      puts format("  %-12s %s", kind, tallies.sort.map { |k, v| "#{k}=#{v}" }.join("  "))
    end

    if result[:errors].any?
      puts "\n  #{result[:errors].size} error(s):"
      result[:errors].first(20).each { |error| puts "    - #{error}" }
      puts "    ..." if result[:errors].size > 20
    end

    pending = MediaItem.awaiting_fetch.count
    puts "\n  #{pending} image(s) queued for download. Run `bin/jobs` to process them."
  end

  desc "Re-enqueue every image that has not been stored yet"
  task retry_media: :environment do
    items = MediaItem.awaiting_fetch
    items.find_each { |item| Wordpress::FetchMediaJob.perform_later(item.id) }
    puts "Re-enqueued #{items.count} image(s)."
  end

  desc "Check every stored image is really in the object store: rake wordpress:verify_media[reset]"
  task :verify_media, [ :reset ] => :environment do |_task, args|
    reset = args[:reset].to_s == "reset"

    puts "Checking #{MediaItem.stored.count} stored image(s) against #{KantanPress::Config.storage_backend}..."
    result = Wordpress::MediaVerifier.call(reset: reset)

    if result.ok?
      puts "  all #{result.checked} present."
      next
    end

    puts "  #{result.missing.size} of #{result.checked} missing from the store:"
    result.missing.first(20).each do |item|
      featured = Post.where(featured_media_item_id: item.id).pluck(:slug)
      note = featured.any? ? "  (featured on #{featured.join(', ')})" : ""
      puts "    #{item.key}#{note}"
    end
    puts "    ..." if result.missing.size > 20

    if reset
      puts "\n  Reset to pending. Run `bin/rails wordpress:retry_media` then `bin/jobs` to re-fetch."
    else
      puts "\n  Re-run as `rake wordpress:verify_media[reset]` to queue them for re-fetching."
    end
  end

  desc "Report on media fetch progress"
  task media_status: :environment do
    MediaItem.group(:status).count.sort.each { |status, count| puts format("  %-8s %d", status, count) }

    failed = MediaItem.failed.limit(10)
    if failed.any?
      puts "\n  most recent failures:"
      failed.each { |item| puts "    #{item.key}: #{item.fetch_error}" }
    end
  end
end
