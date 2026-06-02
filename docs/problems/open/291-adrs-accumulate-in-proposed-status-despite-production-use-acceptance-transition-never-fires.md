# Problem 291: ADRs accumulate in `proposed` status despite heavy production use — the acceptance transition never fires

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 2 (Minor — the `status:` axis is supposed to signal production-validation; with ~54 of ~57 ADRs stuck at `proposed` despite their implementations shipping and being used for weeks/months, the axis carries almost no signal — a reader can't tell which decisions are battle-tested vs freshly-drafted; degraded audit/handover value, no functional breakage) × Likelihood: 3 (Possible — affects nearly the entire ADR corpus and every new ADR, which is born `proposed` and never transitioned)
**Effort**: L — define the acceptance criterion + (ideally) automate/prompt the transition so ADRs stop accumulating, then reconcile the ~50 production-validated ADRs
**WSJF**: 6/4 = **1.5** (Open multiplier 1.0)

## Description

User observation 2026-05-25 (during the P283/ADR-066 oversight drain): *"a lot of these decisions (all) are in a proposed state, even though we've been using them a lot."*

The ADR `status:` axis (`proposed` / `accepted` / `superseded`) is meant to track **production-validation** — orthogonal to the `human-oversight:` marker (which tracks human-confirmation, per ADR-066). Only 3 of ~57 ADRs are `accepted` (ADR-031, 046, 060) — and those flipped manually on the production-landing of their implementations. The rest sit at `proposed` despite their implementations having shipped and been used heavily (e.g. ADR-013, 014, 044, 026, 009, 032 are cited 16–41× and their mechanisms are live in every session). There is **no acceptance step** that fires when an ADR's implementation lands + validates, so `proposed` has become a permanent parking state and the axis no longer signals anything.

**User direction 2026-05-25**: *capture it for now* — keep the in-flight oversight drain oversight-only; handle the status reconciliation as separate planned work (this ticket). Do NOT bulk-flip ADRs to `accepted` (some are correctly `proposed` — e.g. ADR-067/068 have held/incomplete builds; a blanket flip would falsely mark them production-validated).

## Symptoms

(deferred to investigation)

- ~54 of ~57 ADRs are `status: proposed`; only ADR-031/046/060 are `accepted`.
- The 3 accepted ones each transitioned manually/ad-hoc on production-landing — no repeatable mechanism drove it, so the pattern didn't scale to the rest.
- No skill / hook / process transitions `proposed → accepted`; `create-adr` writes `proposed` and nothing flips it later.
- Contrast with `human-oversight` (now detectable + drainable via ADR-066/068): the status axis has no equivalent detection/drain/criterion.

## Workaround

Read the ADR body / git history to judge whether a `proposed` ADR is actually production-validated; the `status:` field can't be trusted as that signal today.

## Root Cause Analysis

### Investigation Tasks

- [ ] Define the **acceptance criterion** precisely: what makes a `proposed` ADR `accepted`? Candidate: implementation shipped (changeset graduated from holding per ADR-061) AND in production use AND human-oversight confirmed (ADR-066). Decide via the asking flow — likely its own ADR.
- [ ] Decide whether to **automate/prompt** the transition so ADRs stop accumulating in `proposed` (e.g. a detector + nudge, mirroring the ADR-066 oversight mechanism — "N proposed ADRs look production-validated; review for acceptance"). Or a step in an existing flow (release-cadence? retro?).
- [ ] Reconcile the existing ~50 production-validated ADRs `proposed → accepted` per the criterion (a reconciliation pass; NOT a blanket flip — exclude held/incomplete ones).
- [ ] Confirm interaction with ADR-022's lifecycle / ADR-061 graduation: acceptance should compose with the held-changeset graduation evidence (an ADR whose changeset graduated on dogfood evidence is a strong acceptance signal).

## Dependencies

- **Blocks**: trustworthy `status:` signal across the ADR corpus.
- **Blocked by**: none — investigation can begin immediately.
- **Composes with**: ADR-066 (the orthogonal human-oversight axis + the marker/detector/nudge/drain pattern this could mirror), ADR-061 (held-changeset graduation = a production-validation signal), ADR-022 (lifecycle states), P283/P288 (the oversight drains that surfaced this — same "an axis isn't being driven" class).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain — user observation)

- **P283** / **ADR-066** — the oversight axis + drain; this ticket is the status-axis sibling (the OTHER orthogonal axis ADR-066 named).
- **ADR-061** — held-changeset graduation (a production-validation evidence source).
- **ADR-031 / 046 / 060** — the only 3 accepted ADRs; their manual transitions are the pattern to systematise.
