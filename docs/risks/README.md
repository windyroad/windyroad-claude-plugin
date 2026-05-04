# Risk Catalogue

Memory aid for the risk-scorer agent: known risk classes + their typical controls. Reading the catalogue at scoring time saves re-deriving them and reduces the chance of forgetting a class previously surfaced.

Each entry is minimal: a description of the class and the controls observed against it. No typical-residual ranges (residuals are computed per-action from which controls fire). No corpus citations (a newly-identified class won't have any).

## Entries

- [R001](R001-confidential-disclosure-in-outbound-prose.md) — Confidential / business-metric disclosure in outbound prose
- [R002](R002-documentation-and-index-drift.md) — Documentation / index / cross-reference drift across docs
- [R003](R003-hook-regression-shipped-to-adopters.md) — Hook regression / behaviour change ships to adopters
- [R004](R004-ambient-unstaged-state-in-commits.md) — Ambient unstaged state included in commits
- [R005](R005-release-coordination-changeset-drift.md) — Release-coordination / changeset queue drift
- [R006](R006-published-package-vs-source-tree-divergence.md) — Published-package references source-tree-only paths and IDs
- [R007](R007-user-stated-preconditions-paired-capability.md) — User-stated preconditions / paired-capability check

## Adding to the catalogue

Identifying a new class during scoring? Author it via `/wr-risk-scorer:create-risk` (interactive) or `/wr-risk-scorer:create-risk --slug <slug>` (orchestrator-driven from an ADR-056 hint).

The catalogue is self-pruning: when a class stops surfacing in `.risk-reports/` (controls have made it rare), retire its entry by renaming `R<NNN>-<slug>.md` to `R<NNN>-<slug>.retired.md`. Git history preserves the prior content.
