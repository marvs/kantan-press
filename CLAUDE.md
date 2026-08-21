# Kantan Press — conventions

A Rails 8.1 blog engine for people leaving WordPress but keeping their content.
SQLite, Solid Queue, Kamal. Read `README.md` for what it does and why block
markup is stored verbatim.

## Commands

```bash
bundle exec rspec         # full suite
bundle exec rubocop       # rubocop-rails-omakase; zero offenses expected
bundle exec brakeman      # zero warnings expected
bin/rails server
```

All three must be green before a feature is reported as done. Do not invent
other commands.

## Stack facts worth not re-deriving

- **No JavaScript build step, and it must stay that way.** Propshaft plus
  importmap; the Gutenberg editor is a vendored prebuilt bundle in
  `vendor/editor/`. Node is only needed to refresh that bundle. Never introduce
  anything that needs `npm run build` at deploy time.
- React is in `package.json` only for that editor bundle. There is no SPA.
- Kamal mounts `kantan_press_storage` at `/rails/storage`, so **anything under
  `storage/` survives a deploy** and anything else written at runtime does not.
- The CSP initializer is entirely commented out.

## Code conventions

- **Services** live in `app/services/<namespace>/`, expose a `.call` class
  method, and hold the logic. Controllers stay thin; jobs delegate immediately.
- **Configuration** goes through `KantanPress::Config`, which reads ENV first and
  Rails credentials second. Never read `ENV` directly elsewhere. Add new
  settings to `.env.example` and the README table.
- Prefer endless method definitions for one-liners, as the existing code does —
  but **never with a trailing `if`**: `def x = y if cond` applies the modifier to
  the definition itself, not the body.
- Comments explain *why*, especially where the code looks odd. Match that
  density; the repo is heavily commented by intent.

## Testing

- RSpec. **Request specs for controllers, service specs for services**, model
  specs for model logic. `factory_bot`; shared helpers in `spec/support/`.
- Every example gets an in-memory `FakeObjectStore` and stubbed
  `KantanPress::Config`, so nothing touches a real bucket. Stub all external
  HTTP with WebMock — the suite must never hit the network.
- Write the failing test first, confirm it fails for the right reason, then make
  it pass.

## Text and escaping — bugs the codebase has already had

- Rails' **`truncate` view helper escapes its result and marks it `html_safe`**.
  For text that will be escaped again on output, use `String#truncate`.
- **`strip_tags` leaves HTML entities encoded.** Use
  `KantanPress::PlainText.call(html)` for anything that needs readable plain
  text — excerpts, meta descriptions, word counts. It strips block comments,
  strips tags, decodes entities and squishes.
- Post bodies are the author's own content and are emitted raw. Anything the
  public wrote (comment bodies) is sanitized.

## Themes

The public site renders through the active theme; the admin and editor never do.
See `docs/THEMES.md` for the theme-author contract and
`.kantan-dev/docs/20260821_themes.md` for how the engine is built.

- **A theme is a directory, and the filesystem owns its content.** The `themes`
  table stores only which theme is active and its settings.
- **Themes are Liquid, never ERB.** An imported theme is untrusted code; Liquid
  is the sandbox that makes importing one safe. Do not add an ERB escape hatch.
- **Drops return escaped text; raw HTML only through a `*_html` field.** Liquid
  does not escape output, so this is what stops an imported WordPress title
  becoming stored XSS. Every public method on a `Liquid::Drop` is callable from a
  template, so helpers on a drop are always `private`.
- **`Themes::Bundle#asset_path` is the only place path safety is decided.** New
  code that reads a file out of a theme goes through it rather than re-checking.
- A theme error raises outside production and falls back to the ERB views inside
  it. Keep the ERB views working.

## Patterns worth reusing

- **Serving files from outside `public/`:** resolve through a single
  path-safety chokepoint, allow-list extensions, `send_file` with an explicit
  content type (never sniffed), and a far-future `Cache-Control` paired with a
  `?v=` derived from mtime. Route must be declared **above**
  `get "/:slug"` and the `*path` catch-all in `routes.rb`, with `format: false`
  so a `.css` suffix stays in the path.
- **Serving JavaScript from a controller** needs `skip_forgery_protection`, or
  Rails' cross-origin JS guard returns 422 after the file is sent.
- **Serving user-supplied SVG** needs `Content-Security-Policy: default-src
  'none'; sandbox` and `X-Content-Type-Options: nosniff`. An SVG opened as a
  document runs its own `<script>` on your origin.
- **Accepting an archive upload:** cap the *uncompressed* size as well as the
  upload size, cap the entry count, allow-list extensions, refuse symlink and
  traversal entries, and validate everything before writing a byte. Stage inside
  the destination filesystem so the final step is an atomic rename, and restore
  the previous version if it fails.
- **Per-process caches are read by several Puma threads.** Use
  `Concurrent::Map`, not `Hash`.
- **Cache filesystem scans on a directory's mtime**, and only in production, so
  development stays live.
- **Never use `||=` for an identifier that comes from an import.** It means a
  wrong value can never be corrected, so re-running the import silently fails to
  heal the data. Assign explicitly, releasing the id from any other row that
  holds it, so the source file stays the source of truth.
- **A `stored` row is not proof the object exists.** The database and the bucket
  drift — an object deleted, or media fetched under the `disk` backend before
  the app was pointed at S3. `retry_media` skips such rows because they are not
  `awaiting_fetch`. `bin/rails wordpress:verify_media` is the check;
  `[reset]` queues what it finds.
- **Reading values out of someone else's CSS: keep the media-query context.**
  A base-level declaration is often the small-screen case that a later
  breakpoint overrides.
- **Enforce "only one row may be X" in the database**, with a partial unique
  index (`add_index :t, :active, unique: true, where: "active"`), not only in
  the model.
