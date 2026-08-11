// Post settings drawer.
//
// Settings sit off-screen so the article has the full width while writing, and
// slide in on demand. The panel stays inside the <form> — only its position is
// fixed — so every field still submits normally.

(function () {
  "use strict";

  var STORAGE_KEY = "kantan-press:settings-drawer";

  function open(drawer, toggle, remember) {
    drawer.classList.add("is-open");
    drawer.setAttribute("aria-hidden", "false");
    toggle.setAttribute("aria-expanded", "true");
    if (remember !== false) localStorage.setItem(STORAGE_KEY, "open");
  }

  function close(drawer, toggle, remember) {
    drawer.classList.remove("is-open");
    drawer.setAttribute("aria-hidden", "true");
    toggle.setAttribute("aria-expanded", "false");
    if (remember !== false) localStorage.setItem(STORAGE_KEY, "closed");
  }

  function wire() {
    var drawer = document.querySelector("[data-settings-drawer]");
    var toggle = document.querySelector("[data-settings-toggle]");
    if (!drawer || !toggle || drawer.dataset.wired === "true") return;

    drawer.dataset.wired = "true";

    toggle.addEventListener("click", function (event) {
      event.preventDefault();

      if (drawer.classList.contains("is-open")) {
        close(drawer, toggle);
        toggle.focus();
      } else {
        open(drawer, toggle);
        var first = drawer.querySelector("select, input, textarea, button");
        if (first) first.focus();
      }
    });

    drawer.querySelectorAll("[data-settings-close]").forEach(function (button) {
      button.addEventListener("click", function (event) {
        event.preventDefault();
        close(drawer, toggle);
        toggle.focus();
      });
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && drawer.classList.contains("is-open")) {
        close(drawer, toggle);
        toggle.focus();
      }
    });

    // A rejected save often fails on a field in here — the slug, say. Leaving
    // the drawer shut would hide the reason the post didn't save.
    if (drawer.dataset.hasErrors === "true") {
      open(drawer, toggle, false);
      return;
    }

    if (localStorage.getItem(STORAGE_KEY) === "open") open(drawer, toggle, false);
  }

  document.addEventListener("DOMContentLoaded", wire);
  document.addEventListener("turbo:load", wire);
})();
