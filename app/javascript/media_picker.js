// Featured-image picker: filters the thumbnail grid by filename and swaps the
// preview when a different image is chosen.
//
// With a few hundred images in the library a plain grid is unusable, and a
// <select> hides the one thing that matters — what the picture looks like.

(function () {
  "use strict";

  function wire(picker) {
    if (picker.dataset.wired === "true") return;
    picker.dataset.wired = "true";

    var filter = picker.querySelector("[data-media-filter]");
    var grid = picker.querySelector("[data-media-grid]");
    var current = picker.querySelector(".media-current");

    if (filter && grid) {
      filter.addEventListener("input", function () {
        var term = filter.value.trim().toLowerCase();

        grid.querySelectorAll(".media-option[data-filename]").forEach(function (option) {
          var match = !term || option.dataset.filename.indexOf(term) !== -1;
          option.hidden = !match;
        });
      });

      // Enter would otherwise submit the post form from a filter box.
      filter.addEventListener("keydown", function (event) {
        if (event.key === "Enter") event.preventDefault();
      });
    }

    if (grid && current) {
      grid.addEventListener("change", function (event) {
        var radio = event.target;
        if (!radio.matches('input[type="radio"]')) return;

        var thumb = radio.parentElement.querySelector("img");
        current.innerHTML = "";

        if (thumb) {
          var preview = document.createElement("img");
          preview.src = thumb.src;
          preview.alt = thumb.alt;
          current.appendChild(preview);

          var name = document.createElement("div");
          name.className = "muted mono";
          name.textContent = thumb.title || "";
          current.appendChild(name);
        } else {
          var empty = document.createElement("div");
          empty.className = "media-empty";
          empty.textContent = "No featured image";
          current.appendChild(empty);
        }
      });
    }
  }

  function init() {
    document.querySelectorAll("[data-media-picker]").forEach(wire);
  }

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
