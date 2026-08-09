# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# The Gutenberg block editor is vendored as Automattic's prebuilt browser
# bundle rather than compiled here. It is a self-contained IIFE with React as
# its only external, so the admin needs no JavaScript build step at all —
# see vendor/editor/README.md for how to refresh it.
Rails.application.config.assets.paths << Rails.root.join("vendor/editor")
