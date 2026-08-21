require "rails_helper"

RSpec.describe Themes::Renderer do
  let(:themes_root) { Pathname.new(theme_tmpdir) }

  def bundle(templates: {}, assets: {}, slug: "sample")
    dir = write_theme(slug: slug, parent: themes_root, templates: templates, assets: assets)
    Themes::Bundle.new(dir, source: :builtin)
  end

  it "renders the template inside the theme's layout" do
    theme = bundle(templates: {
      "layout" => "<html>[{{ content_for_layout }}]</html>",
      "post" => "the post"
    })

    expect(described_class.call(bundle: theme, template: "post")).to eq("<html>[the post]</html>")
  end

  it "passes assigns to both the template and the layout" do
    theme = bundle(templates: {
      "layout" => "{{ site.title }}:{{ content_for_layout }}",
      "post" => "{{ post.title }}"
    })
    post = create(:post, title: "Kantan Dev")

    output = described_class.call(
      bundle: theme, template: "post",
      assigns: { "post" => Themes::Drops::PostDrop.new(post), "site" => Themes::Drops::SiteDrop.new }
    )

    expect(output).to eq("Kantan Press:Kantan Dev")
  end

  it "exposes settings to the template" do
    theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "post" => "{{ settings.accent_color }}" })

    output = described_class.call(bundle: theme, template: "post", settings: { "accent_color" => "#57ad68" })

    expect(output).to eq("#57ad68")
  end

  it "falls back to the post template when the theme ships no page template" do
    theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "post" => "POST", "page" => nil })

    expect(described_class.call(bundle: theme, template: "page")).to eq("POST")
  end

  it "uses the page template when the theme does ship one" do
    theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "page" => "PAGE" })

    expect(described_class.call(bundle: theme, template: "page")).to eq("PAGE")
  end

  describe "safety" do
    it "raises on a syntax error rather than rendering half a page" do
      theme = bundle(templates: { "post" => "{% for %}" })

      expect { described_class.call(bundle: theme, template: "post") }.to raise_error(Liquid::Error)
    end

    it "raises when the theme has no such template" do
      theme = bundle(templates: { "index" => nil, "post" => nil })

      expect { described_class.call(bundle: theme, template: "index") }
        .to raise_error(Themes::Bundle::MissingTemplate)
    end

    it "stops a runaway template instead of exhausting the box" do
      stub_const("#{described_class}::RESOURCE_LIMITS", { render_length_limit: 200 })
      theme = bundle(templates: {
        "layout" => "{{ content_for_layout }}",
        "post" => "{% for i in (1..10000) %}xxxxxxxxxx{% endfor %}"
      })

      expect { described_class.call(bundle: theme, template: "post") }.to raise_error(Liquid::Error)
    end

    it "gives each render its own resource budget" do
      stub_const("#{described_class}::RESOURCE_LIMITS", { render_length_limit: 500 })
      theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "post" => "0123456789" * 20 })

      3.times { expect(described_class.call(bundle: theme, template: "post").length).to eq(200) }
    end

    it "cannot reach Ruby through a drop it was not given" do
      theme = bundle(templates: {
        "layout" => "{{ content_for_layout }}",
        "post" => "[{{ post.record.class }}][{{ post.destroy }}][{{ 'x' | class }}]"
      })
      post = create(:post, title: "Still here")

      output = described_class.call(bundle: theme, template: "post",
                                    assigns: { "post" => Themes::Drops::PostDrop.new(post) })

      # Undeclared drop methods resolve to nothing, and `class` is not a filter,
      # so Liquid passes the value straight through rather than calling Ruby.
      expect(output).to eq("[][][x]")
      expect(output).not_to include("String", "Post")
      expect(post.reload).to be_persisted
    end
  end

  describe "template caching" do
    it "reparses after the template file changes" do
      theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "post" => "before" })

      expect(described_class.call(bundle: theme, template: "post")).to eq("before")

      path = theme.root.join("templates", "post.liquid")
      path.write("after")
      later = Time.now + 5
      File.utime(later, later, path.to_s)

      expect(described_class.call(bundle: theme, template: "post")).to eq("after")
    end
  end

  describe "filters" do
    it "builds a versioned asset url" do
      theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "post" => "{{ 'theme.css' | asset_url }}" },
                     assets: { "theme.css" => "body{}" })

      expect(described_class.call(bundle: theme, template: "post"))
        .to match(%r{\A/themes/sample/assets/theme\.css\?v=\w+\z})
    end

    it "builds an asset url for a nested file" do
      theme = bundle(templates: { "layout" => "{{ content_for_layout }}",
                                  "post" => "{{ 'fonts/pt-sans.woff2' | asset_url }}" },
                     assets: { "fonts/pt-sans.woff2" => "x" })

      expect(described_class.call(bundle: theme, template: "post"))
        .to start_with("/themes/sample/assets/fonts/pt-sans.woff2?v=")
    end

    it "returns nothing for an asset the theme does not ship" do
      theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "post" => "[{{ '../theme.json' | asset_url }}]" })

      expect(described_class.call(bundle: theme, template: "post")).to eq("[]")
    end

    it "builds site urls" do
      theme = bundle(templates: {
        "layout" => "{{ content_for_layout }}",
        "post" => "{{ 'hello' | post_url }} {{ 'ai' | category_url }} {{ 'llm' | tag_url }}"
      })

      expect(described_class.call(bundle: theme, template: "post")).to eq("/hello /category/ai /tag/llm")
    end

    it "formats a word count with thousands separators" do
      theme = bundle(templates: { "layout" => "{{ content_for_layout }}", "post" => "{{ 1337 | number_with_delimiter }}" })

      expect(described_class.call(bundle: theme, template: "post")).to eq("1,337")
    end
  end
end
