require "rails_helper"

# Twice now a rendering gap has only surfaced by looking at a real page: an
# image drifted left because .aligncenter had no rule, and a YouTube embed
# showed as plain text. Request specs can't judge visual output, but they can
# hold the two halves that failed:
#
#   1. WordPress's layout classes survive from stored content into the HTML
#   2. the stylesheet actually defines a rule for each class we rely on
#
# Together those catch "the class reaches the page but nothing styles it",
# which is exactly what went wrong.
RSpec.describe "block rendering" do
  STYLESHEET = Rails.root.join("app/assets/stylesheets/application.css")

  # Every layout-significant class in the imported content, with a real sample
  # of the markup WordPress produces for it.
  #
  # role: :subject  — the class names the element being styled, so a rule must
  #                   target it directly.
  # role: :modifier — the class legitimately only qualifies an ancestor (table
  #                   stripes style the rows; an aspect class sizes the wrapper
  #                   inside it), so it need only appear in some selector.
  BLOCK_SAMPLES = {
    "aligncenter" => { role: :subject, markup: %(<figure class="wp-block-image aligncenter is-resized"><img src="/media/a.png" alt=""/></figure>) },
    "alignleft" => { role: :subject, markup: %(<figure class="wp-block-image alignleft"><img src="/media/a.png" alt=""/></figure>) },
    "alignright" => { role: :subject, markup: %(<figure class="wp-block-image alignright"><img src="/media/a.png" alt=""/></figure>) },
    "alignnone" => { role: :subject, markup: %(<img class="alignnone size-full" src="/media/a.png" alt=""/>) },
    "wp-block-image" => { role: :subject, markup: %(<figure class="wp-block-image size-full"><img src="/media/a.png" alt=""/></figure>) },
    "wp-block-preformatted" => { role: :subject, markup: %(<pre class="wp-block-preformatted">plain text</pre>) },
    "wp-block-code" => { role: :subject, markup: %(<pre class="wp-block-code"><code>curl example.com</code></pre>) },
    "wp-block-quote" => { role: :subject, markup: %(<blockquote class="wp-block-quote"><p>Quoted.</p></blockquote>) },
    "wp-block-separator" => { role: :subject, markup: %(<hr class="wp-block-separator"/>) },
    "wp-block-spacer" => { role: :subject, markup: %(<div style="height:40px" aria-hidden="true" class="wp-block-spacer"></div>) },
    "wp-block-table" => { role: :subject, markup: %(<table class="wp-block-table"><tbody><tr><td>a</td></tr></tbody></table>) },
    "wp-block-embed" => { role: :subject, markup: %(<figure class="wp-block-embed wp-embed-aspect-16-9"><div class="wp-block-embed__wrapper">https://youtu.be/abcdefg</div></figure>) },
    "is-style-stripes" => { role: :modifier, markup: %(<table class="wp-block-table is-style-stripes"><tbody><tr><td>a</td></tr></tbody></table>) },
    "wp-embed-aspect-4-3" => { role: :modifier, markup: %(<figure class="wp-block-embed wp-embed-aspect-4-3"><div class="wp-block-embed__wrapper">https://youtu.be/abcdefg</div></figure>) }
  }.freeze

  describe "stored block classes reach the rendered page" do
    BLOCK_SAMPLES.each do |css_class, sample|
      it "renders #{css_class}" do
        create(:post, slug: "sample-#{css_class}", content: sample[:markup])

        get "/sample-#{css_class}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(css_class)
      end
    end
  end

  describe "the stylesheet defines a rule for every class we render" do
    # Checking that the class name merely appears somewhere in the file proves
    # nothing: ".post-body .aligncenter figcaption" contains "aligncenter"
    # while styling figcaption. A rule only counts when the class is the
    # *subject* — the last compound selector, the element actually targeted.
    def self.rules
      @rules ||= STYLESHEET.read
                           .gsub(%r{/\*.*?\*/}m, " ")
                           .scan(/([^{}]+)\{([^{}]*)\}/)
                           .map { |selector, body| [ selector.strip, body.strip ] }
    end

    def self.subjects_for(css_class)
      rules.select do |selector, body|
        next false if body.empty?

        selector.split(",").any? do |part|
          subject = part.strip
                        .gsub(/:has\([^)]*\)/, "")   # :has(> iframe) hides the real subject
                        .split(/[\s>+~]+/).last.to_s

          subject.include?(".#{css_class}")
        end
      end
    end

    def self.mentions_for(css_class)
      rules.select { |selector, body| !body.empty? && selector.include?(".#{css_class}") }
    end

    BLOCK_SAMPLES.each do |css_class, sample|
      if sample[:role] == :subject
        it "targets .#{css_class} as the subject of a rule" do
          expect(self.class.subjects_for(css_class)).not_to be_empty,
                                                            "'#{css_class}' appears in imported content but nothing in " \
                                                            "application.css targets it — the markup will render unstyled"
        end
      else
        it "uses .#{css_class} to qualify a rule" do
          expect(self.class.mentions_for(css_class)).not_to be_empty,
                                                            "'#{css_class}' appears in imported content but is absent " \
                                                            "from application.css entirely"
        end
      end

      it "scopes .#{css_class} to .post-body so it cannot leak into the admin" do
        unscoped = self.class.mentions_for(css_class).reject { |selector, _| selector.include?(".post-body") }

        expect(unscoped).to be_empty,
                            "these rules for .#{css_class} are not scoped to .post-body: " \
                            "#{unscoped.map(&:first).inspect}"
      end
    end
  end

  describe "content that must survive rendering untouched" do
    it "keeps block delimiter comments" do
      create(:post, slug: "delimiters",
                    content: "<!-- wp:paragraph -->\n<p>Body.</p>\n<!-- /wp:paragraph -->")

      get "/delimiters"

      expect(response.body).to include("<!-- wp:paragraph -->", "<!-- /wp:paragraph -->")
    end

    it "does not escape stored markup" do
      create(:post, slug: "unescaped", content: %(<figure class="wp-block-image"><img src="/media/a.png" alt=""/></figure>))

      get "/unescaped"

      expect(response.body).to include(%(<figure class="wp-block-image">))
      expect(response.body).not_to include("&lt;figure")
    end
  end

  describe "YouTube embeds" do
    it "renders an iframe rather than the bare URL WordPress stores" do
      create(:post, slug: "video", content: BLOCK_SAMPLES.dig("wp-block-embed", :markup))

      get "/video"

      expect(response.body).to include("<iframe", "youtube-nocookie.com/embed/abcdefg")
      expect(response.body).not_to include(">https://youtu.be/abcdefg<")
    end

    it "leaves a provider it cannot resolve as a readable link" do
      create(:post, slug: "vimeo", content: %(<figure class="wp-block-embed"><div class="wp-block-embed__wrapper">https://vimeo.com/123456789</div></figure>))

      get "/vimeo"

      expect(response.body).to include("https://vimeo.com/123456789")
      expect(response.body).not_to include("<iframe")
    end
  end

  describe "excerpts" do
    it "renders excerpt markup on the index rather than escaping it" do
      create(:post, title: "Marked up", excerpt: "<em>Emphasised</em> summary.")

      get root_path

      expect(response.body).to include("<em>Emphasised</em> summary.")
    end

    it "strips markup out of the meta description" do
      create(:post, slug: "meta", excerpt: "<em>Emphasised</em> summary.")

      get "/meta"

      expect(response.body).to match(/<meta name="description" content="Emphasised summary\.">/)
    end
  end
end
