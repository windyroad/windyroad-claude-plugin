# R007: User-stated preconditions / paired-capability check

The user has stated in conversation, commit messages, changesets, or problem tickets that this change is only safe IF some paired capability is also shipped (e.g., "A is only safe if B ships alongside", "don't release X until Y is merged"). The check fires on every per-action assessment.

This is more memo-to-self than typical risk class — the check is mandatory per `packages/risk-scorer/agents/pipeline.md` `## User-Stated Preconditions Check`, and most reports show it as a one-line "no unmet preconditions" pass-through. When it DOES fire as a Risk item with Inherent ≥ 5 (per the policy "Inherent risk MUST be ≥ Medium even when the diff's technical risk alone would score Low"), treat as load-bearing — the user explicitly named the dependency.

## Controls

- **`packages/risk-scorer/agents/pipeline.md` `## User-Stated Preconditions Check` section** — canonical control; every pipeline run scans recent conversation messages, problem tickets referenced in the diff, commit messages and changeset files on the unreleased queue, and CLAUDE.md notes about cross-cutting dependencies.
- **`/wr-risk-scorer:assess-release` skill** — explicit pre-release surface for user-stated preconditions; bridges the agent-tool-grant gap (P035 fallback).
- **Held-changeset pattern** — for the "paired capability not yet released" case; held-area README documents the reinstate trigger as the paired-capability-met signal.

## Watch-out

- Distinguish "future-work-noted" (a TODO or retro observation) from "this-change-is-only-safe-if-X-also-ships" (load-bearing precondition). Only the latter routes through the above-appetite RISK_REMEDIATIONS flow.
- The check sources extend beyond the immediate prompt: scan the unreleased changeset queue's prose for paired-capability claims; scan CLAUDE.md MANDATORY rules for cross-cutting dependencies.
- A precondition can be SOFT (an observation in a retro) or HARD (a verbatim instruction in the active session). Hard ones with paired-capability NOT-yet-met are the load-bearing class — flag them as Risk items with explicit unmet-precondition rationale.
