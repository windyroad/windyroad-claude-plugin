---
"@windyroad/retrospective": patch
---

docs(retrospective): rewrite stale ADR-027 compatibility notes in run-retro/SKILL.md (P014 — ADR-032 supersession trail)

ADR-027 (Governance skill auto-delegation) was superseded by **ADR-032** (Governance skill invocation patterns) on 2026-04-21. Three "ADR-027 compatibility note" blocks in `packages/retrospective/skills/run-retro/SKILL.md` (Step 2b lines around 166, Step 2c around 212, Step 4a around 377) described a hypothetical migration to Step-0 subagent auto-delegation that no longer happens — under ADR-032's foreground-synchronous pattern, run-retro's Steps execute directly in main-agent context with no subagent boundary to cross.

This patch rewrites each of the three compat blocks to **ADR-032 supersession notes** that:

- Cite ADR-032 as the supersession reference
- Record explicitly that no Step-0 subagent migration applies
- Preserve a parenthetical "(was: ADR-027 compatibility note)" pointer for cross-reference continuity with prior commits

Bats tests at `test/run-retro-verification-close-housekeeping.bats:93-98` and `test/run-retro-pipeline-instability-scan.bats:83-86` are re-pointed at the new strings (`ADR-032 supersession note` + `No Step-0 subagent migration applies`). Both tests retain their structural-grep shape; converting to behavioural fixtures is a follow-up (P081 anti-pattern flagged in inline comments).

Part of P014's execution-tracker work for ADR-032 closure conditions. The remaining ADR-032 deliverables (capture-problem skill, capture-adr skill, pending-questions-surface hook) are split into subordinate child tickets in a sibling commit; capture-retro stays deferred per P088.
