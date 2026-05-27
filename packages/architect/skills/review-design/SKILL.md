---
name: wr-architect:review-design
description: On-demand architecture compliance review. Checks staged changes and recent commits against existing ADRs in docs/decisions/. Use before editing architecture-bearing files or before a release.
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion, Skill
---

# Architecture Compliance Review Skill

Run an architecture compliance review on demand — outside the pre-tool-use hook gate. Reviews staged changes and recent commits against the project's ADRs in `docs/decisions/`.

This skill is **read-only**. It does not commit, push, or modify files.

## When to use

- Pre-flight before a release or client handover: confirm no ADR violations crept in
- After a large refactor: verify the new structure still complies with decisions
- When proposing a structural change: get a review before editing architecture-bearing files
- Any time the hook gate is not convenient: e.g., planning mode, exploratory spikes

## Output Formatting

When referencing decision IDs (ADR-<NNN>), problem IDs (P<NNN>), or JTBD IDs in prose output, always include the human-readable title on first mention. Use the format `ADR-013 (Skill manifest in package.json)`, not bare `ADR-013`.

## Steps

### 1. Parse arguments

Read `$ARGUMENTS` for an explicit review scope (e.g., "review my changes to the auth module", "check the new API routes", "pre-release review"). If a scope is provided, use it. If empty, proceed to auto-detection.

### 2. Auto-detect context

Run the following to establish what needs reviewing:

```bash
# Staged changes
git diff --cached --stat

# Recent commits not yet pushed
git log origin/$(git rev-parse --abbrev-ref HEAD)..HEAD --oneline 2>/dev/null || git log HEAD -5 --oneline

# Changed files
git diff --cached --name-only
git diff --name-only HEAD
```

Summarise:
- Files staged or recently committed
- Whether the changes are architectural (source code, config, schema, tooling) vs purely documentary

### 3. Resolve ambiguity

If there are no staged changes and no recent unpushed commits, use `AskUserQuestion` to ask:

> "I don't see any staged or unpushed changes. What would you like me to review?
> (a) A specific set of files — please name them
> (b) All changes since the last tag
> (c) A planned change you'd like to describe
> (d) Cancel"

Do not ask if there is an obvious set of changed files.

### 4. Construct the assessment prompt

Build a self-contained prompt for the architect subagent that includes:
- The list of changed/staged files
- The git diff summary (stat output)
- Any explicit scope from the user
- The request: "Review these proposed changes against the project's ADRs. Flag any violations, gaps that need a new ADR, or compliance questions."

The architect's verdict taxonomy includes **[Unratified Dependency]** (ADR-074 surface 3): if the plan/change explicitly cites or implements an ADR that lacks `human-oversight: confirmed` (unratified, non-superseded), the architect flags ISSUES FOUND with a "ratify via /wr-architect:review-decisions first" action. This applies to plan review exactly as to edit review — a plan built on an unratified decision should not proceed until that decision's substance is ratified. No extra prompt wiring is needed (the agent owns the check); this note records that the surface-3 check is in-scope for plan review.

### 5. Delegate to wr-architect:agent

Invoke the architect subagent via the `Skill` tool:

```
subagent_type: wr-architect:agent
prompt: <constructed review prompt from step 4>
```

Wait for the subagent to complete.

### 6. Present results

Present the full compliance report to the user. The architect subagent will report:
- PASS: no violations found
- FLAGGED: specific violations or compliance questions with ADR references
- NEW ADR NEEDED: decisions that should be recorded before proceeding

If violations are flagged, use `AskUserQuestion` to ask how the user wants to proceed:
- (a) Address the violations before continuing
- (b) Proceed with a documented exception
- (c) Draft a new or amended ADR to legitimise the approach

Do not make the decision unilaterally — per ADR-013 Rule 1, architectural risk decisions are the user's.

$ARGUMENTS
