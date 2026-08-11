// Attaches the Gutenberg block editor to the post form's content field.
//
// The heavy lifting is in the vendored isolated-block-editor bundle, which
// exposes wp.attachEditor(textarea, settings). It reads the textarea's value,
// parses it as block markup (or runs classic HTML through rawHandler), and
// writes serialised block markup back to the textarea on every change — so the
// surrounding Rails form still submits normally, with no JS on the save path.

(function () {
  "use strict";

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  // Gutenberg's media upload contract: a FileList plus two callbacks. Each file
  // is POSTed to Rails, which pushes it to the object store and returns a
  // record the image block understands.
  function mediaUpload(options) {
    var files = Array.prototype.slice.call(options.filesList || []);

    files.forEach(function (file) {
      var body = new FormData();
      body.append("file", file);

      fetch("/admin/media_items/upload", {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken() },
        body: body,
      })
        .then(function (response) {
          if (!response.ok) {
            return response.json().then(
              function (payload) {
                throw new Error(payload.error || "Upload failed (" + response.status + ")");
              },
              function () {
                throw new Error("Upload failed (" + response.status + ")");
              }
            );
          }
          return response.json();
        })
        .then(function (media) {
          options.onFileChange([media]);
        })
        .catch(function (error) {
          if (options.onError) {
            options.onError({ code: "UPLOAD_ERROR", message: error.message, file: file });
          }
        });
    });
  }

  var SETTINGS = {
    iso: {
      // "Top toolbar" stays offered in the menu so it can be turned on, but it
      // is off by default: when the block toolbar is docked in the header the
      // library renders <BlockToolbar hideDragHandle />, which removes the drag
      // grip and the between-blocks inserter that WordPress users expect.
      moreMenu: { editor: true, fullscreen: false, preview: false, topToolbar: true },
      defaultPreferences: { fixedToolbar: false },

      // Popovers rather than docked sidebars. The admin form already owns the
      // right-hand column for post metadata, and two sidebars in one column
      // collide badly.
      sidebar: { inserter: false, inspector: false },
      toolbar: { inserter: true, navigation: false, undo: true, inspector: true },
    },
    editor: {
      hasUploadPermissions: true,
      hasFixedToolbar: false,
      mediaUpload: mediaUpload,
      bodyPlaceholder: "Write your post…",

      // Gutenberg disables the hover "+" between blocks when either of these is
      // on, and they default to undefined rather than false in this bundle.
      isDistractionFree: false,
      hasReducedUI: false,
    },
  };

  // Lets block markup be edited by hand, which is sometimes the quickest way to
  // fix an imported post.
  function wireSourceToggle(textarea) {
    var toggle = document.querySelector("[data-toggle-source]");
    if (!toggle) return;

    toggle.addEventListener("click", function (event) {
      event.preventDefault();

      // attachEditor inserts its own element directly after the textarea.
      var editor = textarea.nextSibling;
      var showingSource = textarea.style.display !== "none";

      textarea.style.display = showingSource ? "none" : "block";
      if (editor && editor.classList && editor.classList.contains("editor")) {
        editor.style.display = showingSource ? "" : "none";
      }
      toggle.textContent = showingSource ? "Edit as source" : "Back to editor";
    });
  }

  function attach() {
    var textarea = document.getElementById("post_content");
    if (!textarea || textarea.dataset.editorAttached === "true") return;

    if (!window.wp || typeof window.wp.attachEditor !== "function") {
      console.error("Block editor bundle did not load; leaving the raw textarea in place.");
      textarea.style.display = "block";
      return;
    }

    textarea.dataset.editorAttached = "true";
    window.wp.attachEditor(textarea, SETTINGS);
    wireSourceToggle(textarea);

    var placeholder = document.querySelector("[data-editor-placeholder]");
    if (placeholder) placeholder.remove();
  }

  document.addEventListener("DOMContentLoaded", attach);
  document.addEventListener("turbo:load", attach);
})();
