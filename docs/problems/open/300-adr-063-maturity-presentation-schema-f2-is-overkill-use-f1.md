# Problem 300: ADR-063 maturity-presentation schema — F2 (rich-record per-surface) is overkill; F1 is sufficient to begin with

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 4 (Low-Med) — Impact: 2 (Minor — over-engineering the plugin.json maturity schema adds build + maintenance cost for capability not yet needed; not shipped, so caught before the cost lands) × Likelihood: 2 (Unlikely — affects the Phase-3 maturity-presentation build only)
**Effort**: S — amend ADR-063's chosen schema option F2 → F1; the implementation simplifies (less to build)
**WSJF**: 4/1 = **4.0** (Open multiplier 1.0)

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-063 (plugin maturity presentation layer) was presented for human-oversight confirmation, the user amended the schema choice:

> User direction 2026-05-25 (drain): *"option F2 is overkill. F1 is sufficient to begin with."*

ADR-063 chose **F2** (rich-record per-surface + string rollup `plugin.json` schema) for the maturity presentation layer. The user wants **F1** (the simpler schema) to begin with — YAGNI: start with the minimal schema and only enrich to F2 if a concrete need emerges. The in-suite `wr-itil-plugin-maturity-list` display shim (F9) is fine.

**Badge rendering (user direction 2026-05-25): use a Shields.io URL badge**, NOT the recorded F5 (markdown prose-woven text badge). The README maturity badge should be a hosted `https://img.shields.io/badge/...` image badge (the standard OSS-README badge convention — renders a recognisable shield image, links to the maturity detail) rather than inline markdown text. So ADR-063 changes on TWO axes: schema F2 → F1, and badge F5 → Shields.io URL badge.

ADR-063 is **left unoversighted** (P283/ADR-066 marker withheld) until amended.

## Symptoms

(deferred to investigation)

- ADR-063 Decision Outcome pins F2 (rich-record per-surface schema) as the `plugin.json` maturity shape; the user judges this over-engineered for the starting point.
- The Phase-3a population script + the README badge renderer would build against the richer F2 schema unnecessarily.

## Root Cause Analysis

### Investigation Tasks

- [ ] Amend ADR-063: change the chosen schema option F2 → F1 (the simpler schema). Confirm what F1's exact shape is (re-read ADR-063 Considered Options) and that the badge + F9 (display shim) still compose with F1.
- [ ] Amend ADR-063 badge rendering F5 → **Shields.io URL badge**: the README maturity badge is a hosted `https://img.shields.io/badge/<label>-<band>-<color>` image badge (links to maturity detail), not an inline markdown text badge. Pick the per-band colour mapping (Experimental/Alpha/Beta/Stable/Deprecated → shield colours) and the label scheme.
- [ ] Reconcile with ADR-053 (the maturity taxonomy) + ADR-058 (the measurement mechanism feeding the schema) — F1 must still carry enough to render the five-band badge + rollup.
- [ ] Note the YAGNI reassessment trigger: enrich F1 → F2 only when a concrete consumer needs the per-surface rich record.
- [ ] Re-confirm amended ADR-063 via `/wr-architect:review-decisions`.

## Dependencies

- **Blocks**: ADR-063 human-oversight confirmation (held until amended).
- **Blocked by**: none.
- **Composes with**: ADR-053 (maturity taxonomy), ADR-058 (measurement mechanism), P087 (the maturity-signal master ticket), P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain)

- **P287 / P289–P299** — sibling drain-surfaced reworks.
- **ADR-063** (`docs/decisions/063-plugin-maturity-presentation-layer.proposed.md`) — amendment target.
- **ADR-053** + **ADR-058** — the maturity taxonomy + measurement neighbours.
