# Problem 318: Architect review (file edits + plans) does not flag changes built on an UNRATIFIED ADR — the build-upon guard only fires at the ITIL propose-fix surface

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

ADR-074 / RFC-008 wired the `wr-architect-is-decision-unconfirmed` predicate into the **ITIL propose-fix surface** (`/wr-itil:manage-problem` + `/wr-itil:work-problems`) so a *fix* that builds on an unratified decision is caught. But the **architect agent itself** — which reviews every project file edit (via the PreToolUse architect gate) and plans (via `/wr-architect:review-design`) — has **no awareness of the oversight marker**. `agent.md` references ADR-074 only for the *new-decision* Needs-Direction case (naming substance when a decision is being recorded); it does NOT flag "this change builds on ADR-NNN, which lacks `human-oversight: confirmed`."

Verified 2026-05-27: `grep human-oversight|is-decision-unconfirmed|oversight packages/architect/agents/agent.md` → only the ADR-074 Needs-Direction line; `review-design/SKILL.md` → none. The predicate is wired only into the two ITIL skills.

**Consequence**: foreground work NOT routed through `manage-problem` (e.g. an ad-hoc edit or a plan that implements/cites a freshly-recorded-but-unratified ADR) is not caught at the architect-review surface — the residual P315 gap. The architect-review/plan-review surface is the broadest, always-on gate (fires on every project file edit + every plan), so it is the right place to close it.

### User correction (2026-05-27) — ratified, not proposed, is the axis

User (verbatim): *"There is a difference between a proposed ADR and an unratified ADR. The stuff built on proposed and ratified ADRs is fine, it's the ones built on unratified ADRs that's the issue."*

This corrects an over-broad framing (worry about "over-firing on the dozens of proposed ADRs"). `status:` (proposed/accepted) and `human-oversight:` (ratified) are **orthogonal axes** (ADR-066's core design). The trigger is **marker absence**, NOT `proposed` status:
- Build-on a **ratified** ADR (even `status: proposed`) → fine, do NOT flag.
- Build-on an **unratified** ADR (lacks `human-oversight: confirmed`, not superseded) → flag.

**No over-firing concern**: 2026-05-27 census = 65 live ADRs, **61 ratified, 4 unratified** (ADR-034/047/055/063 — the rejected-pending-supersede set). Born-confirmed (`create-adr`) + the `/wr-architect:review-decisions` drain keep the unratified set near zero, so the check fires on ~nothing in steady state. The `wr-architect-is-decision-unconfirmed` predicate already keys on exactly this (marker absence + not-superseded, status-agnostic) — verified by `is-decision-unconfirmed.bats` test "accepted ADR without the marker is still unconfirmed".

## Symptoms

- The architect gate reviews a file edit / `review-design` reviews a plan that implements or cites an unratified ADR; verdict is PASS (or flags only conflicts/undocumented-decisions) — never "this builds on unratified ADR-NNN; ratify its substance first."

## Workaround

Route decision-dependent work through `/wr-itil:manage-problem` (the propose-fix guard fires there); or rely on the ADR-074 recording-time Needs-Direction gate + the contract. Both leave the ad-hoc-foreground-edit path uncovered.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Wire `wr-architect-is-decision-unconfirmed` into the architect agent's review + `/wr-architect:review-design`: identify the ADR(s) a change/plan **builds on** (explicit `ADR-NNN` citations in the diff/plan + the ADR being implemented), run the predicate, and emit **ISSUES FOUND** (action: "ratify ADR-NNN via /wr-architect:review-decisions before this lands") for any that are unratified. Status-agnostic — key on the marker, never on `proposed`.
- [ ] Bound detection to "explicitly cites / directly implements" the ADR (not transitive dependence) — though the near-zero unratified set means noise is low regardless.
- [ ] Decide verdict shape (ISSUES FOUND vs a Needs-Direction variant) — likely framework-resolved (ISSUES FOUND + ratify-first action fits the existing taxonomy).

## Dependencies

- **Composes with**: ADR-074 (the build-upon contract — this extends enforcement surface 1 from new-decision-recording to build-on-existing-unratified), ADR-066 (the oversight marker + orthogonal-axis design + the predicate's definition of "unconfirmed"), ADR-064 (architect verdict types), RFC-008 (the predicate + propose-fix guard this generalises).
- **Closes**: the residual P315 foreground-work gap (decisions built on outside the manage-problem propose-fix surface).

## Related

- **P315** — parent (substance-confirm-before-build); this is its uncovered foreground surface.
- **RFC-008** — built the predicate + the propose-fix guard; this generalises the guard to the architect-review surface.
- **P316** — the 4 unratified ADRs (rejected-pending-supersede) are the only current would-fire set; once superseded the unratified set is born-confirmed-only.
- captured via /wr-itil:capture-problem + P078 capture-on-correction (the proposed-vs-unratified clarification), 2026-05-27.
