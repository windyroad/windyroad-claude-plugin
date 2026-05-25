# Problem 288: New Jobs To Be Done and new personas need human-oversight confirmation (sibling of P283)

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 9 (Med High) — Impact: 3 (Moderate — auto-made JTBDs/personas drift from user intent exactly as auto-made ADRs do; documented jobs/personas are load-bearing governance artifacts the JTBD gate reviews every edit against, so a poorly-auto-derived job/persona propagates wrong alignment verdicts) × Likelihood: 3 (Likely — every `wr-jtbd:update-guide` run and every agent-derived job/persona that lands without a confirm pass)
**Effort**: M — direct mirror of the ADR-066 architect mechanism onto the wr-jtbd plugin (marker + detector + nudge + drain + born-confirmed update-guide + tests); the pattern is already built once
**WSJF**: 9/2 = **4.5** (Open multiplier 1.0)
**Type**: technical

## Description

User direction 2026-05-25: *"similar to how we are saying ADRs need human confirmation, new jobs to be done and new personas need human confirmation too."*

P283 / ADR-066 established that recorded **decisions** (ADRs) must carry human oversight: a `human-oversight: confirmed` + `oversight-date` frontmatter marker (orthogonal to `status:`), a token-cheap grep detector, a session-start nudge (AFK-self-suppressed), a `/wr-architect:review-decisions` drain skill, and born-confirmed recording via `create-adr`. The same risk applies to the **other auto-made governance artifacts**: JTBDs (`docs/jtbd/<persona>/JTBD-NNN-*.md`) and personas (`docs/jtbd/<persona>/persona.md`) can be agent-derived without a human confirming they reflect real user/business need — and the JTBD gate reviews every project edit against them, so a drifted job/persona propagates wrong alignment verdicts.

This ticket ships the symmetric **JTBD/persona human-oversight mechanism** in the `wr-jtbd` plugin, mirroring ADR-066:

1. **Marker** — `human-oversight: confirmed` + `oversight-date` on JTBD files AND persona.md files (same field as ADR-066; orthogonal to `status:`).
2. **Detector** — `wr-jtbd-detect-unoversighted` shim (ADR-049) over `docs/jtbd/**/*.md` frontmatter (persona.md + JTBD-*.md; excludes README).
3. **Session-start nudge** — a wr-jtbd SessionStart hook reporting `N jobs/personas lack human oversight — run <drain skill>`; self-suppresses on `WR_SUPPRESS_OVERSIGHT_NUDGE=1` (REUSE the architect AFK guard — work-problems Step 5 already exports it, so no orchestrator change needed).
4. **Drain skill** — confirms unoversighted jobs/personas in batches via AskUserQuestion (confirm/amend/reject), writing the marker on confirm.
5. **Born-confirmed** — `wr-jtbd:update-guide` writes the marker when the user confirms a new/edited job or persona.

## Symptoms

(deferred to investigation)

- `wr-jtbd:update-guide` and agent-derived JTBD/persona authoring land files with `status: proposed` but no record a human confirmed the job/persona reflects real need.
- The JTBD edit gate (`jtbd-enforce-edit.sh`) reviews every project edit against `docs/jtbd/` — a drifted auto-made job/persona propagates wrong alignment verdicts suite-wide.
- No detection / nudge / drain surface for unoversighted jobs/personas (the architect plugin has all three post-ADR-066; the jtbd plugin has none).

## Workaround

Confirm jobs/personas verbally at `update-guide` time; no persistent marker, no drift detection.

## Root Cause Analysis

### Investigation Tasks

- [ ] Decide: separate ADR (ADR-068, JTBD/persona oversight, citing ADR-066 as the precedent pattern) vs amend ADR-066 to generalise across governance-artifact surfaces. Lean: separate ADR — the mechanisms are plugin-specific (architect vs jtbd), mirroring how the nudge hooks are siblings not shared code.
- [ ] Confirm the marker reuses the ADR-066 field (`human-oversight: confirmed` + `oversight-date`) verbatim for cross-surface consistency.
- [ ] Decide the drain skill name (architect's is `/wr-architect:review-decisions`; `/wr-jtbd:review-jobs` is taken by the alignment-review skill — pick a distinct name, e.g. `/wr-jtbd:review-personas-and-jobs` or fold an oversight mode into review-jobs).
- [ ] Build: detector + shim, SessionStart nudge + hooks.json registration (jtbd plugin has no SessionStart event yet), drain skill, update-guide born-confirmed write, scripts/ dir + package.json files-array (jtbd has no scripts dir yet), bats.
- [ ] Verify the AFK guard reuse (`WR_SUPPRESS_OVERSIGHT_NUDGE`) — work-problems Step 5 already exports it; the jtbd nudge should honour the same var so no orchestrator edit is needed.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — investigation can begin immediately)
- **Composes with**: P283 / ADR-066 (the precedent mechanism this mirrors), the wr-jtbd plugin (`update-guide`, `review-jobs`, the edit gate), ADR-049 (shim grammar), ADR-040 (SessionStart nudge precedent).

## Related

(captured 2026-05-25 — user direction extending the ADR-066 human-oversight principle to the JTBD surface)

- **P283** / **ADR-066** — the precedent: human-oversight marker + detector + nudge + drain for ADRs. This ticket is the JTBD/persona sibling.
- `packages/jtbd/skills/update-guide/` — born-confirmed write site.
- `packages/jtbd/skills/review-jobs/` — existing alignment-review skill (name collision to resolve for the drain).
- `packages/jtbd/hooks/` — SessionStart nudge target (no SessionStart event yet).
- `packages/architect/scripts/detect-unoversighted.sh` + `architect-oversight-nudge.sh` + `skills/review-decisions/` — the templates to mirror.
