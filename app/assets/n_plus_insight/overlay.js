(function () {
  "use strict";

  var root = document.getElementById("n1v-root");
  if (!root || root.dataset.initialized === "true") return;
  root.dataset.initialized = "true";

  function element(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function decodePayload(value) {
    try {
      var bytes = Uint8Array.from(atob(value), function (character) {
        return character.charCodeAt(0);
      });
      return JSON.parse(new TextDecoder().decode(bytes));
    } catch (_error) {
      return [];
    }
  }

  var findings = decodePayload(root.dataset.payload || "");
  var launcher = element("button", "n1v-launcher" + (findings.length ? " n1v-has-alert" : ""), "N+1");
  launcher.type = "button";
  launcher.setAttribute("aria-label", findings.length ? "Open NPlusInsight: " + findings.length + " detected" : "Open NPlusInsight: no detections");
  launcher.setAttribute("aria-expanded", "false");

  if (findings.length) {
    var count = element("span", "n1v-count", String(findings.length));
    count.setAttribute("aria-hidden", "true");
    launcher.appendChild(count);
  }

  var panel = element("aside", "n1v-panel");
  panel.id = "n1v-panel";
  panel.setAttribute("aria-hidden", "true");
  panel.setAttribute("aria-label", "N+1 query details");
  launcher.setAttribute("aria-controls", panel.id);

  var header = element("div", "n1v-header");
  var headingWrap = element("div");
  headingWrap.appendChild(element("h2", "n1v-title", findings.length ? "N+1 detected" : "No N+1 queries"));
  headingWrap.appendChild(element("p", "n1v-subtitle", findings.length ? findings.length + " repeated query pattern" + (findings.length === 1 ? "" : "s") + " on this page" : "This request is clear"));
  header.appendChild(headingWrap);

  var close = element("button", "n1v-close", "×");
  close.type = "button";
  close.setAttribute("aria-label", "Close NPlusInsight");
  header.appendChild(close);
  panel.appendChild(header);

  var body = element("div", "n1v-body");
  panel.appendChild(body);

  function appendCode(container, code) {
    var pre = element("pre", "n1v-code");
    pre.appendChild(element("code", "", code || ""));
    container.appendChild(pre);
  }

  function renderSource(container, finding) {
    var section = element("section", "n1v-section");
    section.appendChild(element("h3", "n1v-heading", "Relevant source"));
    if (!finding.location) {
      section.appendChild(element("p", "n1v-location", "No application stack frame was captured."));
      container.appendChild(section);
      return;
    }
    section.appendChild(element("p", "n1v-location", finding.location.path + ":" + finding.location.line));
    var pre = element("pre", "n1v-code");
    var code = element("code");
    (finding.location.snippet || []).forEach(function (sourceLine) {
      var row = element("span", "n1v-line" + (sourceLine.active ? " n1v-active" : ""));
      row.appendChild(element("span", "n1v-line-number", String(sourceLine.line)));
      row.appendChild(element("span", "", sourceLine.text));
      code.appendChild(row);
    });
    pre.appendChild(code);
    section.appendChild(pre);
    container.appendChild(section);
  }

  function renderGraph(container, finding) {
    var section = element("section", "n1v-section");
    section.appendChild(element("h3", "n1v-heading", "Affected models"));
    var graph = element("div", "n1v-graph");
    graph.setAttribute("role", "img");
    graph.setAttribute("aria-label", "Model associations involved in the repeated query");
    (finding.models || []).forEach(function (model, index) {
      if (index > 0) {
        var edge = (finding.edges || [])[index - 1];
        graph.appendChild(element("span", "n1v-edge", (edge && edge.association ? edge.association + " " : "") + "→"));
      }
      var node = element("div", "n1v-node");
      node.appendChild(element("strong", "", model.name));
      node.appendChild(element("small", "", model.table));
      graph.appendChild(node);
    });
    section.appendChild(graph);
    container.appendChild(section);
  }

  function renderFixes(container, finding) {
    var section = element("section", "n1v-section");
    section.appendChild(element("h3", "n1v-heading", "Remediation"));
    (finding.suggestions || []).forEach(function (suggestion) {
      var fix = element("div", "n1v-fix");
      var copy = element("button", "n1v-copy", "Copy");
      copy.type = "button";
      copy.addEventListener("click", function () {
        navigator.clipboard.writeText(suggestion.code).then(function () {
          copy.textContent = "Copied";
          window.setTimeout(function () { copy.textContent = "Copy"; }, 1200);
        });
      });
      fix.appendChild(copy);
      fix.appendChild(element("h4", "n1v-fix-title", suggestion.title));
      appendCode(fix, suggestion.code);
      section.appendChild(fix);
    });
    container.appendChild(section);
  }

  function renderFinding(index) {
    body.textContent = "";
    if (!findings.length) {
      body.appendChild(element("div", "n1v-empty", "No repeated Active Record query shapes were captured while rendering this page."));
      return;
    }

    if (findings.length > 1) {
      var tabs = element("div", "n1v-tabs");
      tabs.setAttribute("role", "tablist");
      findings.forEach(function (finding, tabIndex) {
        var tab = element("button", "n1v-tab", "#" + (tabIndex + 1) + " · " + finding.query_count + " queries");
        tab.type = "button";
        tab.setAttribute("role", "tab");
        tab.setAttribute("aria-selected", String(tabIndex === index));
        tab.addEventListener("click", function () { renderFinding(tabIndex); });
        tabs.appendChild(tab);
      });
      body.appendChild(tabs);
    }

    var finding = findings[index];
    renderSource(body, finding);
    renderGraph(body, finding);
    renderFixes(body, finding);
  }

  function setOpen(open) {
    panel.setAttribute("aria-hidden", String(!open));
    launcher.setAttribute("aria-expanded", String(open));
    if (open) close.focus();
    else launcher.focus();
  }

  launcher.addEventListener("click", function () {
    setOpen(panel.getAttribute("aria-hidden") === "true");
  });
  close.addEventListener("click", function () { setOpen(false); });
  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && panel.getAttribute("aria-hidden") === "false") setOpen(false);
  });

  renderFinding(0);
  root.appendChild(panel);
  root.appendChild(launcher);
}());
