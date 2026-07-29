# Changelog

## Unreleased

- Add per-pattern query loading waterfalls to the mounted dashboard and
  on-page inspector, including individual query offsets, durations, elapsed
  span, and cumulative database time.
- Add styled hover and keyboard-focus tooltips to every waterfall query bar.

## 0.1.0 - 2026-07-28

- Detect repeated Active Record query shapes within a request.
- Combine multiple repeated query shapes attributed to the same source line.
- Identify relevant application source files, line numbers, and code excerpts.
- Visualize multi-model associations as nested trees.
- Recommend combined eager-loading and strict-loading remediations for the
  complete association tree.
- Provide an optional on-page status indicator and findings panel.
- Provide a full mounted findings dashboard.
- Allow operators to clear stored findings from the dashboard.
- Roll off the oldest dashboard findings according to `max_events`.
- Publish canonical GitHub, documentation, changelog, and issue-tracker
  metadata.
- Support environment-neutral activation and deployment.
