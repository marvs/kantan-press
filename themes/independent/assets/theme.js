// Fades the title and byline out as the cover image scrolls away, which is the
// one piece of behaviour this theme has.
//
// Plain browser JavaScript on purpose: Kantan Press has no build step, and a
// theme must not depend on the app's importmap.
(function () {
  "use strict";

  var cover = document.querySelector(".post-cover");
  if (!cover) return;

  var meta = cover.querySelector(".cover-meta");
  if (!meta) return;

  // Someone who has asked for less motion gets a title that simply stays put.
  var reduced = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)");
  if (reduced && reduced.matches) return;

  var ticking = false;

  function update() {
    ticking = false;

    var height = cover.offsetHeight;
    if (!height) return;

    var remaining = 1 - window.scrollY / height;
    meta.style.opacity = String(Math.min(1, Math.max(0, remaining)));
  }

  function schedule() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(update);
  }

  window.addEventListener("scroll", schedule, { passive: true });
  window.addEventListener("resize", schedule);
  update();
})();
