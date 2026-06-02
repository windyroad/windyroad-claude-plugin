# Problem 292: Reconcile ADR-018 release-cadence text with P250 (lean / release-sooner; appetite is a ceiling, not a trigger) + add the dogfood-location-before-public clause

**Status**: Closed
**Reported**: 2026-05-25
**Closed**: 2026-05-31
**Priority**: 6 (Medium) — Impact: 2 (Minor — the implementation already follows the lean principle via P250's amendment to work-problems Step 6.5, so behaviour is correct; the defect is that ADR-018's *recorded decision* still says "release when risk approaches appetite", which misleads every reader of the release-cadence decision and contradicts the live behaviour) × Likelihood: 3 (Likely — ADR-018 is the cited parent for all release-cadence behaviour; the stale text is read on every cadence question)
**Effort**: M — ADR-018 Decision-Outcome amendment + add the dogfood-location clause + verify consistency with P250 + ADR-061 (held-changeset graduation) + the work-problems Step 6.5 implementation
**WSJF**: 6/2 = **3.0** (Open multiplier 1.0)

## Closed as no longer relevant

**Closure date**: 2026-05-31 (foreground relevance-scan batch 5, user-confirmed)
**Closure reason**: implementation-shipped — the reconciliation this ticket asks for was done; ADR-018 body and the work-problems Step 6.5 SKILL both carry the P250 amendment text verbatim.
**Evidence (per ADR-026 grounding + ADR-079 evidence-based relevance-close pass)**:
- `docs/decisions/018-release-cadence-afk-loops.proposed.md` carries the literal heading: *"Amendment 2026-05-18 — Drain trigger is releasable material, not residual band (P250)"* (verified `grep`)
- The amendment body quotes the user direction verbatim: *"You don't want to accumulate risk. If it's low risk, you should release."*
- `packages/itil/skills/work-problems/SKILL.md` Step 6.5 carries the matching SKILL prose: *"The release-action threshold is 'is there something to release?', NOT 'has accumulated risk reached the safety band?'"* + *"Per user direction 2026-05-17 (P250 Description): 'If it's low risk, you should release.'"*
- The non-interactive decision-making table in work-problems SKILL is amended to match (verified `grep` shows the rows referencing 'releasable material' / 'no drain' fast-paths)
- P292's premise that *"ADR-018's recorded decision still says 'release when risk approaches appetite'"* is no longer true — the recorded decision was amended

**Relevance evidence shape**: implementation-shipped (the recorded-decision text was amended directly + the matching SKILL prose was amended in the same direction; the dogfood-location-before-public clause within scope is also carried in ADR-061's held-changeset graduation contract)
**Authorising decision**: P346 user direction 2026-05-31; user confirmed P292 in foreground relevance-scan batch 5.

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-018 (Inter-iteration release cadence for AFK loops) was presented for human-oversight confirmation, the user confirmed the **risk-driven** direction but amended the **trigger** semantics:

> User direction 2026-05-25 (drain): *"Risk based is right, but it shouldn't wait to reach a risk threshold. It should seek to be lean, minimise WIP and release sooner rather than later. I don't mind if we release to a dog-fooding location (e.g. repo local skill) before we release publicly (that's a good safety mechanism), but we shouldn't be waiting till the threshold is reached."*

Two corrections to ADR-018's recorded Decision Outcome:

1. **Appetite is a CEILING, not a TRIGGER.** ADR-018 currently reads as "release when pipeline risk approaches/reaches the appetite." The correct model: release **as soon as there is releasable material within appetite** — lean, minimise WIP, sooner rather than later. The appetite bounds what you may release (never *above* it), but you do NOT wait for risk to climb toward it before releasing. This is exactly the principle **P250** already established and implemented (work-problems Step 6.5 was amended per P250: *"trigger is presence of releasable material, NOT residual band reaching appetite"*; user 2026-05-17 *"If it's low risk, you should release."*). ADR-018's text is stale relative to P250.

2. **Dogfood-location-before-public is an endorsed safety mechanism.** Releasing to a dogfooding location (e.g. a repo-local skill / the held-changeset in-repo dogfood window) before a public npm release is explicitly good — a staged release path. This should be named in ADR-018 (it intersects ADR-061 held-changeset graduation + the repo-local-skill pattern per ADR-030).

ADR-018 is **left unoversighted** (P283/ADR-066 marker withheld) until this reconciliation lands and the amended decision is re-confirmed — mirroring P287/P289/P290/P291's status-axis sibling.

## Symptoms

(deferred to investigation)

- ADR-018 Decision Outcome ("risk-driven cadence") reads as wait-for-appetite; the live implementation (work-problems Step 6.5, P250-amended) releases on presence-of-releasable-material. Decision record and behaviour diverge.
- No mention in ADR-018 of the dogfood-location-before-public staged-release safety mechanism (which the project actively uses via held changesets per ADR-061 + repo-local skills per ADR-030).

## Workaround

The implementation is already correct (P250); only the ADR text misleads. Read P250 + work-problems Step 6.5 for the actual cadence.

## Root Cause Analysis

### Investigation Tasks

- [ ] Amend ADR-018 Decision Outcome: appetite = ceiling not trigger; release as soon as there is releasable material within appetite (lean / minimise-WIP / sooner-not-later); cite P250 as the establishing amendment.
- [ ] Add the dogfood-location-before-public clause: staged release (repo-local skill / held-changeset in-repo dogfood per ADR-061 + ADR-030) before public npm release is an endorsed safety mechanism; name how it composes with the within-appetite release trigger.
- [ ] Verify consistency with P250, ADR-061 (held-changeset graduation), ADR-030 (repo-local skills), and the work-problems Step 6.5 implementation — the amend should match the live behaviour, not introduce new divergence.
- [ ] Re-confirm amended ADR-018 via `/wr-architect:review-decisions` → write `human-oversight: confirmed`.

## Dependencies

- **Blocks**: ADR-018 human-oversight confirmation (held until reconciled).
- **Blocked by**: none.
- **Composes with**: P250 (the establishing release-sooner amendment — already implemented), ADR-061 (held-changeset dogfood graduation = the dogfood-location mechanism), ADR-030 (repo-local skills = another dogfood location), work-problems Step 6.5 (the live implementation), P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain)

- **P250** — established "release when low-risk / presence-of-releasable-material, not wait for the band"; amended work-problems Step 6.5. ADR-018 text needs to catch up.
- **P287 / P289 / P290 / P291** — sibling drain-surfaced reworks (same "drain found an artifact needing change → withhold marker + capture rework" pattern).
- **ADR-018** (`docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md`) — amendment target.
- **ADR-061** (held-changeset graduation) + **ADR-030** (repo-local skills) — the dogfood-location safety mechanisms to name.
