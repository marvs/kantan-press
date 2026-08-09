# Vendored block editor

These files are Automattic's prebuilt browser build of
[isolated-block-editor](https://github.com/Automattic/isolated-block-editor),
plus the React UMD builds it expects as globals.

They are committed rather than bundled on purpose. The `@wordpress/*` packages
ship ESM with incorrect export maps (`@wordpress/sync` in particular declares
exports it does not have), which webpack tolerates and rolldown — the bundler
behind Vite 8 — correctly rejects. Automattic publishes this prebuilt bundle
precisely so consumers do not have to fight that, and using it means Kantan
Press has **no JavaScript build step and no Node dependency at deploy time**.

| File | Source | Notes |
|---|---|---|
| `isolated-block-editor.js` | `@automattic/isolated-block-editor@2.30.0/build-browser/` | Self-contained IIFE, exposes `window.wp` |
| `isolated-block-editor.css` | same | Editor chrome |
| `core.css` | same | Gutenberg core block styles |
| `react.js` | `react@18/umd/react.production.min.js` | Loaded as `window.React` first |
| `react-dom.js` | `react-dom@18/umd/react-dom.production.min.js` | Loaded as `window.ReactDOM` first |

React 18 specifically — the bundle targets Gutenberg 20.x, which is not built
against React 19.

## Refreshing

```bash
npm install @automattic/isolated-block-editor@<version> react@18 react-dom@18
bin/rails kantan:vendor_editor
```

Node is only needed for that one command, never to run or deploy the app.
