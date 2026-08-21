require "tmpdir"
require "zip"
require "fileutils"
require "json"

# Builds throwaway theme directories on disk. Themes are read from the
# filesystem rather than the database, so almost every theme spec needs a real
# directory to point at.
module ThemeFixtures
  DEFAULT_MANIFEST = {
    "name" => "Sample",
    "slug" => "sample",
    "version" => "1.0.0",
    "author" => "Tester",
    "kantan_theme_api" => 1
  }.freeze

  DEFAULT_TEMPLATES = {
    "layout" => "<html><body>{{ content_for_layout }}</body></html>",
    "index" => "INDEX",
    "post" => "POST {{ post.title }}",
    "page" => "PAGE {{ post.title }}",
    "archive" => "ARCHIVE"
  }.freeze

  # Writes a theme into +parent+ (a fresh tmpdir by default) and returns the
  # theme's own directory. Pass manifest: nil to omit theme.json entirely.
  def write_theme(slug: "sample", parent: nil, manifest: {}, templates: {}, assets: {})
    parent ||= theme_tmpdir
    dir = Pathname.new(parent).join(slug)
    FileUtils.mkdir_p(dir)

    unless manifest.nil?
      merged = DEFAULT_MANIFEST.merge("slug" => slug).merge(manifest.transform_keys(&:to_s))
      dir.join("theme.json").write(JSON.pretty_generate(merged))
    end

    DEFAULT_TEMPLATES.merge(templates.transform_keys(&:to_s)).each do |name, source|
      next if source.nil?

      FileUtils.mkdir_p(dir.join("templates"))
      dir.join("templates", "#{name}.liquid").write(source)
    end

    assets.each do |path, contents|
      target = dir.join("assets", path.to_s)
      FileUtils.mkdir_p(target.dirname)
      target.write(contents)
    end

    dir
  end

  # theme.json that is not valid JSON at all, or is valid JSON but wrong.
  def write_raw_manifest(dir, body)
    Pathname.new(dir).join("theme.json").write(body)
  end

  # Builds a .zip on disk from a { "path/in/zip" => contents } hash. Pass a
  # Pathname value to store a real symlink, which is how the traversal specs get
  # a symlink entry into the archive.
  def build_theme_zip(entries, name: "theme.zip")
    path = Pathname.new(theme_tmpdir).join(name)

    Zip::File.open(path.to_s, Zip::File::CREATE) do |zip|
      entries.each do |entry_name, contents|
        if contents.is_a?(Pathname)
          zip.add(entry_name.to_s, contents.to_s)
        else
          zip.get_output_stream(entry_name.to_s) { |io| io.write(contents) }
        end
      end
    end

    path
  end

  # The manifest + templates a minimal installable theme needs, ready to be
  # merged into a zip entry hash.
  def zip_entries_for(slug: "downloaded", prefix: "", manifest: {}, extra: {})
    merged = DEFAULT_MANIFEST.merge("slug" => slug).merge(manifest.transform_keys(&:to_s))

    entries = { "#{prefix}theme.json" => JSON.pretty_generate(merged) }
    DEFAULT_TEMPLATES.each { |name, source| entries["#{prefix}templates/#{name}.liquid"] = source }
    entries["#{prefix}assets/theme.css"] = "body{}"
    entries.merge(extra.transform_keys { |key| "#{prefix}#{key}" })
  end

  def theme_tmpdir
    @theme_tmpdirs ||= []
    Dir.mktmpdir("kantan-themes").tap { |dir| @theme_tmpdirs << dir }
  end

  def cleanup_theme_tmpdirs
    Array(@theme_tmpdirs).each { |dir| FileUtils.remove_entry(dir, true) }
    @theme_tmpdirs = []
  end
end

RSpec.configure do |config|
  config.include ThemeFixtures
  config.after { cleanup_theme_tmpdirs }
end
