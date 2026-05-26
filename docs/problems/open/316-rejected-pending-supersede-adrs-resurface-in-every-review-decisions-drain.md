# Problem 316: Rejected-pending-supersede ADRs re-surface in every review-decisions drain — no "rejected" state to suppress them

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 6 (Medium) — Impact: 2 x Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)
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

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Design a `rejected` / `supersede-pending: P<NNN>` frontmatter state (or marker) that `wr-architect-detect-unoversighted` excludes (mirroring how it excludes `superseded`), so a rejected-with-tracked-supersede ADR drops out of the drain until either the supersede lands or the rejection is revisited. Compose with ADR-066 (the marker mechanism) + ADR-009 (never-re-ask).
- [ ] Decide whether the drain skill writes this state on a Reject outcome (currently it writes nothing).

## Dependencies

- **Composes with**: ADR-066 (human-oversight marker + detector + drain — the mechanism this extends), ADR-009 (never-re-ask principle — currently only honoured for `confirmed`, not `rejected`), P283 (the drain's origin).
- **Concrete instances**: ADR-034/P299, ADR-047/P297, ADR-055/P298, ADR-063/P300 (the four that re-surfaced this session).

## Fix Strategy

**Kind**: improve — **Shape**: ADR + script. The detector (`packages/architect/scripts/detect-unoversighted.sh`) + the `review-decisions` skill gain a `rejected` / `supersede-pending` exclusion state; route the state-shape decision through `/wr-architect:create-adr` (amends ADR-066). The drain writes the state on a Reject outcome.

## Related

(captured via /wr-retrospective:run-retro Step 2b pipeline-instability scan, 2026-05-26 — the second retro this session, covering the review-decisions drain + P314 rework; expand at next investigation)
