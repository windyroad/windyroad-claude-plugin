---
"@windyroad/retrospective": patch
---

`measure-context-budget.sh` now counts problem tickets in the per-state subdirectory layout, not just the flat layout. The problems bucket previously enumerated only `docs/problems/*.md` (a flat-layout glob), which missed the per-state subdirs (`docs/problems/{open,known-error,verifying,closed,parked}/*.md`) introduced by the RFC-002 T5 / ADR-031 migration. The result was an undercount of roughly 99% and a phantom drop in the problems-bucket figure of `/wr-retrospective:run-retro` Step 2c and `/wr-retrospective:analyze-context` deep-layer reports. The bucket now walks both layouts and deduplicates on ticket ID — the per-state subdirectory copy wins on collision per ADR-031 — mirroring the proven dual-tolerant pattern in `reconcile-readme.sh`. README files and any pre-migration flat tickets are still counted. Fixes P182.
