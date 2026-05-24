# R007: User-stated preconditions / paired-capability check

The user has stated in conversation, commit messages, changesets, or problem tickets that this change is only safe IF some paired capability is also shipped (e.g., "A is only safe if B ships alongside", "don't release X until Y is merged"). The check fires on every per-action assessment.

This is more memo-to-self than typical risk class — the check is mandatory per `packages/risk-scorer/agents/pipeline.md` `## User-Stated Preconditions Check`. Most reports show it as a one-line "no unmet preconditions" pass-through. When it DOES fire as a Risk item with Inherent ≥ 5 (per the policy "Inherent risk MUST be ≥ Medium even when the diff's technical risk alone would score Low"), treat as load-bearing.

## Recogniser

**Path patterns** (any match → consider this entry):

- (no path patterns — surfaces from prose context, not file paths)
- Surface: recent conversation messages, commit messages on the unreleased queue, `.changeset/*.md` body prose, problem-ticket bodies cross-referenced from the diff, `CLAUDE.md` MANDATORY rules

**Diff-content keywords** (in conversation/commit/changeset/ticket prose, NOT diff content directly):

- "only safe if", "don't release X until", "must ship alongside", "paired with", "depends on", "blocked by"
- "X requires Y", "wait for Y to land", "do not Z until W"
- (verbatim user instructions in MANDATORY/imperative form)

**Anti-patterns** (looks like R007 but isn't):

- Future-work-noted in a TODO or retro observation — soft preconditions, not load-bearing.
- A problem ticket's "Composes with" relationships — those are coordination notes, not safety constraints.
- A passing reference to a sibling capability without an explicit safety constraint — descriptive, not prescriptive.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | yes | Most preconditions name commit-time concerns (don't commit X until Y merges) |
| push | yes | Some preconditions are push-blocking (don't push to main until coordinated branch merges) |
| release | **primary** | Most "don't release X until Y" preconditions land here |
| external-comms | yes | Some preconditions name outbound-prose surfaces (don't announce X until Y) |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 4 (Significant) — when a precondition is unmet and ignored, the user explicitly warned about the consequence; ignoring an explicit warning is high-impact by definition. Per `pipeline.md`: "Inherent risk MUST be ≥ Medium even when the diff's technical risk alone would score Low".
- **Likelihood**: 3 (Possible) — most preconditions are obvious; some get missed when the conversation thread is dense or the precondition lives in a problem-ticket the agent didn't read.
- **Inherent score**: 12
- **Inherent band**: High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| `pipeline.md` `## User-Stated Preconditions Check` mandatory section | Every per-action assessment (scorer is required to scan recent conversation + tickets + changesets + CLAUDE.md) | 1 | -1 likelihood | Bump +2 (the check is foundational; skipping it is structural failure) |
| `/wr-risk-scorer:assess-release` skill | User explicitly invokes for pre-release sweep | 2 | -1 likelihood | Bump +1 |
| Held-changeset pattern for paired-capability case | Paired capability is in flight; changeset held until paired capability ships | 3 | -1 likelihood | Bump +1 (paired capability not yet shipped means precondition unmet) |
| Briefing memory items naming cross-cutting dependencies | Always (declarative; surfaces at SessionStart) | n/a (declarative) | 0 paths | Lower author-mindfulness |

Lifetime residual likelihood = 1 (Rare; capped at floor) when all three paths fire.

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Recent conversation includes verbatim "only safe if" / "don't release until" / "paired" language naming a paired capability | 0 (the check is about to fire) | Surfaces the precondition; not a band-shift |
| Paired capability status: NOT YET SHIPPED at this moment | +2 | Precondition unmet; this is the load-bearing high-residual case |
| Paired capability status: shipped in a prior session, can be cited by SHA | -1 | Empirical evidence of paired-capability presence |
| Held-changeset for paired capability is in `docs/changesets-holding/` with reinstate trigger naming this commit's paired surface | 0 (held-changeset pattern is the right shape) | Documented control fire |
| User has not stated any preconditions in scope of this action | -2 (floor 1) | No precondition class to fire on |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 1 (Rare) — pipeline.md mandatory check fires every assessment; held-changeset pattern parks unmet-precondition cases.
- **Residual score**: 4
- **Residual band**: Low — at appetite.

**At appetite**. Cost-of-control is low; residual reflects rare cases where multiple precondition sources are scanned and one slips through.

## Watch-out

- Distinguish "future-work-noted" (a TODO or retro observation) from "this-change-is-only-safe-if-X-also-ships" (load-bearing precondition). Only the latter routes through the above-appetite RISK_REMEDIATIONS flow.
- The check sources extend beyond the immediate prompt: scan the unreleased changeset queue's prose for paired-capability claims; scan CLAUDE.md MANDATORY rules.
- Soft preconditions (observation in a retro) vs hard preconditions (verbatim instruction in active session) — only hard ones with paired-capability NOT-yet-met are load-bearing.

## See also

- **Generalisation**: not a defect class per se — this is a CHECK the scorer must run.
- **Driver references**: `packages/risk-scorer/agents/pipeline.md` `## User-Stated Preconditions Check` section, ADR-015 (pure-scorer contract), ADR-026 (grounding sentinel — preconditions cite source).
