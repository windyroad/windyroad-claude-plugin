---
status: proposed
job-id: keep-plugins-current
persona: solo-developer
date-created: 2026-04-23
---

# JTBD-007: Keep Plugins Current Across Projects

## Job Statement

When I ship a new version of a plugin I depend on, I want every active project to pick up the latest code reliably, so I don't waste time debugging behaviour that was already fixed in the latest release.

## Desired Outcomes

- One command refreshes all enabled plugins in the current project and its siblings
- Plugin updates land reliably without silent no-ops — the refresh mechanism actually fetches the latest marketplace version
- No manual per-project reinstall is required
- The refresh is gated by consent when side effects touch sibling projects
- The process reports what changed, what stayed the same, and what failed
- Restarting Claude Code is surfaced as the final step so the new code is loaded
- **(Amended 2026-05-04 by P159; re-amended 2026-05-25 by P294/ADR-069)** README content currency tracks code currency — adopters never read prose describing a prior release. Per ADR-069 (superseding ADR-051): each `@windyroad/*` plugin README markets the persona's problem derived FROM the JTBD (no JTBD-ID citation); skill-inventory drift — a shipped skill not named in the README — is **enforced at commit time** via PreToolUse:Bash hook; retro/release-time advisories ride as backup signals. **(Amended in P087 Phase 3)** Maturity-band currency (recomputed by the Phase 3a writer per ADR-044 silent-framework carve-out and rendered into READMEs per ADR-063 §Phase 3b) is a third dimension of the same currency concern — code currency, README-content currency, and maturity-band currency all track the same release together.

## Persona Constraints

- Works across multiple related projects (monorepo or sibling repos)
- Expects the agent to handle the mechanics after a release
- Does not want to manually track which plugins updated in which project
- Wants transparency — a clear report of before/after versions per project

## Current Solutions

- Manually running `claude plugin uninstall` + `claude plugin install` per plugin per project
- Relying on `claude plugin install` alone, which silently no-ops and leaves old code in place (P106)

## Related decisions

- **ADR-051** — JTBD-anchored README structure (amended P159; **superseded 2026-05-25 by ADR-069**). Extended this job's currency scope from code-currency to README-content-currency. ADR-069 retains the content-currency dimension as skill-inventory drift and drops the JTBD-ID anchor.
- **(Added 2026-05-25) ADR-069** — READMEs market the persona's problem (no ID citation); commit-hook narrowed to skill-inventory-drift. Current home of this job's content-currency enforcement.
- **(Added 2026-05-04) P159** — Drift detector should be a load-bearing commit-hook with auto-fix, not a retro-time advisory. Drives the load-bearing-from-the-start direction for this job's content-currency dimension.
