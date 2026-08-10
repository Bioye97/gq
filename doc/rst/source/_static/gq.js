(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    var selector = document.querySelector(".gq-version-select");

    if (selector) {
      selector.addEventListener("change", function () {
        if (this.value) {
          window.location.href = this.value;
        }
      });
    }
  });
}());
