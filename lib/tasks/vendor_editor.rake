namespace :kantan do
  desc "Refresh the vendored Gutenberg bundle from node_modules (needs Node 22 + npm install)"
  task :vendor_editor do
    require "fileutils"

    root = Pathname.new(__dir__).join("../..").expand_path
    destination = root.join("vendor/editor")
    editor = root.join("node_modules/@automattic/isolated-block-editor/build-browser")

    sources = {
      editor.join("isolated-block-editor.js") => "isolated-block-editor.js",
      editor.join("isolated-block-editor.css") => "isolated-block-editor.css",
      editor.join("core.css") => "core.css",
      root.join("node_modules/react/umd/react.production.min.js") => "react.js",
      root.join("node_modules/react-dom/umd/react-dom.production.min.js") => "react-dom.js"
    }

    missing = sources.keys.reject(&:exist?)
    if missing.any?
      abort <<~MESSAGE
        Missing #{missing.size} source file(s); run `npm install` on Node 22 first.
        #{missing.map { |path| "  #{path.relative_path_from(root)}" }.join("\n")}
      MESSAGE
    end

    FileUtils.mkdir_p(destination)
    sources.each do |source, name|
      FileUtils.cp(source, destination.join(name))
      puts format("  %-32s %s", name, ActiveSupport::NumberHelper.number_to_human_size(source.size))
    end

    puts "\nVendored to #{destination.relative_path_from(root)}. Commit the result — the app"
    puts "needs no Node at runtime or deploy time."
  end
end
