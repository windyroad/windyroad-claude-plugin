---
status: "proposed"
date: 2026-04-16
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-10-16
---

# On-Demand Assessment Skills for Governance Plugins

## Context and Problem Statement

The governance plugins (`wr-risk-scorer`, `wr-architect`, `wr-jtbd`) expose assessment agents that are invoked exclusively via hooks at gate points (user-prompt-submit, pre-tool-use, pre-commit). Users who want a pre-flight assessment outside a gate trigger must either fake a gate event or manually invoke the subagent via the Task tool — requiring knowledge of the exact `subagent_type` string and crafting a self-contained context prompt.

This makes on-demand governance assessment invisible (undiscoverable) and high-friction. JTBD-005 (Invoke Governance Assessments On Demand) and JTBD-202 (Run Pre-Flight Governance Checks Before Release or Handover) document this gap explicitly.

The `wr-itil` plugin resolved this gap for its own domain by wrapping agents in skills (`manage-problem`, `manage-incident`). ADR-011 established that skill-wrapping pattern. This ADR extends the pattern to the governance assessment plugins.

## Decision Drivers

- **JTBD-005** (Invoke Governance Assessments On Demand) — solo-developer needs pre-flight risk scores via `/` autocomplete, not Task-tool invocations
- **JTBD-202** (Pre-Flight Governance Checks) — tech-lead needs release readiness checks before committing to a release
- **JTBD-101** (Extend the Suite) — updated desired outcome: plugins with assessment agents must expose corresponding assessment skills
- **ADR-011** (manage-incident skill) — positive precedent for skill-wrapping assessment agents
- **ADR-009** (gate marker lifecycle) — on-demand assessment must interact correctly with TTL+drift marker model
- **P020** — the open problem this ADR resolves

## Considered Options

### Option A: Per-plugin assessment skills (chosen)

Each governance plugin adds its own assessment skill(s). Skills are discoverable under their plugin's namespace (e.g., `/wr-risk-scorer:assess-release`).

### Option B: Single cross-plugin dispatcher `/wr:assess`

A single skill across all governance plugins, with a mode picker to select which assessment to run.

### Option C: Hook-only (status quo)

Keep assessments hook-triggered only. Document the manual Task-tool invocation pattern for on-demand use.

## Pros and Cons of the Options

### Option A: Per-plugin assessment skills

**Pros:**
- Discoverable under the expected plugin namespace — `/wr-risk-scorer:` autocomplete surfaces risk-scorer skills
- Each skill owns its own context-gathering (release queue for pipeline, staged diff for wip, etc.)
- Follows the established ADR-011 skill-wrapping precedent exactly
- Independent release cadence per plugin — no cross-plugin coupling

**Cons:**
- Multiple SKILL.md files to maintain
- Slight redundancy — each skill must document the subagent delegation pattern

### Option B: Single cross-plugin dispatcher

**Pros:**
- One entry point for all assessments
- Composable — one skill can run all three assessments in sequence

**Cons:**
- Hard to discover — users must know to look for `/wr:assess` rather than under their plugin's namespace
- Cross-plugin dependency: changes to the dispatcher affect all governance plugins
- Inconsistent with the per-plugin skill convention established by ADR-011

### Option C: Hook-only (status quo)

**Pros:**
- No new code

**Cons:**
- Directly violates JTBD-005 and JTBD-202
- Makes governance capabilities invisible
- High friction — requires exact subagent_type knowledge

## Decision Outcome

**Option A is chosen.** Per-plugin assessment skills, following the ADR-011 skill-wrapping pattern.

## Scope

**In scope (this ADR):**

| Plugin | Skill name | Subagent wrapped | Description |
|--------|-----------|-----------------|-------------|
| `wr-risk-scorer` | `assess-release` | `wr-risk-scorer:pipeline` | Commit/push/release risk score |
| `wr-risk-scorer` | `assess-wip` | `wr-risk-scorer:wip` | Uncommitted-diff risk score |
| `wr-risk-scorer` | `assess-external-comms` | `wr-risk-scorer:external-comms` | Risk/leak review of outbound prose drafts (P064 / ADR-028 amended 2026-05-14) |
| `wr-voice-tone` | `assess-external-comms` | `wr-voice-tone:external-comms` | Voice + tone review of outbound prose drafts (P038 / ADR-028 amended 2026-05-14) |
| `wr-architect` | `review-design` | `wr-architect:agent` | ADR compliance review |
| `wr-jtbd` | `review-jobs` | `wr-jtbd:agent` | Persona/job alignment review |

**Out of scope for now:**
- `wr-risk-scorer:assess-plan` — lower priority; `plan-risk-guidance.sh` hook already covers plan mode
- Eval harnesses for assessment skills — deferred to P012 (skill testing harness)

## Naming Convention

Assessment skills use the pattern `<verb>-<artifact>`:
- `assess-<artifact>`: for skills that score or measure a quantitative property (`assess-release`, `assess-wip`)
- `review-<artifact>`: for skills that produce a qualitative compliance report (`review-design`, `review-jobs`)

This follows ADR-010's established verb-noun pattern and distinguishes assessment skills (one-shot stateless evaluation) from management skills (stateful lifecycle workflow). `manage-*` implies a workflow with lifecycle transitions; `assess-*` and `review-*` imply a point-in-time read-only evaluation.

## Gate Marker Interaction (ADR-009 clarification)

When an assessment skill invokes `wr-risk-scorer:pipeline` as a subagent, the `PostToolUse:Agent` hook (`risk-score-mark.sh`) reads the structured `RISK_SCORES` / `RISK_BYPASS` output and writes the bypass marker files (`${TMPDIR}/claude-risk-${SESSION_ID}/reducing-commit` etc.) — exactly as it does when the pipeline mode is triggered by a commit attempt.

**Skills MUST NOT write marker files directly.** The only correct mechanism is subagent delegation:

```
assess-release skill → delegates to wr-risk-scorer:pipeline subagent
  → pipeline agent outputs: RISK_SCORES: commit=N push=N release=N
  → risk-score-mark.sh PostToolUse hook writes the marker files
```

This preserves ADR-009's TTL+drift model: markers written during an on-demand assessment have the same TTL and are invalidated by the same drift hashes as markers written during a gate-triggered assessment. A subsequent `git commit` in the same session uses the already-written bypass marker and does not re-trigger the scorer.

## Context-Gathering Protocol

Each assessment skill auto-detects context from git state:

| Skill | Auto-detected context | AskUserQuestion fallback |
|-------|----------------------|-------------------------|
| `assess-release` | Unpushed commits (`git log origin/main..HEAD`), changesets dir, staged diff | Prompt for explicit release scope if ambiguous |
| `assess-wip` | Current `git diff HEAD` (unstaged + staged) | None — WIP is always the current diff |
| `review-design` | Staged diff + recent commits, `docs/decisions/*.md` | Ask "what are you planning to change?" |
| `review-jobs` | Staged diff + recent commits, `docs/jtbd/**/*.md` | Ask "what are you planning to change?" |

All decision branch points (e.g., above-appetite risk) use `AskUserQuestion` per ADR-013 Rule 1. Assessment skills are read-only — they do not commit files (per ADR-014, assessment skills that produce no file changes are exempt from the commit obligation).

## Scorer Output Contract: `RISK_REMEDIATIONS:` Schema

The scorer's structured `RISK_REMEDIATIONS:` block is the machine-readable interface between scorer and orchestrator. It MUST be emitted by all three scoring modes (pipeline, wip, plan) when cumulative risk exceeds appetite.

### Schema (5 columns)

```
RISK_REMEDIATIONS:
- R1 | <description> | <effort S/M/L> | <risk_delta -N> | <files affected>
```

| Column | Purpose |
|--------|---------|
| `description` | Free-form prose summarising the remediation. The agent reads this and decides what to do. |
| `effort` | Estimated size — S (< 1h), M (1-4h), L (> 4h) |
| `risk_delta` | Estimated score reduction (e.g., `-3`) |
| `files affected` | Files or areas touched |

The agent reads the `description` column and decides what to do. There is no structured `action_class` column (ADR-042 Rule 2a).

## Scorer Output Contract: `RISK_REGISTER_HINT:` Companion Line (P110)

The scorer's structured `RISK_REGISTER_HINT:` block is the passive-trigger channel that routes register-worthy pipeline findings into the standing-risk register (`docs/risks/`). It is additive — emitted alongside (not instead of) `RISK_SCORES:`, `RISK_REMEDIATIONS:`, and `RISK_BYPASS:`. Currently defined for the `pipeline` scoring mode only; `wip` and `plan` may gain their own hints in a follow-up if a register-worthy shape surfaces in those modes.

### Shape (bulleted-list, multi-hint capable)

```
RISK_REGISTER_HINT:
- <reason-tag> | <one-line prefill>
```

| Column | Purpose |
|--------|---------|
| `reason-tag` | One of three reserved tags: `above-appetite-residual`, `confidentiality-disclosure`, `user-stated-precondition`. Closed vocabulary — extending requires a new ticket. |
| `prefill` | Free-form one-line description the orchestrator passes to `/wr-risk-scorer:create-risk` as initial risk title/description. |

### Consumption timing (post-loop)

The hint is consumed by the orchestrator **after** the ADR-042 Rule 2a auto-apply remediation loop converges or halts — not interleaved. A remediation that reduces residual back within appetite does NOT retract the hint; the risk is standing even if this change is no longer in breach. This separation preserves ADR-042 Rule 2a's within-loop decision semantics: the loop sees only `RISK_REMEDIATIONS:` descriptions and decides what to apply; the register hint is a sibling output that sits outside the loop's decision surface.

### Silence semantics

No hint is emitted when all cumulative scores are within appetite AND no confidentiality-disclosure or user-stated-precondition item fires. This extends the Below-Appetite Output Rule (ADR-013 Rule 5) — a silent policy-authorised pass remains silent across all structured blocks, including the hint.

### Problem and JTBD trace

- P110 — parent ticket; closes the passive-trigger gap that P102's MVP slash command left open.
- JTBD-001 (Enforce Governance Without Slowing Down) — the "no manual step is needed to trigger reviews" desired outcome; the pipeline agent is passively invoked, so the hint inherits that passivity.
- JTBD-005 (Invoke Governance Assessments On Demand) — composed with the hint via pre-filled `/wr-risk-scorer:create-risk` invocation.

## Confirmation

- [x] `packages/risk-scorer/skills/assess-release/SKILL.md` created; skill delegates to `wr-risk-scorer:pipeline` via the Skill tool
- [x] `packages/risk-scorer/skills/assess-wip/SKILL.md` created; skill delegates to `wr-risk-scorer:wip` via the Skill tool
- [x] `packages/architect/skills/review-design/SKILL.md` created; skill delegates to `wr-architect:agent` via the Skill tool
- [x] `packages/jtbd/skills/review-jobs/SKILL.md` created; skill delegates to `wr-jtbd:agent` via the Skill tool
- [x] No skill contains `touch`, `echo`, or `mkdir` instructions targeting `$TMPDIR/claude-risk-*` directly
- [x] All four skills declare `allowed-tools: Read, Glob, Grep, AskUserQuestion, Skill` (at minimum; also Bash for git context-gathering)
- [x] ADR-002 package inventory updated to list all new skills under architect, risk-scorer, and jtbd entries
- [x] `docs/jtbd/README.md` includes JTBD-005 and JTBD-202 ✓ (done)
- [x] JTBD-005, JTBD-202, updated tech-lead persona, updated JTBD-101 are committed ✓ (done)
- [x] `packages/risk-scorer/agents/pipeline.md` defines a `RISK_REGISTER_HINT:` block with the three reserved reason tags (`above-appetite-residual`, `confidentiality-disclosure`, `user-stated-precondition`), post-loop consumption semantics, and the silence-when-no-trigger-fires rule (P110)
- [x] `packages/risk-scorer/agents/test/risk-scorer-register-hint.bats` guards the contract (P110)

## Related

- P020: `docs/problems/020-on-demand-assessment-skills.open.md` — the problem this ADR resolves
- ADR-011: `docs/decisions/011-manage-incident-skill.proposed.md` — skill-wrapping precedent
- ADR-009: `docs/decisions/009-gate-marker-lifecycle.proposed.md` — gate marker TTL+drift model
- ADR-014: `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md` — assessment skills are read-only, exempt from commit obligation
- ADR-013: `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — AskUserQuestion at branch points
- ADR-002: `docs/decisions/002-monorepo-per-plugin-packages.proposed.md` — package layout; inventory to be updated
- ADR-010: `docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md` — naming pattern for skills
- JTBD-005: `docs/jtbd/solo-developer/JTBD-005-assess-on-demand.proposed.md`
- JTBD-202: `docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md`
- JTBD-101: `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`
