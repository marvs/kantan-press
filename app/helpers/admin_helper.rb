module AdminHelper
  def admin_nav_class(section)
    controller_name == section ? "active" : nil
  end

  def status_pill(status)
    tag.span(status.to_s.humanize, class: "pill pill-#{status}")
  end

  def import_summary(import)
    return "—" if import.stats.blank?

    import.stats.sort.filter_map do |kind, tallies|
      created = tallies["created"].to_i
      "#{created} #{kind}" if created.positive?
    end.join(", ").presence || "nothing new"
  end
end
