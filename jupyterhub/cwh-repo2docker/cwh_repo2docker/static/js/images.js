require([
  "jquery", "bootstrap", "moment", "jhapi", "utils",
  "static/vendor/xterm-addon-fit.js",
  "static/vendor/xterm.js"
], function(
  $,
  bs,
  moment,
  JHAPI,
  utils,
  fit,
  xterm
) {
  "use strict";

  var base_url = window.jhdata.base_url;
  var xsrf_token = window.jhdata.xsrf_token || window.xsrf_token;
  var api = new JHAPI(base_url);

  function getRow(element) {
    var original = element;
    while (!element.hasClass("image-row")) {
      element = element.parent();
      if (element[0].tagName === "BODY") {
        console.error("Couldn't find row for", original);
        throw new Error("No image-row found");
      }
    }
    return element;
  }

  $("#add-environment").click(function() {
    var dialog = $("#create-environment-dialog");
    dialog.find(".repo-input").val("");
    dialog.find(".ref-input").val("");
    dialog.find(".name-input").val("");
    dialog.find(".memory-input").val("");
    dialog.find(".cpu-input").val("");
    dialog.find(".build-args-input").val("");
    dialog.find(".username-input").val("");
    dialog.find(".password-input").val("");
    dialog.modal();
  });

  $(".set-default-course-image").click(function() {
    var el = $(this);
    var row = getRow(el);
    var name = row.data('image');
    var digest = row.data('manifest-digest');
    $.ajax("api/environments/default-course-image?_xsrf=" + xsrf_token, {
      type: "PUT",
      data: JSON.stringify({
        name: name,
        digest: digest
      }),
      success: function() {
        window.location.reload();
      }
    });
  });

  $("#create-environment-dialog")
    .find(".save-button")
    .click(function() {
      var dialog = $("#create-environment-dialog");
      var repo = dialog.find(".repo-input").val().trim();
      var ref = dialog.find(".ref-input").val().trim();
      var name = dialog.find(".name-input").val().trim();
      var buildargs = dialog.find(".build-args-input").val().trim();
      var username = dialog.find(".username-input").val().trim();
      var password = dialog.find(".password-input").val().trim();
      var spinner = $("#adding-environment-dialog");
      spinner.find('.modal-footer').remove();
      spinner.modal();
      $.ajax("api/environments?_xsrf=" + xsrf_token, {
        type: "POST",
        data: JSON.stringify({
          repo: repo,
          ref: ref,
          name: name,
          buildargs: buildargs,
          username: username,
          password: password,
        }),
        success: function() {
          window.location.reload();
        },
      });
    });

  $(".remove-environment").click(function() {
    var el = $(this);
    var row = getRow(el);
    var image = row.data("image");
    var name = row.data("display-name");
    var dialog = $("#remove-environment-dialog");
    dialog.find(".delete-environment").attr("data-image", image);
    dialog.find(".delete-environment").text(name);
    dialog.modal();
  });

  $("#remove-environment-dialog")
    .find(".remove-button")
    .click(function() {
      var dialog = $("#remove-environment-dialog");
      var image = dialog.find(".delete-environment").data("image");
      var spinner = $("#removing-environment-dialog");
      spinner.find('.modal-footer').remove();
      spinner.modal();
      $.ajax("api/environments?_xsrf=" + xsrf_token, {
        type: "DELETE",
        data: JSON.stringify({
          name: image
        }),
        success: function() {
          window.location.reload();
        },
      })
    });

  $(".logs").click(function() {
    var el = $(this);
    var row = getRow(el);
    var image = row.data("image");
    var dialog = $("#show-logs-dialog");

    var log = new xterm.Terminal({
      convertEol: true,
      disableStdin: true
    });
    var fitAddon = new fit.FitAddon();
    log.loadAddon(fitAddon);

    var eventSource;

    function showTerminal() {
      $(".build-logs").empty();
      log.clear();
      var container = dialog.find(".build-logs")[0];
      log.open(container);
      fitAddon.fit();

      var logsUrl = utils.url_path_join("api", "environments", image, "logs");
      logsUrl += "?_xsrf=" + xsrf_token;
      eventSource = new EventSource(logsUrl);
      eventSource.onerror = function(err) {
        console.error("Failed to construct event stream", err);
        eventSource.close();
      };
      eventSource.onmessage = function(event) {
        var data = JSON.parse(event.data);
        if (data.phase === 'built') {
          eventSource.close();
          return
        }
        log.write(data.message);
        fitAddon.fit();
      };
    }

    dialog.on('shown.bs.modal', showTerminal);
    dialog.on('hide.bs.modal', function () {
      dialog.off('shown.bs.modal', showTerminal);
      if (eventSource) {
        eventSource.close();
      }
    });
    dialog.modal();
  });

  // initialize tooltips
  $('[data-toggle="tooltip"]').tooltip();

});
