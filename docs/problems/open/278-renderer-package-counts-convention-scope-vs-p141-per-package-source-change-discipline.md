# Problem 278: renderer-package-counts-the-readme-changes convention scope vs P141 per-package source change discipline (ADR-021 boundary clarification)

**Status**: Open
**Reported**: 2026-05-19
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)

## Description

During session 8 iter 2 (P269), the single-package `@windyroad/itil` changeset initially failed P141 changeset-discipline because plugin.json modifications across 11 plugins count as per-package source changes. The precedent (P0 hotfix `3cfa6fc`) declared all 11 plugins. The "renderer-package-counts" convention only covers README content shifts, not plugin.json field modifications.

The boundary needs clarification in ADR-021 (or .changeset/ conventions document):

- **README content changes** (e.g. compound-rendering output shifts) can ride the renderer's package bump — one changeset entry under the renderer's package suffices.
- **plugin.json field additions / removals** (e.g. populate writes new `rollup_invocations_30d` field on plugin root) MUST declare per-package patches — each modified plugin gets its own changeset entry.

Without this clarification, every populate rerun repeats the changeset-iteration cycle: agent proposes single-package, P141 rejects, agent expands to multi-package.

## Symptoms

(deferred to investigation) — iter 2 (P269) cycle: 4 changeset rewrites before P141 + risk-scorer-external-comms gates both PASSed.

## Workaround

Agent learns the convention by hitting P141 and expanding manually. Repeating cost ~$0.30-0.50 per cycle (multiple re-reviews).

## Impact Assessment

- **Who is affected**: any maintainer + AFK orchestrator iter writing a multi-plugin populate-time field change.
- **Frequency**: every populate rerun on `plugin.json` shape changes.
- **Severity**: (deferred to investigation) — initial: low.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — read ADR-021 and ADR-058
- [ ] Amend ADR-021 (or write a new convention document) with the boundary clarification
- [ ] Update `.changeset/` conventions documentation if separate
- [ ] Create reproduction test

## Dependencies

- **Composes with**: P141 (changeset-discipline hook), ADR-021 (changeset conventions), ADR-058 (semver classification), the renderer-package-counts convention (currently undocumented as a formal ADR).

## Related

(captured 2026-05-19 from /wr-itil:work-problems session 8 iter 2 (P269) deviation-approval queue, user-directed via AskUserQuestion at Step 2.5)

- P141 — changeset-discipline hook
- ADR-021 — changeset conventions (amendment target)
- ADR-058 — semver classification
- 3cfa6fc — P0 hotfix that established the multi-package-declaration precedent
