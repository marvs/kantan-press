module KantanPress
  # Turns stored post markup into readable plain text, for excerpts, meta
  # descriptions and word counts.
  module PlainText
    module_function

    def call(html)
      # Block delimiters are HTML comments, so they have to go before tags do or
      # their contents leak into the text.
      stripped = ActionController::Base.helpers.strip_tags(html.to_s.gsub(/<!--.*?-->/m, " "))

      # strip_tags leaves HTML entities encoded, and imported WordPress content
      # is full of them. Without decoding here the entity is escaped a second
      # time on output and the reader sees "All&#39;s" instead of "All's".
      CGI.unescapeHTML(stripped.to_s).squish
    end
  end
end
