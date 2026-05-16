---
"@windyroad/itil": patch
---

P087 Phase 2d — wr-itil-skill-invocations transcript-axis performance optimization

Add a substring pre-filter on the `"tool_use"` discriminating token before `json.loads()` in `packages/itil/scripts/skill-invocations.sh`. Approximately 60% of in-window transcript lines (user messages, tool_result blocks, snapshots, title records) carry no `"tool_use"` value at all and now short-circuit without paying the JSON parse cost.

Warm-cache median against a 5155 jsonl / 1.13 GB / 380,898-line corpus: **7.12s → 5.34s** (1.78s reduction, 25%). The 5s ADR-058 §Reassessment Triggers threshold remains marginally exceeded (0.34s / 6.8%); Phase 2e binary-search-to-first-in-window queued within P087 to close the residual gap.

NDJSON output schema unchanged (`schema_version` stays 1.0). Privacy posture unchanged. ADR-013 Rule 6 exit-0-always preserved. Substring filter is whitespace-tolerant — works against both compact and pretty-printed JSONL. False-positive fall-through invariant pinned by new bats fixture; 14 tests now green.

ADR-058 §Performance contract amended with the Decision Outcome — Phase 2d block per ADR-023 template.
