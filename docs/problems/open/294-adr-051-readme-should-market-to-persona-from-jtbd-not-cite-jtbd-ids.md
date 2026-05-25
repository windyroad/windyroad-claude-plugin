# Problem 294: ADR-051 is wrong — plugin READMEs should MARKET to the persona (the problem solved for them), derived from the JTBD, NOT mechanically cite JTBD IDs

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 9 (Med High) — Impact: 3 (Moderate — the current mechanism actively fails the actual intent: every plugin README now carries mechanical JTBD-ID citations that read as internal-governance plumbing, not persona-facing marketing; a load-bearing commit hook enforces the wrong thing; degraded README value for the plugin-user/adopter who should be sold on the problem the plugin solves) × Likelihood: 3 (Likely — every plugin README + every README edit hits the ADR-051 hook)
**Effort**: L — supersede ADR-051 + unwind the JTBD-ID-citation commit hook + rewrite the plugin READMEs to market-from-JTBD + rethink (or drop) the drift-detection anchor that motivated the ID-citation
**WSJF**: 9/4 = **2.25** (Open multiplier 1.0)
**Type**: technical

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-051 (plugin READMEs anchor on JTBD job IDs) was presented for human-oversight confirmation, the user **rejected the core decision**:

> User direction 2026-05-25 (drain): *"Yeah, I really don't like this. The intention was not for the README to cite the JTBDs. The idea is that based on the JTBD, the README could market the plugin to the persona and the problem it solves for them. The current approach fails that miserably."*

ADR-051 chose Option D2: *"Plugin README MUST cite at least one current JTBD job ID; value framing SHOULD derive from JTBD"*, with a load-bearing commit hook enforcing the ID citation as a drift-detection anchor. The user's actual intent was the opposite emphasis: the JTBD should **inform persona-facing marketing** — the README sells the plugin to its persona by naming the problem it solves for them — and the mechanical **ID citation is not the goal** and "fails that miserably". The drift-detection-anchor mechanism (grep for a JTBD ID) optimised for detector-simplicity at the expense of the README's real job (marketing to the persona).

This is a **reject/supersede**, not a minor amend — the chosen mechanism (cite-the-ID + enforce-via-hook) is wrong, and the implementation (the commit hook + the JTBD-ID citations now in every plugin README) must be unwound. ADR-051 is **left unoversighted** (P283/ADR-066 marker withheld) until superseded.

## Symptoms

(deferred to investigation)

- Every `@windyroad/*` plugin README carries a "Jobs to be Done" section citing JTBD IDs (the ADR-051 anchor) — internal-governance plumbing surfaced in a persona-facing document.
- A load-bearing commit hook (per ADR-051) denies README commits that don't cite a current JTBD ID — enforcing the wrong thing.
- The README's `## What It Does` value-framing exists but the load-bearing signal is the ID citation, not the persona/problem marketing the user actually wants.

## Workaround

None — the READMEs function; they just market poorly. The hook enforces ID-presence, which is satisfiable without good marketing.

## Root Cause Analysis

### Investigation Tasks

- [ ] Supersede ADR-051: the README's job is to **market the plugin to its persona** — name the persona + the problem the plugin solves for them, derived FROM the JTBD content (not the ID). Record the superseding decision via the asking flow.
- [ ] Decide the drift-detection question separately: ADR-051's ID-citation was motivated by wanting a cheap currency/drift anchor. If currency-of-README still matters, find a mechanism that doesn't degrade the marketing (e.g. derive-and-check persona/problem coverage, or a lighter advisory, or drop the hard gate). Don't re-introduce ID-citation as the anchor.
- [ ] Unwind the implementation: retire/replace the ADR-051 commit hook (the JTBD-ID-citation enforcer); rewrite each plugin README's value framing to market from the JTBD (persona + problem solved), removing the mechanical ID-citation as the load-bearing element.
- [ ] Reconcile with ADR-008 (per-job-file layout — still the JTBD source) and ADR-053 (maturity badge in README header) — the README header composition.
- [ ] Re-confirm the superseding decision via `/wr-architect:review-decisions`.

## Dependencies

- **Blocks**: ADR-051 human-oversight confirmation (held until superseded).
- **Blocked by**: none.
- **Composes with**: ADR-008 (JTBD source layout), ADR-053 (README maturity badge — same header region), ADR-040/ADR-051 hook precedent, P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain — user rejected the ADR's core mechanism)

- **P287 / P289 / P290 / P291 / P292 / P293** — sibling drain-surfaced reworks; this is the first **reject/supersede** (others were amends/generalisations).
- **ADR-051** (`docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md`) — the decision to supersede.
- **ADR-008** (JTBD source) + **ADR-053** (README maturity badge) — README composition neighbours.
