# Problem 023: Governance skills should commit completed work, not defer to user

**Status**: Closed
**Reported**: 2026-04-16
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)

## Description

The manage-problem skill (step 11) says "Do not commit — the user will commit when ready." This instruction actively works against the lean release principle: completed work sits uncommitted, accumulating WIP risk. If the session ends, context compresses, or a conflicting change lands, the uncommitted work is at risk of being lost or requiring manual recovery.

The correct behaviour: after completing a discrete unit of work (problem file update, Known Error transition, fix implementation), the skill should commit the changes immediately with a descriptive commit message. This aligns with the lean principle of reducing WIP and keeping the pipeline flowing — the risk-scorer can then assess the committed work and the release pipeline can pick it up.

This is not limited to manage-problem. The pattern "Do not commit — the user will commit when ready" appears to be a default assumption across governance skills. Every skill that produces file changes should commit its completed work unless the user has explicitly asked it not to.

## Symptoms

- manage-problem `work` mode completes a fix, updates problem files, transitions status — then says "Ready to commit when you are" instead of committing.
- Uncommitted changes accumulate across multiple problem-work iterations in a single session.
- If the session ends unexpectedly, all uncommitted governance artefact changes are lost.
- The risk-scorer WIP mode cannot assess uncommitted changes (they aren't in git history yet), creating a blind spot.
- The "Do not commit" instruction contradicts the lean release principle documented in the project.

## Workaround

User manually commits after each skill operation. Friction, not harm.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — manual commit step is unnecessary friction that slows the governance-work-release cycle.
  - Solo-developer persona (JTBD-002 Ship with Confidence) — uncommitted work is invisible to the risk-scorer pipeline, creating an unscored gap.
  - Tech-lead persona — WIP accumulation makes it harder to audit what governance work has been done.
- **Frequency**: Every manage-problem operation that produces file changes (create, update, transition, work).
- **Severity**: Medium. No data loss if session completes normally, but risk of loss on unexpected session end. Compounding friction across multi-problem work sessions.
- **Analytics**: Observed this session — manage-problem `work P021` completed SKILL.md edits + problem file transition, then asked user to commit instead of committing.

## Root Cause Analysis

### Investigation Tasks

- [x] Audit manage-problem SKILL.md for all "Do not commit" / "the user will commit" instructions. Replaced with ADR-014 `work → score → commit` sequence (3 occurrences: step 9e, step 11, step report).
- [x] Audit manage-incident SKILL.md for the same pattern. Replaced with ADR-014 sequence (1 occurrence: step 14).
- [x] Audit other governance skills (create-adr, update-guide, update-policy, run-retro) — none had the pattern. Deferred to when those skills are worked per ADR-014 scope.
- [x] Define the commit-message convention for governance-skill commits. Documented in ADR-014 `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`.
- [x] Ensure the skill's `allowed-tools` includes Bash — both SKILL.md files already had Bash in allowed-tools.

## Root Cause Analysis

### Confirmed Root Cause

The `manage-problem` and `manage-incident` skills had a "Do not commit" instruction in their report steps, added as a conservative default when the skills were authored. No policy existed at the time to require auto-commit. ADR-014 now establishes that policy.

### Workaround

Replaced by fix. Skills now instruct the primary agent to score and commit after each operation.

## Fix Released

Deployed in `@windyroad/itil` v0.3.2 (commit `0806242`). `manage-problem` and `manage-incident` SKILL.md files updated to score and commit after each operation. Awaiting user verification that governance skills now commit automatically.

## Related

- `packages/itil/skills/manage-problem/SKILL.md` line ~280 — "Do not commit" instruction
- Session evidence: Image #5 showing "Ready to commit when you are" after P021 work
- P024: risk-scorer WIP mode should flag uncommitted completed work
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
- JTBD-002: `docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md`
