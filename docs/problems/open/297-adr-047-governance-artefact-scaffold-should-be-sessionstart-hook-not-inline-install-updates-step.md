# Problem 297: ADR-047 — governance-artefact scaffolding should be a SessionStart hook (per-project, automatic), not an inline `/install-updates` step

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 3 (Moderate — the inline-/install-updates mechanism only scaffolds for sibling projects reachable from THIS project's /install-updates run; it completely misses adopter projects on other machines, and any project where /install-updates is never run against it; the scaffold's whole point — that an adopter with a policy file gets its artefact — silently fails for the majority of real adopters) × Likelihood: 3 (Likely — most adopter projects are not reachable from this repo's /install-updates)
**Effort**: M — move the scaffold from an inline /install-updates step to a SessionStart hook (per-plugin, fires per-project-session) + reconcile with the ADR-040 SessionStart precedent
**WSJF**: 6/2 = **3.0** (Open multiplier 1.0)
**Type**: technical

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-047 (install-updates scaffolds governance artefacts when a policy file is present but its artefact is missing) was presented for human-oversight confirmation, the user **rejected the mechanism**:

> User direction 2026-05-25 (drain): *"Inline scaffold step in `/install-updates` is the wrong choice. That happens from within this project for sibling projects. It would completely miss other projects on other machines. SessionStart hook scaffold unless you have a better option."*

ADR-047 chose "Option 1 — inline scaffold step in `/install-updates`". The defect: `/install-updates` runs **from this repo, pushing to sibling projects it knows about** — it is occasional, manual, and machine-local. It cannot reach adopter projects on other machines, and it never fires for projects that don't get `/install-updates` run against them. So the scaffold (policy-file-present-but-artefact-missing → scaffold the artefact) silently fails for the majority of real adopters.

The right mechanism is a **SessionStart hook** (per the cadence principle — memory `feedback_automatic_cadence_or_it_doesnt_happen`): it fires automatically in **every project on every machine** at session start, so any adopter with a policy file but a missing artefact gets it scaffolded locally. (Considered: no better option was identified — SessionStart is the natural per-project automatic trigger, matching ADR-040 / the ADR-066/068 oversight nudges. PreToolUse/edit-gate is edit-triggered, wrong shape; the inline /install-updates step is the rejected one.)

ADR-047 is **left unoversighted** (P283/ADR-066 marker withheld) until amended (mechanism → SessionStart hook) and re-confirmed.

## Symptoms

(deferred to investigation)

- ADR-047's scaffold only fires inside this repo's `/install-updates` run for enumerated sibling projects; adopters on other machines / unreached projects never get the scaffold.
- The scaffold's value (auto-create docs/risks/ when RISK-POLICY.md exists, etc.) is per-adopter-project, but the trigger is centralised-and-manual — a mechanism/intent mismatch.

## Root Cause Analysis

### Investigation Tasks

- [ ] Amend ADR-047: change the mechanism from "inline /install-updates step" to a **SessionStart hook** (the relevant plugin's hooks.json gains a SessionStart `startup` entry; the hook checks policy-file-present-but-artefact-missing and scaffolds). Confirm the owning plugin (risk-scorer for RISK-POLICY→docs/risks; itil for intake; etc.) or a shared mechanism.
- [ ] Reconcile with ADR-040 (SessionStart surface precedent) + the ADR-066/068 SessionStart nudges (same event; ensure they compose, not collide) + ADR-045 (hook budget — scaffold is a side-effect-only-silent hook).
- [ ] Decide the scaffold's interactivity: silent auto-scaffold vs nudge-then-scaffold-on-confirm (consider the human-oversight principle — auto-scaffolding a governance artefact may itself warrant a confirm, per [[feedback_lift_auto_decisions_to_human]]).
- [ ] Keep an /install-updates path too if useful for the sibling-push case, but the SessionStart hook is the load-bearing per-project trigger.
- [ ] Re-confirm amended ADR-047 via `/wr-architect:review-decisions`.

## Dependencies

- **Blocks**: ADR-047 human-oversight confirmation (held until amended).
- **Blocked by**: none.
- **Composes with**: ADR-040 (SessionStart precedent), ADR-045 (hook budget), ADR-066/068 (existing SessionStart oversight nudges — same event), memory `feedback_automatic_cadence_or_it_doesnt_happen` (the per-project-automatic-trigger principle), P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain)

- **P287 / P289 / P290 / P291 / P292 / P293 / P294 / P295 / P296** — sibling drain-surfaced reworks.
- **ADR-047** (`docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md`) — amendment target.
- **ADR-040** (SessionStart surface), **ADR-045** (hook budget), **ADR-066/068** (SessionStart oversight nudges) — the SessionStart neighbours to compose with.
