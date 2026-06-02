# Problem 304: Move `packages/shared/` from duplicate-and-sync to a bundler-based shared-code approach (ADR-017 reassessment outcome)

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; likely L/XL — touches every plugin's build + sync + CI)

## Description

Surfaced by the P283 prong-2 human-oversight drain (2026-05-26). When ADR-017 (cross-package shared-code sync convention) was presented for oversight confirmation, its own **reassessment trigger** — "revisit the shared-code storage approach when shared-module volume grows >5 modules" — was found **objectively met**: ~8 canonical shared helpers now live under `packages/shared/` (install-utils, derive-first-dispatch, session-marker, leak-detect, command-detect, external-comms-key, external-comms-gate, migrate-problems-layout).

**User decision 2026-05-26 (oversight drain)**: *move to a bundler-based shared-code approach* — replace the current duplicate-and-sync model (each plugin gets a synced copy of each shared helper + a `check:<name>` CI drift gate) with a bundler / single-source mechanism, while preserving the adopter-installs-a-self-contained-plugin guarantee.

The current duplicate-and-sync overhead: every shared helper is copied into each consuming package, kept in lockstep by a per-helper `sync-<name>.sh` script + a `npm run check:<name>` CI drift gate. At ~8 helpers × N consuming packages this is significant storage + cognitive + CI overhead, and is the zone ADR-017 flagged for bundler-vs-duplicate review.

## Symptoms

(deferred to investigation)

- N synced copies of each shared helper across consuming packages; drift risk managed only by CI gates.
- Per-helper sync script + CI step proliferation.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Design the bundler approach (likely an RFC per ADR-060): single-source shared helpers + a build/bundle step that produces the self-contained per-plugin artefact at publish time, replacing the sync-script + CI-drift-gate machinery. MUST preserve the adopter-installs-a-single-self-contained-plugin guarantee (no runtime cross-plugin dependency).
- [ ] Reconcile with ADR-017 — amend or supersede it once the bundler design lands (record the reassessment outcome + the new convention).
- [ ] Subsume P026 (install-utils.mjs duplicated across all packages) — that is a specific instance of this duplicate-and-sync overhead; the bundler approach closes it.

## Dependencies

- **Blocks**: (none — current duplicate-and-sync works; this is overhead-reduction)
- **Blocked by**: (none)
- **Composes with**: ADR-017 (cross-package sync convention — the decision this reassesses), P279 (ADR-017 housekeeping that surfaced the two coexisting conventions), P026 (install-utils duplication — a specific instance subsumed by the bundler approach), P283/ADR-066 (the oversight drain that surfaced this).

## Related

(captured 2026-05-26 during the P283/ADR-066 oversight drain — user-directed "move to a bundler approach")

- ADR-017 — cross-package shared-code sync convention; its >5-module reassessment trigger fired.
- P279 — ADR-017 § Consequences housekeeping (the two coexisting clustering conventions).
- P026 — install-utils.mjs duplicated across all packages (subsumed instance).
