# Kantan Press

A small blog engine for people leaving WordPress but keeping their content.

It imports a WordPress WXR export, downloads the images that went with it, and
serves the result at the same URLs — while storing post bodies in WordPress's
own block format so nothing is lost in translation.

- **Rails 8.1**, SQLite, Solid Queue
- **Themes** in Liquid, importable as a zip, with a full-width cover-image theme
  in the box
- **Media on any S3-compatible store** — Cloudflare R2, AWS S3, DigitalOcean
  Spaces — or local disk in development
- **Deploys with Kamal** onto a small VPS, happily alongside other apps

## Why block markup stays as-is

WordPress does not store a block tree. It stores HTML with block delimiters in
comments:

```html
<!-- wp:paragraph -->
<p>Hello.</p>
<!-- /wp:paragraph -->
```

Browsers ignore comments, so that string renders correctly with no
transformation at all. Three things follow, and they shape the whole design:

1. `posts.content` is a plain `TEXT` column. No block schema, no migrations
   when blocks change.
2. Rendering is `content.html_safe`. There is no block renderer to maintain.
3. It round-trips losslessly, so a block editor can be added later without
   touching the data.

## Getting started

```bash
bin/setup                      # bundle + prepare the database
bin/rails db:seed              # create the first admin user (prints a password)
bin/rails server
```

Sign in at `/session/new`, then go to `/admin`.

With no configuration, media is written to `public/media` and served from
`/media`, so the importer works out of the box.

## Importing from WordPress

In WordPress: **Tools → Export → All content**. Then either upload the file at
`/admin/imports/new`, or:

```bash
bin/rails "wordpress:import[path/to/export.xml]"
bin/jobs                       # downloads the images the import registered
```

The import creates records fast and registers every image it finds; the actual
downloads run as one background job per image. That way a 200-image migration
does not block, and individual failures retry on their own.

```bash
bin/rails wordpress:media_status   # how many stored / pending / failed
bin/rails wordpress:retry_media    # re-queue anything not yet stored
bin/rails wordpress:verify_media   # check every "stored" image is really in the bucket
```

Re-running the same export updates records in place — it matches on WordPress
IDs rather than creating duplicates.

### What the importer handles

| | |
|---|---|
| Posts and pages | Block markup and classic HTML alike, kept verbatim |
| Statuses | `publish` → published; drafts, private and scheduled → draft |
| Revisions, nav items | Skipped |
| Categories | Including nesting |
| Tags | |
| Attachments | Registered under their original `wp-content/uploads/…` key |
| srcset variants | Discovered by scanning post bodies, not just the export |
| Featured images | Resolved through `_thumbnail_id` |
| Comments | Including reply threading and the approval flag |
| Permalinks | A 301 is recorded whenever the old path differs from the new slug |
| `/?p=123` | Resolved via the retained WordPress post ID |

### The one rule that matters for images

Uploads keep their **original object key**:

```
https://techandfi.com/wp-content/uploads/2024/01/foo.jpg
                     └──────────────── key ─────────────┘
```

Because the key is unchanged, making every image in every post work again is a
host substitution and nothing more — no markup parsing, and each `srcset`
variant is fixed by the same pass.

That host is `KANTAN_MEDIA_BASE_URL`, and it should always be a domain **you**
control (`cdn.example.com`), never the raw bucket endpoint. Repointing a CDN
then costs a DNS change instead of another pass over every post.

## Configuration

Copy `.env.example`. Every value can live in ENV or in Rails credentials under
`kantan_press:`; ENV wins.

| Variable | Purpose |
|---|---|
| `KANTAN_SITE_TITLE` | Site name themes render; defaults to "Kantan Press". Admin → Settings overrides it |
| `KANTAN_SITE_DESCRIPTION` | Optional tagline under the site name. Admin → Settings overrides it |
| `KANTAN_MEDIA_BASE_URL` | Host written into post content for images |
| `KANTAN_LEGACY_SITE_URL` | Old site host; read from the export when unset |
| `KANTAN_STORAGE_BACKEND` | `disk` or `s3`; inferred from the S3 settings |
| `KANTAN_S3_ENDPOINT` | R2: `https://<account>.r2.cloudflarestorage.com` |
| `KANTAN_S3_BUCKET` | |
| `KANTAN_S3_ACCESS_KEY_ID` / `KANTAN_S3_SECRET_ACCESS_KEY` | |
| `KANTAN_S3_REGION` | `auto` for R2 |

Nothing in the storage layer is R2-specific — S3 and Spaces work with the same
settings, so switching providers is an endpoint change plus an `rclone sync`.

## Layout

```
app/services/wordpress/
  wxr_document.rb      parses the export; WXR 1.1 and 1.2
  importer.rb          orchestrates the whole thing
  content_rewriter.rb  finds and rehosts uploads URLs in post bodies
  media_fetcher.rb     downloads one image and stores it
app/services/object_store.rb
  disk_backend.rb      public/media, for development
  s3_backend.rb        any S3-compatible endpoint
app/jobs/wordpress/
  import_job.rb        runs an admin-uploaded export
  fetch_media_job.rb   one per image, with backoff and retries
app/services/themes/
  bundle.rb            one theme directory; the path-safety chokepoint
  registry.rb          discovers themes in themes/ and storage/themes/
  renderer.rb          renders a template inside the theme's layout
  installer.rb         validates and unpacks an uploaded .zip
  drops/               the only objects a template can reach
themes/independent/    the theme that ships with the app
```

## Tests

```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
```

The importer is covered against a fixture that mirrors a real export: Gutenberg
and classic posts side by side, srcset variants, PHP-serialized attachment
metadata, threaded comments, spam, a page, a draft and a revision.

## Settings

**Admin → Settings** holds the things a site owner changes: site title, tagline,
and how many posts the home page lists. They are stored in the database and take
effect immediately — no redeploy.

These **override** the matching `KANTAN_*` environment variables, which is the
opposite of every other setting in the table below. A form that silently lost to
a deploy-time variable would be worse than not having the form. Clearing a field
falls back to ENV, then to the built-in default.

Storage and S3 credentials are deliberately not editable there; they stay in ENV
or Rails credentials.

## Themes

The public site is rendered by the active theme. Pick or import one at
**Admin → Themes**.

A theme is a directory holding a `theme.json` manifest, Liquid templates and
static assets. Themes that ship with the app live in `themes/`; uploaded ones
are unpacked into `storage/themes/`, which Kamal keeps on the persistent volume,
so they survive a deploy.

**Themes are Liquid, not ERB, and that is the point.** Liquid is a sandbox: a
template reaches only the objects it is handed, so a theme downloaded from a
stranger cannot run Ruby, read the database, or reach your S3 credentials.
Installing a WordPress theme means trusting it with your whole server; installing
a Kantan Press theme does not.

The zip is treated as hostile until proven otherwise — uncompressed size and
entry-count caps, an extension allow-list, and refusal of any entry that is a
symlink or that would write outside the theme directory. Nothing is written
until the whole archive has passed and the result validates as a theme.

If a theme fails to render, production logs the error and falls back to the
app's own ERB views, so a broken theme cannot take the site down. In development
it raises instead.

Writing one: [docs/THEMES.md](docs/THEMES.md).

### The theme in the box

**Independent** is a port of Raam Dev's Independent Publisher: a full-width
cover image carrying the post title, which fades out as you scroll; PT Serif for
the body and PT Sans for everything else, both self-hosted; and no sidebar. Four
settings — accent colour, cover height, word count, body font.

The index and archives list posts as compact cards — a cropped thumbnail beside
the text — rather than at full width. Featured images here are usually
screenshots, and at full width each entry ran to about a screen on its own.

## The editor

Posts are edited in the real Gutenberg block editor, via Automattic's
[isolated-block-editor](https://github.com/Automattic/isolated-block-editor).

It is vendored as a **prebuilt browser bundle** in `vendor/editor/` rather than
compiled here. The `@wordpress/*` packages ship ESM with incorrect export maps,
which webpack tolerates and rolldown (Vite 8's bundler) correctly rejects;
Automattic publishes the prebuilt bundle precisely so consumers do not have to
fight that. The upshot is that Kantan Press has **no JavaScript build step and
needs no Node at deploy time** — `assets:precompile` is the whole story.

Node 22 is only required to refresh that bundle (`bin/rails kantan:vendor_editor`),
and is pinned in `.nvmrc`, `package.json` engines, and `.npmrc`.

`wp.attachEditor` binds the editor to the content textarea: it parses block
markup on load, runs classic-editor HTML through `rawHandler`, and writes
serialised markup back to the field on every change. The surrounding Rails form
submits normally, so **no JavaScript sits on the save path**. "Edit as source"
reveals the raw textarea when hand-editing markup is quicker.

Images dropped into the editor upload to `POST /admin/media_items/upload`, which
files them under the same `wp-content/uploads/YYYY/MM/` convention as imported
media so the bucket has one key scheme throughout.

### One fidelity note

WordPress adds `srcset` and `sizes` at *render* time, not in stored content, so
a WXR export's image blocks carry neither — and Kantan Press keeps them that
way. Storing srcset in content would make Gutenberg flag the block as "invalid"
on edit. The consequence is that imported images serve at a single size rather
than responsively; the generated variants are still fetched into the bucket
whenever a post references them directly, which classic-editor posts often do.

## Not here yet

- **Accepting new comments.** Imported ones display read-only; there is no
  submission form and so no spam handling to own.
- **Sidebars and widget areas.** The theme in the box has none; a theme that
  wants one has no API to hang it on yet.
- **Theme partials.** `{% render %}` has no file system wired up, so shared
  markup is duplicated between a theme's templates.
- **Static generation.** The public side is server-rendered and cheap to cache;
  freezing it to files is a rake task away because the controllers are pure.
- **Responsive images.** See the fidelity note above.
