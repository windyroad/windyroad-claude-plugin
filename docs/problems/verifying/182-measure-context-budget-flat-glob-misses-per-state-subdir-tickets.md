# Problem 182: `measure-context-budget.sh` flat-glob misses per-state-subdir problem tickets — sibling fix to RFC-002 T4 dual-tolerant `reconcile-readme.sh`

**Status**: Verification Pending
**Reported**: 2026-05-11
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

The retrospective context-budget measurement primitive `packages/retrospective/scripts/measure-context-budget.sh` enumerates problem tickets via a flat-layout glob (`docs/problems/*.md` or equivalent), which **misses the per-state subdir layout** introduced by RFC-002 T5 (commit `e31bd6a`, shipped 2026-05-10 in `@windyroad/risk-scorer@0.7.1` via I002 mitigation atomic-cohort graduation).

Symptom: the deep-layer context-analysis report `docs/retros/2026-05-11-context-analysis.md` shows the **problems bucket dropped 85.6%** vs the 2026-04-29 prior snapshot (1,986,943 → 286,459 bytes). This is a **measurement artefact, not a real reduction** — the ticket bodies didn't disappear, they moved to `docs/problems/<state>/*.md` per-state subdirs that the script's glob doesn't recurse into.

This is the same script-vs-layout-mismatch shape that produced the cached-`wr-itil-reconcile-readme` shim staleness loop captured during I002 mitigation (see I002 Outstanding Design Questions and the 2026-05-11 briefing entry under `docs/briefing/releases-and-ci.md`). The reconcile-readme path was fixed by RFC-002 T4 (dual-tolerant flat + per-state-subdir enumeration); the same widening pattern applies here.

### Verbatim evidence

From `docs/retros/2026-05-11-context-analysis.md` (commit `cf8ed21`):

> "**Problems bucket — fix the measurement methodology, not the surface**. The -85.6% delta (1,986,943 → 286,459) is a measurement artefact: `packages/retrospective/scripts/measure-context-budget.sh` measures `docs/problems/*.md` with a flat-layout glob; RFC-002 T5 migrated tickets to `docs/problems/<state>/*.md` per-state subdirs (commit `e31bd6a`, shipped via I002 mitigation H3 graduation 2026-05-10 in `@windyroad/risk-scorer@0.7.1`). The script (cached version) doesn't recurse into subdirs."

Bucket totals confirming the artefact (script output 2026-05-11):

```
BUCKET problems bytes=286459
```

Total measured 2,869,907 bytes; problems bucket is 10.0% of measured. Prior 2026-04-29 measurement showed problems at 50.9% of measured (1,986,943 / 3,901,563).

### Architectural context

- **RFC-002 T4 dual-tolerant `reconcile-readme.sh`** (commit `822c794`) is the proven sibling pattern: extend the script's enumeration to walk both the flat layout (`docs/problems/*.md`) and the per-state subdirs (`docs/problems/{open,known-error,verifying,closed,parked}/*.md`), with the per-state subdir winning on collision per ADR-031 § "Authoritative state signal".
- **ADR-031** (Per-state subdir layout) — confirms subdirs as post-migration ground truth.
- **ADR-026** (Agent output grounding) — the deep-layer report flagged this as a measurement-methodology artefact rather than a real-reduction claim, per the `not estimated — no prior data` discipline. Without this fix, future deltas-vs-prior continue to be misleading.
- **ADR-043** (Progressive context-usage measurement) — defines the deep-layer report shape; this script is the cheap-layer baseline that the deep layer reuses. Both layers depend on the script's correctness.

## Symptoms

(deferred to investigation)

## Workaround

For the 2026-05-11 deep-layer report: explicit ADR-026 sentinel (`-85.6% problems-bucket delta is a methodology artefact`) called out in Bucket Totals and Suggestions §4 sections. No mechanical workaround in the cheap-layer baseline; future deltas-vs-prior remain misleading until the script is fixed.

## Impact Assessment

- **Who is affected**: every adopter of `@windyroad/retrospective` running `/wr-retrospective:run-retro` Step 2c cheap-layer measurement OR `/wr-retrospective:analyze-context` deep-layer report whose project has applied the RFC-002 T5 per-state subdir migration. Window opens 2026-05-10 (T5 release) onward.
- **Frequency**: every retro invocation (cheap layer) and every explicit deep-layer invocation produces incorrect problems-bucket measurement.
- **Severity**: (deferred to investigation) — observability degradation, not functional break. Other measurement surfaces (`hooks`, `skills`, etc.) are unaffected.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — confirmed S (single-file script fix + test); WSJF 6.0 unchanged.
- [x] Investigate root cause — `measure-context-budget.sh:188` summed `sum_globs "docs/problems/*.md"` (flat top-level only); the RFC-002 T5 / ADR-031 per-state subdirs were never recursed, so the bucket counted only the 2 README files.
- [x] Apply RFC-002 T4 dual-tolerant pattern: enumeration now walks flat (`docs/problems/*.md`) + per-state subdirs (`docs/problems/{open,known-error,verifying,closed,parked}/*.md`); dedup keyed on ticket ID (`${base%%-*}`) — NOT raw basename, because the per-state layout drops the `.<state>` suffix so the same ticket has different basenames across layouts (architect verdict on this fix); per-state subdir wins on collision (subdir loop runs after flat loop) per ADR-031. README files key on full basename so existing README-counting is preserved.
- [x] Survey sibling scripts for the same flat-glob anti-pattern — `measure-context-budget.sh` was the SOLE remaining instance. `architect-enforce-edit.sh` / `jtbd-enforce-edit.sh` already dual-tolerant (`docs/problems/*.md|docs/problems/*/*.md`); `update-jtbd-references-section.sh` uses `docs/problems/*/[0-9]*-*.md` (per-state); `evaluate-graduation.sh` already dual-tolerant; `plugin-exercise-index.sh` uses `docs/problems/**/`; `migrate-problems-layout.sh` intentionally detects flat files for migration. No further fixes needed.
- [x] Create reproduction test — `measure-context-budget.bats` gains 3 tests: (a) per-state subdir tickets counted; (b) flat README + flat ticket + 2 subdir tickets sum exactly; (c) same ticket ID in flat + per-state subdir counted once, per-state byte size wins. Red-green confirmed (3 fail pre-fix, all 34 pass post-fix).

### Findings (fix landed 2026-05-26)

Single copy of the script exists (no canonical+sync needed). Real-repo verification: the problems bucket corrected from a phantom 286,459 bytes (2 README files) to 3,797,225 bytes (305 ticket files) — post-migration ground truth restored. The architect flagged that the `decisions` bucket flat glob is CORRECT (no per-state subdirs) and must not be touched. Optional follow-up queued: amend ADR-043 line 78 (stale `docs/problems/*.md` wording) so a future reviewer doesn't "fix" the script back to the flat glob — deferred to avoid decision-file edit-gate churn in this AFK loop.

## Dependencies

- **Blocks**: meaningful delta-vs-prior comparison in subsequent `/wr-retrospective:run-retro` Step 2c invocations (until fix lands, problems-bucket deltas remain misleading).
- **Blocked by**: (none — RFC-002 T4 already shipped the proven dual-tolerant pattern)
- **Composes with**: P069 (problem-ticket layout migration ticket — RFC-002 T5 was a sibling slice), I002 (the mitigation that shipped T5 in the cohort), P162 (Phase 1b extension covers the broader cached-shim staleness loop pattern), RFC-002 (originating RFC for the dual-tolerant enumeration shape).

## Related

- **`docs/retros/2026-05-11-context-analysis.md`** (commit `cf8ed21`) — surfaced the artefact via Suggestions §4.
- **`docs/briefing/releases-and-ci.md`** (entry added 2026-05-11) — captures the cached-shim staleness loop pattern this ticket continues.
- **RFC-002 T4** (commit `822c794`) — proven sibling fix on `reconcile-readme.sh`; the dual-tolerant pattern applies verbatim.
- **ADR-031** — Per-state subdir layout (post-migration authoritative state signal).
- **ADR-043** — Progressive context-usage measurement (the deep-layer report shape this script underlies).
- **ADR-026** — Agent output grounding (the `not estimated — no prior data` sentinel discipline that surfaced this as artefact rather than real reduction).
- **P181** (`docs/problems/open/181-architect-mark-reviewed-verdict-grep-fragile-on-issues-found-substring.md`) — sibling capture this session for a different script-fragility pattern; same Stage 2 shape (improvement stub on a script).
- **P097** (`docs/problems/open/097-skill-md-files-mix-runtime-and-rationale.md`) — composes with the deep-layer report's other findings (3 SKILL.md > 50KB cluster).

## Fix Released

**Release marker**: `@windyroad/retrospective` patch — changeset `p182-measure-context-budget-per-state-subdir-walk.md` queued; commit pending this AFK iteration; npm release deferred to the orchestrator's Step 6.5 drain.
**Fix summary**: `measure-context-budget.sh`'s problems bucket now walks both the flat and per-state-subdir layouts (dual-tolerant per RFC-002 T4 / ADR-031), deduplicating on ticket ID with the per-state subdir winning on collision — correcting the ~99% under-count and phantom delta in `/wr-retrospective:run-retro` Step 2c and `/wr-retrospective:analyze-context` reports.
**Exercise evidence**: bats 34/34 green (3 new tests, red-green confirmed); real-repo problems bucket corrected 286,459 → 3,797,225 bytes.
**Awaiting user verification**: run `/wr-retrospective:run-retro` Step 2c (or `/wr-retrospective:analyze-context`) after release and confirm the problems-bucket figure reflects the full ticket inventory rather than the 2 README files.

## Fix Strategy

**Kind**: improve
**Shape**: script
**Target file**: `packages/retrospective/scripts/measure-context-budget.sh`
**Observed flaw**: flat-glob enumeration of `docs/problems/*.md` misses per-state subdir layout introduced by RFC-002 T5; produces -85.6% phantom delta in deep-layer reports.
**Edit summary**: extend enumeration to dual-tolerant flat + per-state-subdir walk per RFC-002 T4 pattern (`reconcile-readme.sh` is the canonical reference). Deduplicate on filename collision; per-state subdir wins per ADR-031.
**Routing target**: no routing skill — direct script edit + bats coverage (`packages/retrospective/scripts/test/measure-context-budget.bats`) + sync via canonical+sync if the script lives in shared. Re-run deep-layer report post-fix to confirm problems-bucket measurement reflects post-migration ground truth.
**Evidence**: 2026-05-11 deep-layer report Suggestions §4 (commit `cf8ed21`); RFC-002 T4 dual-tolerant `reconcile-readme.sh` (commit `822c794`) is the proven precedent.
