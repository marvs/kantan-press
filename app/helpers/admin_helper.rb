module AdminHelper
  def admin_nav_class(section)
    controller_name == section ? "active" : nil
  end

  # Puts the already-selected terms at the top of a checkbox list. Without this
  # a selection can sit below the scroll fold, so a post looks uncategorised
  # when it isn't.
  def selected_first(collection, selected_ids)
    collection.to_a.partition { |record| selected_ids.include?(record.id) }.flatten
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
