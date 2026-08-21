# Writing a theme for Kantan Press

A theme controls how the public site looks. It cannot touch the admin, the
editor, or the Atom feed.

Themes are written in [Liquid](https://shopify.github.io/liquid/), which is a
sandbox. A theme can only read what it is handed, so a theme downloaded from a
stranger **cannot run Ruby, read the database, or reach your storage
credentials**. That is the whole reason Liquid is used here rather than ERB.

## Package layout

```
my-theme/
├── theme.json                 required — manifest and settings schema
├── screenshot.svg             optional — also .png, .jpg or .webp
├── assets/
│   ├── theme.css
│   ├── theme.js
│   └── fonts/…
└── templates/
    ├── layout.liquid          required
    ├── index.liquid           required
    ├── post.liquid            required
    ├── page.liquid            optional — falls back to post.liquid
    └── archive.liquid         optional — falls back to index.liquid
```

Zip that directory and upload it at **Admin → Themes**. A single wrapper
directory is fine, so a zip downloaded straight from GitHub works.

Themes that ship with the app live in `themes/`; uploaded ones are extracted to
`storage/themes/`, which is on the persistent volume. A built-in theme always
wins a slug collision, so an upload can never shadow one.

## theme.json

```json
{
  "name": "Independent",
  "slug": "independent",
  "version": "1.0.0",
  "author": "Kantan Press",
  "author_url": "https://example.com",
  "description": "One sentence about the theme.",
  "kantan_theme_api": 1,
  "settings": [
    { "key": "accent_color", "type": "color", "label": "Accent colour", "default": "#57ad68" }
  ]
}
```

`slug` must match the directory name and be lowercase letters, numbers and
dashes. `kantan_theme_api` must be `1`.

The screenshot sits at the **theme root**, not in `assets/`, and is served at
`/themes/<slug>/screenshot` — the assets route only ever resolves paths inside
`assets/`.

### Settings

Each entry becomes a field on the theme's settings page, and the values arrive
in templates as `{{ settings.<key> }}`. Three types are supported:

| Type | Renders as | Validation |
|---|---|---|
| `color` | A colour picker | Must be `#rrggbb` |
| `select` | A dropdown; needs an `options` array | Must be one of the declared options |
| `boolean` | A checkbox | Coerced to true/false |

`options` entries are `{ "value": …, "label": … }` pairs, or bare strings.

A value that fails validation is refused, and a key the theme did not declare is
rejected rather than stored. That matters because these values are interpolated
straight into CSS by your layout — the schema is what makes that safe.

## Escaping — read this before writing a template

**Liquid does not escape output.** Jekyll and Shopify leave escaping to the
theme author; Kantan Press does not, because a theme that forgets `| escape`
would turn an imported WordPress post title into stored XSS.

So:

- **Text fields come back already escaped.** Write `{{ post.title }}`. Do *not*
  add `| escape` — that would escape it twice and the reader would see the
  entity.
- **Raw HTML is only reachable through a field ending in `_html`**, so emitting
  it is always deliberate: `{{ post.body_html }}`, `{{ comment.content_html }}`.

## Objects

Every template gets `site`, `settings`, `theme` and `page`.

### `site`

| Field | |
|---|---|
| `site.title`, `site.description` | From `KANTAN_SITE_TITLE` / `KANTAN_SITE_DESCRIPTION` |
| `site.url`, `site.feed_url` | |
| `site.categories`, `site.tags` | Arrays of category/tag objects, alphabetical |
| `site.pages` | Published pages, by title |

### `page`

Head metadata, computed by the app so a theme cannot get canonical URLs wrong:
`page.title`, `page.description`, `page.canonical_url`, `page.image_url`,
`page.kind` (`article` or `website`). Optional ones are nil when absent, so
`{% if page.image_url %}` works.

### `post`

Given to `post.liquid` and `page.liquid`, and looped over as `posts` in
`index.liquid` and `archive.liquid`.

| Field | |
|---|---|
| `post.title`, `post.slug`, `post.url` | |
| `post.body_html` | **Raw.** The stored block markup, with oEmbed URLs resolved |
| `post.excerpt` | Escaped plain text |
| `post.excerpt_html` | **Raw.** The hand-written excerpt if there is one |
| `post.published_at`, `post.updated_at` | Times — use the `date` filter |
| `post.word_count` | Integer |
| `post.author_name` | May be blank on imported posts |
| `post.categories`, `post.tags` | Each has `name`, `slug`, `url` |
| `post.featured_image` | Nil unless the image is stored; else `url`, `alt`, `title`, `caption`, `width`, `height` |
| `post.comments`, `post.comment_count` | Approved comments only |
| `post.page` | True for a page |

### `comment`

`author_name` (escaped), `author_url` (escaped, and empty unless http/https),
`content_html` (**sanitized** — the one field the public wrote),
`published_at`, `reply`.

### `pagination` (index) and `archive` (archives)

`pagination.current_page`, `total_pages`, `previous_url`, `next_url`. The urls
are nil at the ends.

`archive.title`, `archive.description`, `archive.kind` (`category`, `tag` or
`month`).

## Filters

On top of Liquid's own (`date`, `escape`, `strip_html`, `truncate`, …):

| Filter | |
|---|---|
| `{{ 'theme.css' \| asset_url }}` | URL for a file in `assets/`, with a cache-busting `?v=`. Empty if the theme does not ship it |
| `{{ slug \| post_url }}` | |
| `{{ slug \| category_url }}`, `{{ slug \| tag_url }}` | |
| `{{ year \| archive_url: month }}` | |
| `{{ 1337 \| number_with_delimiter }}` | `1,337` |

## Templates

`layout.liquid` wraps every page and must emit the whole document, `<!DOCTYPE
html>` included. The rendered page goes where you put `{{ content_for_layout }}`.

Everything else renders inside it. Assets are referenced with `asset_url`;
relative URLs inside a stylesheet (`url(fonts/x.woff2)`) resolve correctly
because the stylesheet is served from `assets/`.

## Limits worth knowing

- **No partials yet.** `{% render %}` and `{% include %}` have no file system
  wired up, so shared markup is duplicated between templates for now.
- **Settings types are `color`, `select` and `boolean`.** `text` and `number`
  are not implemented; adding one is a change to `Themes::Setting::TYPES` and
  the `_setting_field` partial.
- **Only `.css .js .map`, font, and image extensions are served** from
  `assets/`. `.liquid` and `.json` deliberately are not, so a theme cannot serve
  its own source.
- **Every asset is served under `default-src 'none'; sandbox`.** An SVG opened
  as a document would otherwise run its own `<script>` on the site's origin.
  This does not affect SVGs used in `<img>`, CSS, JS or fonts.
- Renders are subject to Liquid's resource limits, so a runaway loop aborts
  rather than taking the box down.
- If a theme raises, production logs the error and falls back to the app's own
  ERB views, so a broken theme cannot take the site down. In development it
  raises, so you see it immediately.

## Styling imported content

Imported posts carry WordPress's own block classes (`wp-block-image`,
`alignwide`, `is-style-stripes`, …). WordPress ships those styles as part of its
themes, so **your theme must style them too** or imported posts lose their
layout. The Independent theme's `theme.css` has a worked set to copy.
