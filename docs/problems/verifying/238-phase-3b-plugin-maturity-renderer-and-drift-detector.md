# Problem 238: Phase 3b — README badge renderer (`wr-itil-plugin-maturity-render`) + advisory drift detector (`check-plugin-maturity-drift.sh`)

**Status**: Verification Pending
**Reported**: 2026-05-17
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Phase 3b of the P087 plugin maturity rollout. Two scripts ship in this phase per ADR-063 §Phase 3 sub-iter shape:

1. **`wr-itil-plugin-maturity-render`** (`packages/itil/bin/wr-itil-plugin-maturity-render` shim → `packages/itil/scripts/plugin-maturity-render.sh` canonical body) — writes the prose-woven rollup badge to each plugin's `README.md` value-framing lead prose AND populates the per-skill `Maturity` column in existing `## Skills` / `## How It Works` tables. Reads `plugin.json` `maturity:` field as canonical source. Markdown text only — no shields.io URL, no inline SVG (per ADR-063 §Decision Outcome §"README badge rendering format"). During the Bootstrapping window (sunset 2026-06-06 per ADR-053), rollup renders the compound form *"(Experimental, suite-bootstrap window; 796 invocations / 30d)"*; per-skill column renders band name only (compound stays at rollup). Anti-patterns enforced: NO standalone `## Maturity` section; NO header block immediately after H1 before any prose framing (reproduces ADR-051 anti-pattern).

2. **`check-plugin-maturity-drift.sh`** (`packages/retrospective/scripts/check-plugin-maturity-drift.sh` canonical body → `packages/retrospective/bin/wr-retrospective-check-plugin-maturity-drift` shim) — advisory drift detector. Compares rendered README badge against canonical `plugin.json` `maturity:` field per plugin. Sibling to ADR-051's `check-readme-jtbd-currency.sh`. Different anchor (maturity record vs JTBD ID), different failure mode (render drift vs citation drift), same detector pattern. Exit code 0 always per ADR-013 Rule 6. NDJSON-per-drift signal on stdout for retro / release-time consumption.

Phase 3b MUST land AFTER Phase 3a (P237) — the renderer needs canonical `plugin.json` field data populated; the drift detector needs the same canonical record to compare rendered badges against. ADR-052 behavioural bats coverage: drift fixture, clean fixture, stale-band fixture, anti-pattern fixture (synthetic README with standalone `## Maturity` section → render produces correct prose-woven output and drift detector flags the anti-pattern).

Child of P087. Driver: ADR-063 Phase 3 sub-iter contract.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Author `packages/itil/scripts/plugin-maturity-render.sh` canonical body + shim per ADR-049.
- [ ] Author `packages/retrospective/scripts/check-plugin-maturity-drift.sh` canonical body + shim per ADR-049.
- [ ] Author behavioural bats fixtures per ADR-052: render fixture (clean → expected diff), drift fixture (non-matching badge), stale-band fixture, anti-pattern fixtures (standalone `## Maturity` section absent in rendered output; no shields.io URL; no compound rendering in per-skill table cells).
- [ ] Verify renderer's prose-weaving anchor pattern resists plugin-author restructuring of the value-framing lead prose — if brittle, queue Phase 3b' iter to introduce structured anchors (HTML comment delimiters) per ADR-063 §Reassessment Triggers.
- [ ] Wire detector into `/wr-retrospective:run-retro` Step 2b cross-reference (sibling to ADR-051's wiring).
- [ ] Verify exit-0-always invariant via behavioural bats (negative-presence on non-zero exits).

## Dependencies

- **Blocks**: P087 closure path (Phase 3b is on the critical path to verifying P087)
- **Blocked by**: P237 (Phase 3a population script — needs canonical fields to render against)
- **Composes with**: ADR-051 (sibling drift detector pattern; same detector shape, different anchor), ADR-063 (Phase 3 presentation-layer contract)

## Related

- P087 — parent: no maturity / battle-hardening signal on plugins, skills, agents, or hooks
- ADR-053 — Phase 1 taxonomy (rendered surface drives badge format)
- ADR-058 — Phase 2 measurement scripts (NOT the source for the renderer — renderer reads `plugin.json`, not NDJSON)
- ADR-063 — Phase 3 presentation-layer contract (renderer + detector pinned here)
- ADR-051 — sibling drift-detector pattern (JTBD-currency); same pattern, different anchor
- ADR-013 Rule 6 — fail-safe / advisory-first
- ADR-044 — silent-framework (renderer is mechanical; no AskUserQuestion per re-render)
- ADR-049 — bin shim grammar
- ADR-052 — behavioural bats
- P237 — Phase 3a population script (blocks this ticket)
- P239 — Phase 3c bats doc-lint per plugin

## Fix Released

Phase 3b renderer + drift detector shipped 2026-05-18 in `/wr-itil:work-problems` AFK orchestrator iter 8 (session 6). Two changesets land in the same iter commit:

- `@windyroad/itil` minor — renderer `wr-itil-plugin-maturity-render` (`packages/itil/scripts/plugin-maturity-render.sh` + `packages/itil/bin/wr-itil-plugin-maturity-render`). 17 behavioural bats fixtures at `packages/itil/scripts/test/plugin-maturity-render.bats` — all green.
- `@windyroad/retrospective` minor — drift detector `wr-retrospective-check-plugin-maturity-drift` (`packages/retrospective/scripts/check-plugin-maturity-drift.sh` + `packages/retrospective/bin/wr-retrospective-check-plugin-maturity-drift`). 14 behavioural bats fixtures at `packages/retrospective/scripts/test/check-plugin-maturity-drift.bats` — all green.

Awaiting user verification — next adopter session that runs `wr-itil-plugin-maturity-render` and `wr-retrospective-check-plugin-maturity-drift` from a marketplace-installed cache against a populated `plugin.json` set confirms the renderer + drift detector behave as documented. Per ADR-022 the user may also signal verification by acknowledging Phase 3b's smoke-test behaviour against the live monorepo (12 plugins / 0 drift instances at baseline — coherent because all 11 plugins lack `maturity:` field pending Phase 3a mechanical rollout).

Recovery path: `/wr-itil:transition-problem 238 known-error` after reverting the iter commit.
