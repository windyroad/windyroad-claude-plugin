---
"@windyroad/itil": patch
---

`manage-problem` SKILL.md gains a new Step 0a (Auto-migrate adopter layout) that fires before Step 0 README reconciliation preflight. Sources `packages/itil/lib/migrate-problems-layout.sh` (shipped in T7) and calls `migrate_problems_to_per_state_layout` to auto-migrate flat-layout `docs/problems/<NNN>-<slug>.<state>.md` trees into per-state subdirectories on first invocation post-update. Idempotent + partial-migration-safe; emits standalone commit with `RISK_BYPASS: adr-031-migration` trailer. Fires unconditionally per ADR-013 Rule 6 + ADR-019 precedent. Routine refinements applied this release: single stderr first-fire signal (`migrate-problems-layout: relocated N tickets to per-state subdirs (ADR-031)`) so AFK orchestrator output records the action; commit body cites `docs/decisions/031-problem-ticket-directory-layout.accepted.md` so future `git log` readers have semantic context independent of the trailer.
