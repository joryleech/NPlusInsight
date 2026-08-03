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

  function formatMilliseconds(value) {
    return (Number(value) || 0)
      .toFixed(2)
      .replace(/\.00$/, "")
      .replace(/(\.\d)0$/, "$1");
  }

  function queryGroupsFor(finding) {
    if ((finding.query_groups || []).length) return finding.query_groups;
    return [{
      sql: finding.sql,
      query_count: finding.query_count,
      total_ms: finding.total_ms,
      tables: [],
      waterfall: []
    }];
  }

  function waterfallEntriesFor(group) {
    if ((group.waterfall || []).length) return group.waterfall;

    var count = Number(group.query_count) || 0;
    var duration = count ? (Number(group.total_ms) || 0) / count : 0;
    return Array.from({ length: count }, function (_value, index) {
      return {
        index: index + 1,
        offset_ms: duration * index,
        duration_ms: duration
      };
    });
  }

  var findings = decodePayload(root.dataset.payload || "");
  var initialFindingIndex = findings.reduce(function (bestIndex, finding, index) {
    var best = findings[bestIndex];
    var patternCount = queryGroupsFor(finding).length;
    var bestPatternCount = best ? queryGroupsFor(best).length : -1;

    if (patternCount > bestPatternCount) return index;
    if (patternCount === bestPatternCount && finding.query_count > best.query_count) return index;
    return bestIndex;
  }, 0);
  var patternCount = findings.reduce(function (total, finding) {
    return total + queryGroupsFor(finding).length;
  }, 0);

  var launcher = element("button", "n1v-launcher" + (findings.length ? " n1v-has-alert" : ""), "N+1");
  launcher.type = "button";
  launcher.setAttribute("aria-label", findings.length ? "Open NPlusInsight: " + findings.length + " affected source locations" : "Open NPlusInsight: no detections");
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
  headingWrap.appendChild(element(
    "p",
    "n1v-subtitle",
    findings.length ?
      findings.length + " affected source location" + (findings.length === 1 ? "" : "s") +
        " · " + patternCount + " query pattern" + (patternCount === 1 ? "" : "s") :
      "This request is clear"
  ));
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

  function renderQueries(container, finding) {
    var section = element("section", "n1v-section");
    section.appendChild(element("h3", "n1v-heading", "Repeated query patterns"));
    queryGroupsFor(finding).forEach(function (group, index) {
      var query = element("div", "n1v-query");
      var tables = (group.tables || []).join(", ");
      var metadata = "Pattern " + (index + 1) + " · " + group.query_count +
        " queries · " + group.total_ms + " ms" + (tables ? " · " + tables : "");
      query.appendChild(element("p", "n1v-query-meta", metadata));
      appendCode(query, group.sql);
      section.appendChild(query);
    });
    container.appendChild(section);
  }

  function renderWaterfall(container, finding) {
    var groups = queryGroupsFor(finding);
    var span = Number(finding.waterfall_ms) || groups.reduce(function (maximum, group) {
      return Math.max(maximum, waterfallEntriesFor(group).reduce(function (groupMaximum, query) {
        return Math.max(groupMaximum, Number(query.offset_ms) + Number(query.duration_ms));
      }, 0));
    }, 0);
    span = Math.max(span, 0.01);

    var section = element("section", "n1v-section");
    section.appendChild(element("h3", "n1v-heading", "Query loading waterfall"));
    section.appendChild(element(
      "p",
      "n1v-waterfall-summary",
      formatMilliseconds(finding.waterfall_ms || span) +
        " ms elapsed · " + finding.total_ms + " ms database time · Hover a bar for timing"
    ));

    var waterfall = element("div", "n1v-waterfall");
    waterfall.setAttribute("role", "img");
    waterfall.setAttribute(
      "aria-label",
      "Waterfall of repeated query patterns over " + Number(finding.waterfall_ms || span) + " milliseconds"
    );

    var axis = element("div", "n1v-waterfall-axis");
    axis.setAttribute("aria-hidden", "true");
    axis.appendChild(element("span", "", "0 ms"));
    axis.appendChild(element("span", "", formatMilliseconds(finding.waterfall_ms || span) + " ms"));
    waterfall.appendChild(axis);

    groups.forEach(function (group, groupIndex) {
      var row = element("div", "n1v-waterfall-row");
      var label = element("div", "n1v-waterfall-label");
      label.appendChild(element("strong", "", "Pattern " + (groupIndex + 1)));
      label.appendChild(element("small", "", (group.tables || []).join(", ") || "Repeated query"));
      row.appendChild(label);

      var track = element("div", "n1v-waterfall-track");
      waterfallEntriesFor(group).forEach(function (query, queryIndex) {
        var offset = Math.max(Number(query.offset_ms) || 0, 0);
        var duration = Math.max(Number(query.duration_ms) || 0, 0);
        var startPercent = Math.min(offset / span * 100, 100);
        var widthPercent = Math.min(duration / span * 100, 100 - startPercent);
        var edgeClass = startPercent < 20 ? " n1v-waterfall-bar-start" :
          (startPercent > 80 ? " n1v-waterfall-bar-end" : "");
        var bar = element("span", "n1v-waterfall-bar" + edgeClass);
        var queryNumber = query.index || queryIndex + 1;
        bar.style.setProperty("--n1v-waterfall-start", startPercent.toFixed(4) + "%");
        bar.style.setProperty("--n1v-waterfall-width", widthPercent.toFixed(4) + "%");
        bar.tabIndex = 0;

        var tooltip = element("span", "n1v-waterfall-tooltip");
        var tooltipId = "n1v-waterfall-tooltip-" + groupIndex + "-" + queryIndex;
        tooltip.id = tooltipId;
        tooltip.setAttribute("role", "tooltip");
        tooltip.appendChild(element("strong", "", "Query " + queryNumber));
        tooltip.appendChild(element("span", "", formatMilliseconds(duration) + " ms"));
        tooltip.appendChild(element("small", "", "Started +" + formatMilliseconds(offset) + " ms"));
        bar.setAttribute("aria-describedby", tooltipId);
        bar.appendChild(tooltip);
        track.appendChild(bar);
      });
      row.appendChild(track);
      row.appendChild(element("span", "n1v-waterfall-total", group.total_ms + " ms"));
      waterfall.appendChild(row);
    });

    section.appendChild(waterfall);
    container.appendChild(section);
  }

  function renderTreeNode(entry) {
    var item = element("li", "n1v-tree-item");
    if (entry.association) {
      item.appendChild(element(
        "span",
        "n1v-edge",
        entry.association + (entry.macro ? " (" + entry.macro + ")" : "")
      ));
    }

    var node = element("div", "n1v-node");
    node.appendChild(element("strong", "", entry.name));
    node.appendChild(element("small", "", entry.table));
    item.appendChild(node);

    if ((entry.children || []).length) {
      var children = element("ul", "n1v-tree");
      entry.children.forEach(function (child) {
        children.appendChild(renderTreeNode(child));
      });
      item.appendChild(children);
    }
    return item;
  }

  function renderGraph(container, finding) {
    var section = element("section", "n1v-section");
    section.appendChild(element("h3", "n1v-heading", "Affected model tree"));
    var graph = element("div", "n1v-graph");
    graph.setAttribute("role", "img");
    graph.setAttribute("aria-label", "Tree of models and associations involved in the repeated queries");
    var tree = element("ul", "n1v-tree");
    var roots = finding.tree || (finding.models || []).map(function (model) {
      return { name: model.name, table: model.table, children: [] };
    });
    roots.forEach(function (entry) {
      tree.appendChild(renderTreeNode(entry));
    });
    graph.appendChild(tree);
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
        if (!navigator.clipboard) return;
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
        var groupCount = queryGroupsFor(finding).length;
        var tab = element(
          "button",
          "n1v-tab",
          "#" + (tabIndex + 1) + " · " + groupCount + " pattern" + (groupCount === 1 ? "" : "s")
        );
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
    renderWaterfall(body, finding);
    renderGraph(body, finding);
    renderQueries(body, finding);
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

  renderFinding(initialFindingIndex);
  root.appendChild(panel);
  root.appendChild(launcher);
}());
