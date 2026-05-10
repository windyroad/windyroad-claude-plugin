---
"@windyroad/risk-scorer": patch
---

RFC-002 T5 (mechanical migration only): bulk `git mv` of 177 problem tickets from flat `docs/problems/<NNN>-<slug>.<state>.md` to per-state subdirectory layout `docs/problems/<state>/<NNN>-<slug>.md` per ADR-031. State encoded by directory; filename `.<state>.md` suffix dropped. `packages/risk-scorer/agents/wip.md` governance-artefact detection heuristic widened to dual-tolerant (matches both flat and per-state subdir layouts during the T1-T6 migration window). T5b — ADR-031 `proposed → accepted` transition + ADR-022/016/024 amendments referencing the dual-pattern — deferred to follow-up iter. Refs: RFC-002 T5.
