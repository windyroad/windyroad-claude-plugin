# Problem 299: ADR-034 per-project auto-install is the wrong mechanism — the plugin install cache is global/shared, so one update propagates to all projects

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 2 (Minor — a per-project SessionStart auto-install is redundant work, not a correctness break; updates still propagate via the shared cache; but the redundancy + the per-project consent gate add friction and model the wrong thing) × Likelihood: 3 (Possible — fires per project per session)
**Effort**: M — ADR-034 rework (drop the per-project auto-install model; define the update trigger against the global cache) + reconcile with /install-updates (ADR-030) which is the actual cache-refresh surface
**WSJF**: 6/2 = **3.0** (Open multiplier 1.0)

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-034 (Auto-install on next session start — SessionStart hook + per-project consent gate + AFK carve-out) was presented for human-oversight confirmation, the user **rejected the mechanism**:

> User direction 2026-05-25 (drain): *"this is wrong. The sibling projects automatically get the new version when we update the install for one. If we do it here in this project, they all get it."*

ADR-034 modelled auto-install as a **per-project** SessionStart hook (each project checks for updates + installs on its own session start, gated by a per-project consent marker). But the **plugin install cache is global/shared across projects** (per the `/install-updates` skill contract: "the plugin install cache is global/shared across projects … this advances the active version for every project that enables those plugins"). So updating the install from ANY one project (in practice, this plugin-dev repo after a release) advances the active version for ALL projects on the machine — a per-project auto-install is redundant.

**Key distinction (vs ADR-047/P297):** per-project *artifacts* (scaffold docs/risks/ etc.) genuinely need a per-project trigger because each project's `docs/` is separate; the *global plugin cache* does NOT — it's shared, so one update propagates. ADR-034 wrongly applied the per-project-trigger pattern to the global-cache case.

ADR-034 is **left unoversighted** (P283/ADR-066 marker withheld) until reworked.

## Symptoms

(deferred to investigation)

- ADR-034's `session-start-update-check.sh` would fire in every project, each trying to install — but they share one global cache, so all but the first are redundant.
- The per-project consent marker models per-project install decisions that don't reflect the shared-cache reality.

## Root Cause Analysis

### Investigation Tasks

- [ ] Rework ADR-034 given the global/shared cache: the update should be triggered ONCE (from the plugin-dev repo post-release via `/install-updates` per ADR-030, or from any single project) and propagate to all; there is no need for a per-project auto-install. Decide whether ADR-034 is superseded entirely (the `/install-updates` chain per P233 already covers post-release cache refresh) or reduced to a "global cache is stale → refresh once" check.
- [ ] Reconcile with ADR-030 (`/install-updates` repo-local skill) + P233 (post-release cache refresh chain) — those are the real cache-refresh surfaces; ADR-034 may be redundant with them.
- [ ] If any session-start check survives, it should detect global-cache staleness (shared state), not per-project install need.
- [ ] Re-confirm the reworked ADR-034 via `/wr-architect:review-decisions` (or supersede it).

## Dependencies

- **Blocks**: ADR-034 human-oversight confirmation (held until reworked).
- **Blocked by**: none.
- **Composes with**: ADR-030 (/install-updates repo-local skill), P233 (post-release cache refresh), ADR-047/P297 (the per-project-vs-global distinction — scaffold IS per-project, install is NOT), P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain)

- **P297** (ADR-047) — sibling on the per-project-vs-global trigger axis: scaffold needs per-project (SessionStart), install does NOT (global cache).
- **P287 / P289–P298** — sibling drain-surfaced reworks.
- **ADR-034** (`docs/decisions/034-auto-install-on-next-session-start.proposed.md`) — the decision to rework/supersede.
- **ADR-030** + **P233** — the actual cache-refresh surfaces ADR-034 may be redundant with.
