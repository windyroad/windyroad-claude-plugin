# Problem 295: ADR-043 deep layer (`analyze-context`) needs an automatic cadence — on-demand-only means it never runs

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 2 (Minor — the deep context analysis exists but, being on-demand-only, effectively never fires; the cheap layer carries all the load and the deep insights are never realised; no breakage, just an un-exercised capability) × Likelihood: 3 (Likely — every retro runs the cheap layer; the deep layer's zero-cadence means zero runs)
**Effort**: M — ADR-043 amendment (add a proactive lower-frequency cadence to the deep layer) + run-retro trigger wiring + the analyze-context skill
**WSJF**: 6/2 = **3.0** (Open multiplier 1.0)

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-043 (Progressive context-usage measurement for retro sessions) was presented for human-oversight confirmation, the user amended it:

> User direction 2026-05-25 (drain): *"the second layer should happen proactively as well with less frequency than the first layer. Generally speaking, if there is no automatic cadence, it does not happen."*

ADR-043 ships two layers: a **cheap layer** (Step 2c in `run-retro`, runs every retro) and a **deep layer** (`/wr-retrospective:analyze-context`, **user-invoked only**). The user wants the deep layer to ALSO fire **proactively at a lower cadence** than the cheap layer (e.g. every Nth retro, or periodically) — because an on-demand-only surface, in practice, never runs.

**General principle (user, 2026-05-25): "if there is no automatic cadence, it does not happen."** This is broader than ADR-043 — it is the same root cause behind P291 (ADRs never reach `accepted` because no acceptance cadence fires) and is why the P283/P288 oversight drains needed a session-start nudge rather than relying on the user to remember the drain skill. On-demand-only governance/maintenance surfaces get forgotten; they need an automatic cadence (even a low-frequency one) to actually happen. See memory `feedback_automatic_cadence_or_it_doesnt_happen`.

ADR-043 is **left unoversighted** (P283/ADR-066 marker withheld) until this amendment lands and the amended decision is re-confirmed.

## Symptoms

(deferred to investigation)

- `/wr-retrospective:analyze-context` (the deep layer) has no automatic trigger — it fires only when the user explicitly invokes it, which means in practice it rarely/never runs.
- The cheap Step 2c layer runs every retro, so all context-measurement load falls on it; the deep layer's richer analysis (per-turn attribution, per-plugin decomposition, suggestion generation) is never realised.

## Root Cause Analysis

### Investigation Tasks

- [ ] Amend ADR-043: add a proactive, lower-frequency automatic cadence to the deep layer (e.g. run-retro triggers `analyze-context` every Nth retro, or on a date/usage threshold). Define N / the trigger condition. Keep on-demand invocation too.
- [ ] Wire the trigger in `run-retro` (the cheap layer already runs there; it's the natural place to fire the deep layer every Nth pass) without re-introducing the per-retro cost the two-layer split avoided.
- [ ] Reconcile with the general cadence principle — consider whether other on-demand-only governance surfaces (the oversight drains' deep passes, maturity assessment per ADR-053, etc.) need the same automatic-cadence treatment (separate tickets if so).
- [ ] Re-confirm amended ADR-043 via `/wr-architect:review-decisions`.

## Dependencies

- **Blocks**: ADR-043 human-oversight confirmation (held until amended).
- **Blocked by**: none.
- **Composes with**: P291 (same root cause — no cadence means the action doesn't happen; ADRs never accepted), ADR-040 (session-start cadence precedent), the run-retro cadence, P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain)

- **P287 / P289 / P290 / P291 / P292 / P293 / P294** — sibling drain-surfaced reworks.
- **P291** — same "no automatic cadence" root cause (ADRs stuck in proposed because no acceptance cadence fires).
- **ADR-043** (`docs/decisions/043-progressive-context-usage-measurement.proposed.md`) — amendment target.
- memory `feedback_automatic_cadence_or_it_doesnt_happen` — the generalised principle.
