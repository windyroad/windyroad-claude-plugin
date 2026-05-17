---
"@windyroad/itil": minor
---

P087 Phase 2a — ship `wr-itil-skill-invocations` script + shim covering the transcript axis of ADR-058's plugin-maturity measurement mechanism.

Reads `~/.claude/projects/**/*.jsonl` (recursive), tallies tool_use invocations by `Skill` / `Agent` / `Bash` per ADR-058 §Script contracts, emits one NDJSON record per surface to stdout. Schema v1.0 fields: `schema_version`, `axis`, `surface`, `kind`, `plugin`, `window_days`, `invocations`, `first_invocation_iso`, `last_invocation_iso`. Exit 0 always per ADR-013 Rule 6 (opt-out marker, inaccessible root, no data all hit the zero-records/stderr-comment path).

Privacy posture adopted verbatim from ADR-035: opt-out marker `.claude/.skill-metrics-opt-out`, content sanitisation (only fixed-pattern surface names extracted), no network primitive (negative-grep enforced via bats), path-hashing (sha256-prefix-12hex; reserved for future schema bumps).

Behavioural confirmation: 13 bats fixtures covering ADR-058 §Confirmation criteria 1–5 plus existence / forward-extension flag / window-days filtering. All green.

Phase 2b (git axis — `wr-itil-plugin-exercise-index`) and Phase 2c (performance reassessment, surfaced from a 7.8s warm-cache observation against 5157 jsonl / 1.1 GB on the author's workstation, above ADR-058's 5s reassessment threshold) are queued as discrete Investigation Tasks under P087.
