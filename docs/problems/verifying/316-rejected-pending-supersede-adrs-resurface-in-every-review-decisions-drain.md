# Problem 316: Rejected-pending-supersede ADRs re-surface in every review-decisions drain — no "rejected" state to suppress them

**Status**: Verifying
**Reported**: 2026-05-26
**Priority**: 6 (Medium) — Impact: 2 x Likelihood: 3 (re-rated unchanged 2026-05-30 at fix landing)
**Effort**: S → M at implementation (architect adjustments expanded scope to mirror onto JTBD sibling, is-*-unconfirmed predicates, agent.md docs, and compendium renderer per the canonical-shape sync guard)
**Type**: technical

## Description

`/wr-architect:review-decisions` (the ADR-066 oversight drain) surfaces every ADR lacking a `human-oversight: confirmed` marker. An ADR that the user **rejects** (or defers) writes **no marker** — so it re-surfaces in **every subsequent drain** until it is actually superseded (status `superseded`, which the detector excludes). For **rejected-pending-supersede** ADRs this is cry-wolf: the user already decided "reject + supersede via P<NNN>", but the drain keeps re-asking because the disposition isn't recorded in a way the detector honours.

Concrete instance (2026-05-26): the drain re-surfaced ADR-034 / ADR-047 / ADR-055 / ADR-063 — all already rejected-pending-supersede at the prior P283 drain (tracked by P297/P298/P299/P300). The user had to re-disposition all four again this session. They will re-surface AGAIN next drain (and every drain) until P297–P300 land the supersede ADRs and flip the originals to `superseded`. Real rejections hide among the re-asks, and the user is trained to expect noise from the drain.

## Symptoms

- `wr-architect-detect-unoversighted docs/decisions` lists ADRs the user already rejected at a prior drain.
- The same set re-appears every drain; the only thing that removes them is the eventual supersede (status flip to `superseded`).
- No frontmatter state records "rejected, supersede tracked by P<NNN>" — so the detector cannot distinguish "not yet reviewed" from "reviewed + rejected + supersede pending."

## Workaround

Re-disposition the same ADRs at each drain (reject again), carrying the tracked supersede-ticket context in the surfacing prose. Tedious; relies on the operator remembering the prior disposition.

## Impact Assessment

- **Who is affected**: anyone running `/wr-architect:review-decisions` after a prior drain left rejections un-superseded.
- **Frequency**: Likely — fires every drain until the supersede ADRs land.
- **Severity**: Minor — cry-wolf, not data loss; but erodes trust in the drain + costs re-disposition effort each time.

## Root Cause Analysis

The `human-oversight:` marker vocabulary in ADR-066 had two states: `confirmed` (drain excludes) and absent (drain surfaces). A Reject outcome at the drain wrote nothing, leaving the rejected ADR indistinguishable from "never reviewed" — hence cry-wolf every drain until the supersede ADR eventually landed and flipped the file to `*.superseded.md` (the only other exclusion the detector honoured).

The fix adds a **third value** on the same axis: `rejected-pending-supersede`. Combined with a companion scalar `supersede-ticket: P<NNN>`, this records "user reviewed + rejected + supersede tracked" in a machine-readable form the detector and the build-upon predicate both honour. The marker without the ticket is malformed and still surfaces (defensive — preserves JTBD-201/202 audit-trail).

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — done at fix landing (Impact 2 × Likelihood 3, Effort S → M).
- [x] Design the `rejected-pending-supersede` + `supersede-ticket: P<NNN>` frontmatter state and the detector exclusion — compose with ADR-066 (additive scalar per existing Reassessment carve-out, no migration required) and ADR-009 (write-once-permanent for the new value too).
- [x] Update the drain skill to write the state on a Reject outcome — `/wr-architect:review-decisions` (and the JTBD sibling `/wr-jtbd:confirm-jobs-and-personas`) Step 4 Reject branch now captures the supersede ticket via `AskUserQuestion` and writes the marker.

## Dependencies

- **Composes with**: ADR-066 (human-oversight marker + detector + drain — the mechanism this extends), ADR-009 (never-re-ask principle — now honoured for the rejected-pending-supersede value too), P283 (the drain's origin).
- **Concrete instances**: ADR-034/P299, ADR-047/P297, ADR-055/P298, ADR-063/P300 (the four backfilled at the fix landing — verified excluded from the detector after the backfill).

## Fix Strategy

**Kind**: improve — **Shape**: ADR amendment + script extension + agent/SKILL doc updates. Landed 2026-05-30 as a Reassessment-driven additive-scalar extension of ADR-066 (per its existing Reassessment carve-out — no new ADR required).

## Fix Released

Landed 2026-05-30 (orchestrator iter 4 of `/wr-itil:work-problems`). Changes:

- **Detector** (`packages/architect/scripts/detect-unoversighted.sh`): new exclusion branch for `human-oversight: rejected-pending-supersede` + `supersede-ticket: P<NNN>`. Marker-only (without ticket) still surfaces (defensive).
- **Build-upon predicate** (`packages/architect/scripts/is-decision-unconfirmed.sh`): mirror exclusion — exit 1 on the marker+ticket pair (ratified-equivalent) so the `[Unratified Dependency]` flag no longer re-fires on rejected ADRs with tracked supersedes. Sync-guard bats verify the two scripts agree on the new branch.
- **JTBD sibling** (`packages/jtbd/scripts/detect-unoversighted.sh` + `is-job-or-persona-unconfirmed.sh`): symmetric mirror — same marker grammar applies to personas/jobs the user rejects with a tracked supersede ticket.
- **Drain SKILLs** (`packages/architect/skills/review-decisions/SKILL.md` + `packages/jtbd/skills/confirm-jobs-and-personas/SKILL.md`): Reject branch now captures the supersede ticket via a follow-up `AskUserQuestion` and writes the marker+ticket pair into frontmatter. Defer-without-ticket leaves the marker absent (re-surfaces next drain).
- **Agent docs** (`packages/architect/agents/agent.md` + `packages/jtbd/agents/agent.md`): the `[Unratified Dependency]` read-only-equivalent description now lists the rejected-pending-supersede exclusion alongside the superseded skip.
- **Compendium renderer** (`packages/architect/scripts/generate-decisions-compendium.sh`): `**Oversight:**` badge now renders `rejected-pending-supersede (P<NNN>)` so the compendium surfaces the disposition without a per-ADR body read.
- **ADR-066 amendment**: documents the third oversight value, the defensive un-tracked-marker rule, and the supersede-lands transition (the existing `*.superseded.md` skip takes over; rejected-pending-supersede lines become historical residue with no active clearance required).
- **Backfill**: ADR-034 (→ P299), ADR-047 (→ P297), ADR-055 (→ P298), ADR-063 (→ P300) all carry `human-oversight: rejected-pending-supersede` + `supersede-ticket: P<NNN>`. Detector verified to exclude all four after the backfill.
- **Bats coverage**: 8 new behavioural tests across the 4 scripts (3 architect detect + 3 architect predicate + 3 JTBD detect + 3 JTBD predicate, including a defensive un-tracked-marker case and a sync-guard for each predicate ↔ detector pair).

Released 2026-05-30 in `@windyroad/architect@0.12.0` + `@windyroad/jtbd@0.9.0` (multi-package release — the ADR-066 amendment + detector + predicate landed in `architect`; the symmetric JTBD-sibling extension landed in `jtbd`). Citation derived deterministically via `wr-itil-derive-release-vehicle P316` (second real-world dogfood after P267):

```
RELEASE_VEHICLE:
  changeset: .changeset/p316-rejected-pending-supersede-marker.md
  version-packages-commit: 338a0517f44afcc74b2e549596e6835d5a96796d
  pr: #175
  merge-commit: 241db7f654f34a918ca9b724ac7af95ca195a904
  release-date: 2026-05-30
```

- Source commit: `aef160c` "feat(architect,jtbd): add rejected-pending-supersede marker value (closes P316)" (2026-05-30 orchestrator iter-4 of `/wr-itil:work-problems`).
- Version-packages commit: `338a0517` (changeset removal per ADR-022 P143 fold-fix).
- Merge PR: #175 `windyroad/changeset-release/main`.
- Merge commit: `241db7f` (2026-05-30).
- Plugin caches refreshed in iter-5 chained `/install-updates`; `rejected-pending-supersede` keyword verified present in both cache 0.12.0 + 0.9.0.

Awaiting user verification: next `/wr-architect:review-decisions` drain SHOULD exclude ADR-034 / ADR-047 / ADR-055 / ADR-063 (all backfilled with `human-oversight: rejected-pending-supersede` + `supersede-ticket: P<NNN>`). Cry-wolf re-surface class is eliminated for the four backfilled instances and for any future Reject outcomes (drain SKILL now captures the supersede ticket via follow-up `AskUserQuestion` and writes the marker+ticket pair).

## Related

(captured via /wr-retrospective:run-retro Step 2b pipeline-instability scan, 2026-05-26 — the second retro this session, covering the review-decisions drain + P314 rework. Closed in iter 4 of /wr-itil:work-problems 2026-05-30.)
