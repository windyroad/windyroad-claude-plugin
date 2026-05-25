---
status: "proposed"
date: 2026-04-16
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-10-16
---

# Governance Skills Commit Their Own Completed Work

## Context and Problem Statement

Governance skills (manage-problem, manage-incident, create-adr, run-retro, update-guide) currently end with "Do not commit. The user will commit when ready." This instruction leaves completed work uncommitted in the working tree, which creates three problems:

1. **Pipeline invisibility.** Uncommitted changes are not assessed by `wr-risk-scorer:wip` or the commit-gate hook. The risk pipeline cannot score what it cannot see.
2. **Loss risk.** If a session ends unexpectedly, all uncommitted governance artefact changes are lost — no git recovery, no audit trail.
3. **WIP accumulation.** Multiple skill operations in a session stack up as uncommitted changes. The lean release principle (minimise WIP dwell time) is violated on every skill invocation.

The commit gate hook (`packages/risk-scorer/hooks/risk-score-commit-gate.sh`) blocks `git commit` unless a risk-scorer bypass marker exists. A skill that auto-commits must therefore obtain a score before committing — establishing the ordering constraint `work → score → commit`.

## Decision Drivers

- **JTBD-001** (Enforce Governance Without Slowing Down) — manual commit steps add friction; the "no manual step needed" desired outcome applies equally to commit steps
- **JTBD-002** (Ship AI-Assisted Code with Confidence) — "every commit has been through risk scoring" presupposes that commits actually happen; uncommitted work is invisible to the pipeline
- **Lean release principle** — minimise WIP dwell time; completed work should flow to the pipeline immediately
- **ADR-013** (Structured User Interaction) — above-appetite decisions require `AskUserQuestion`, not prose; this ADR extends that rule to the commit-gate branch point
- **P023** — open problem this ADR resolves

## Considered Options

### Option A: Skills commit autonomously (chosen)

Skills instruct the primary agent to commit after completing each discrete unit of work, using the ordering: `work → score via wr-risk-scorer:pipeline → commit`. If the risk score is above appetite, the skill presents an `AskUserQuestion` before committing. Non-interactive fail-safe per ADR-013 Rule 6: skip commit and report clearly if `AskUserQuestion` is unavailable.

### Option B: Skills stage but leave commit to the user (status quo)

Keep "Do not commit. The user will commit when ready." Skills produce files; the user decides when to commit.

### Option C: Structured commit-ready summary handed off to a separate commit skill

Skills produce a machine-readable commit-ready payload. A separate `/commit-governance` skill handles scoring and committing. Skills remain commit-agnostic.

## Pros and Cons of the Options

### Option A: Skills commit autonomously

**Pros:**
- Completed work enters the pipeline immediately — no WIP accumulation
- Audit trail created at the moment of completion, not later
- Eliminates a manual step that adds no quality benefit (quality checks happen inside the skill, before the commit instruction)
- Consistent with how non-governance work flows (developers commit after completing a unit of work)
- Above-appetite branch uses `AskUserQuestion` (ADR-013 compliant), making the decision structured and auditable

**Cons:**
- Introduces a sequencing dependency between any governance skill and `wr-risk-scorer:pipeline`
- A failed risk assessment above appetite requires an explicit user decision mid-skill-run
- Non-interactive contexts (CI, scheduled triggers) must handle the `AskUserQuestion` fail-safe path

### Option B: Stage but leave commit to user (status quo)

**Pros:**
- No new dependencies between skills and risk-scorer
- User retains full control over commit timing
- No risk of above-appetite work being committed without explicit acknowledgement

**Cons:**
- Directly violates the lean release principle — WIP accumulates across multiple skill operations
- Uncommitted work is invisible to the risk pipeline until the user manually commits
- Session-end data loss risk
- Requires the user to remember to commit after each skill operation — easy to forget under time pressure (incidents, retros)

### Option C: Separate commit skill

**Pros:**
- Skills remain single-responsibility (produce artefacts, not pipeline actions)
- Centralises commit-gate interaction in one place

**Cons:**
- Adds a second skill invocation step after every governance skill run — more friction, not less
- The "separate commit skill" is itself a manual step the user must remember
- Effectively the same as Option B from the user's perspective

## Decision Outcome

**Option A is chosen.** The reduction in WIP dwell time and pipeline visibility improvements outweigh the added skill–risk-scorer sequencing dependency.

### Scope

**In scope (this ADR):**
- `packages/itil/skills/manage-problem/SKILL.md`
- `packages/itil/skills/manage-incident/SKILL.md`

**Out of scope for now (to be addressed when those skills are worked):**
- `packages/architect/skills/create-adr/SKILL.md`
- `packages/retrospective/skills/run-retro/SKILL.md`
- `packages/jtbd/skills/update-guide/SKILL.md`
- `packages/risk-scorer/skills/update-policy/SKILL.md`

### Ordering Constraint

All in-scope skills MUST instruct the primary agent to follow this sequence when committing:

1. Stage the completed files with `git add`
2. Delegate to `wr-risk-scorer:pipeline` (subagent_type: `wr-risk-scorer:pipeline`) to assess the staged changes
3. If all scores are within appetite (`RISK_BYPASS: reducing` or score ≤ 4): commit using `git commit`
4. If any score is above appetite: use `AskUserQuestion` to ask the user whether to commit anyway, remediate first, or park the work. Per ADR-013 Rule 6, if `AskUserQuestion` is unavailable, skip the commit and report the uncommitted state clearly in the response.

### Commit Message Convention

| Operation | Format | Example |
|-----------|--------|---------|
| New problem created | `docs(problems): open P<NNN> <title>` | `docs(problems): open P025 foo-bar-baz` |
| Transition to Known Error | `docs(problems): P<NNN> known error — <root cause summary>` | `docs(problems): P023 known error — skills emit no-commit instruction` |
| Problem closed | `docs(problems): close P<NNN> <title>` | `docs(problems): close P023 governance-skills-commit` |
| Review / WSJF re-rank | `docs(problems): review — re-rank priorities` | _(literal)_ |
| Fix implemented (with problem transition) | `fix(<scope>): <description> (closes P<NNN>)` | `fix(itil): remove no-commit instruction (closes P023)` |
| New incident opened | `docs(incidents): open I<NNN> <title>` | `docs(incidents): open I004 login-500s` |
| Incident mitigated | `docs(incidents): I<NNN> mitigated — <mitigation summary>` | `docs(incidents): I004 mitigated — feature flag off` |
| Incident restored | `docs(incidents): I<NNN> restored — <action>` | `docs(incidents): I004 restored — rollback v1.4.3` |
| Incident closed | `docs(incidents): close I<NNN>` | `docs(incidents): close I004` |
| Context analysis report (P101 / ADR-043) | `docs(retros): context analysis YYYY-MM-DD` | `docs(retros): context analysis 2026-04-26` |
| Adopter `docs/problems/` auto-migration (P170 / RFC-002 / ADR-031) | `docs(problems): auto-migrate to per-state subdirectory layout (ADR-031)` + body footer `RISK_BYPASS: adr-031-migration` | _(literal — emitted by `migrate_problems_to_per_state_layout` at adopter Step 0a)_ |
| Upstream-responses check pass (P249 Phase 1 / ADR-062 outbound counterpart) | `chore(problems): check upstream responses — <N> polled, <M> new` | `chore(problems): check upstream responses — 7 polled, 2 new` |

All commit messages must follow the conventional-commit format (`<type>(<scope>): <description>`) and reference the problem or incident ID.

The `docs(retros): context analysis YYYY-MM-DD` row is amended within ADR-014's existing reassessment window (2026-10-16) — no new ADR. It carries the deep-layer `/wr-retrospective:analyze-context` skill output (`docs/retros/<date>-context-analysis.md` plus the directory's `README.md` index when newly scaffolded). Source decision: ADR-043.

The `docs(problems): auto-migrate to per-state subdirectory layout (ADR-031)` row is amended within ADR-014's existing reassessment window — no new ADR. The migration commit is emitted by `migrate_problems_to_per_state_layout` (`packages/shared/lib/migrate-problems-layout.sh`, synced to `packages/itil/lib/`) at adopter Step 0a in `manage-problem` (P170 T8) + `work-problems` (P170 T9). The body footer `RISK_BYPASS: adr-031-migration` is recognised by `packages/risk-scorer/hooks/risk-score-commit-gate.sh` (P170 T11) and by `packages/itil/hooks/lib/readme-refresh-detect.sh` (P265) — the migration commit is a rename-only change that legitimately stages no README refresh, so the same token clears both commit gates via a byte-identical grep. It bypasses the risk-score gate per ADR-031 § Open-Execution Q3 lean (b) and the P165 README-refresh gate per P265. Case-sensitive token match; new commit-message-embedded bypass markers MUST be added to this table + every recognising gate together. Source decisions: ADR-031, ADR-019 precedent (pure-rename + pure-mkdir policy-authorised), ADR-013 Rule 6 (AFK non-interactive authorisation).

The `chore(problems): check upstream responses — <N> polled, <M> new` row is amended within ADR-014's existing reassessment window — no new ADR. The pass commit covers the outbound-responses cache file (`docs/problems/.outbound-responses-cache.json`) plus the appended audit-log entry (`docs/audits/outbound-responses-log.md`), both written by `packages/itil/scripts/check-upstream-responses.sh` (P249 Phase 1). The pass is the outbound symmetric counterpart to ADR-062's inbound discovery audit-log + cache pair; `chore(problems)` mirrors `chore(problems): reconcile README ...` precedent for read-only mechanical passes that write only data files (no source-of-truth changes). Source decisions: ADR-062 audit-log + cache patterns, ADR-024 outbound-report back-link contract.

### Non-Interactive Fail-Safe

When `AskUserQuestion` is unavailable (non-interactive context, `--channels` flag, CI):
- If risk is within appetite: proceed to commit silently
- If risk is above appetite: skip the commit, clearly report "Commit skipped — risk above appetite and user confirmation unavailable. Stage and commit manually when ready."

### Reconciliation as preflight robustness layer (P118, 2026-04-25)

The single-commit-transaction discipline above (Step 11 in manage-problem; Step 7 in transition-problem) covers **per-operation** README staging — the new ticket file + the refreshed README ride the same commit. P094 (refresh-on-create) and P062 (refresh-on-transition) both ship and hold their per-session evidence.

But per-operation enforcement cannot retroactively fix drift introduced by **prior sessions**. If any past session committed a ticket change without staging the README refresh (the Step 11 / Step 7 staging contract was skipped — bug, conflict resolution dropped a file, partial-progress hand-off, etc.), the next session inherits a stale README that no per-operation contract can detect or correct in isolation. P118 captured this drift class with direct evidence: 2026-04-24 the README listed 10 open tickets missing from WSJF Rankings + 2 verifying-as-Open + stale Verification Queue rows, all accumulated despite P094 and P062 both Closed.

The Reconciliation contract closes that gap as a **robustness layer** ON TOP of P094 + P062, not a supersession of either:

1. **`packages/itil/scripts/reconcile-readme.sh`** — a diagnose-only mechanical drift detector (read-only; does NOT mutate the README). Reads `docs/problems/<NNN>-*.<status>.md` files, parses the README's WSJF Rankings + Verification Queue + Closed tables, and emits one structured row per drift entry to stdout (≤150 bytes per ADR-038 progressive-disclosure budget). Exit 0 = clean, 1 = drift detected, 2 = parse error.
2. **`/wr-itil:reconcile-readme`** — agent-applied-edits skill that wraps the script. Step 4 applies row-level Edit operations that **preserve narrative** (the long "Last reviewed" prose paragraph, the Closed-section closure-via free text). Full README regeneration is forbidden — narrative content is human-curated session memory.
3. **Preflight invocation surfaces**:
   - `/wr-itil:manage-problem` Step 0 — invoke the script (cheap mechanical check); halt-with-directive on drift; do NOT auto-apply (edit application lives in the dedicated skill).
   - `/wr-itil:work-problems` Step 0 — invoke the script after the session-continuity pass; auto-apply via the skill in AFK mode (per ADR-013 Rule 6 non-interactive fail-safe) so the orchestrator's Step 3 ranking reads ground truth.
   - Direct user invocation of `/wr-itil:reconcile-readme` when drift is spotted manually.
4. **Excluded surfaces**:
   - `/wr-itil:transition-problem` does NOT invoke the script — P062 already covers transition-time refresh inside the same commit; redundant preflight there would pay the cost on every transition.

The reconciled README rides a dedicated `chore(problems): reconcile README ...` commit per ADR-014's commit-message convention table. It is distinct from any contract-landing or ticket-transition commit so the data correction is attributable to its own SHA.

This sub-rule is amended within ADR-014's existing reassessment window (2026-10-16) — no new ADR.

## Confirmation

- [ ] `packages/itil/skills/manage-problem/SKILL.md` contains no "Do not commit" instruction
- [ ] `packages/itil/skills/manage-incident/SKILL.md` contains no "Do not commit" instruction
- [ ] `packages/itil/skills/manage-problem/SKILL.md` contains the `work → score → commit` ordering sequence
- [ ] `packages/itil/skills/manage-incident/SKILL.md` contains the `work → score → commit` ordering sequence
- [ ] Both SKILL.md files reference `AskUserQuestion` at the above-appetite commit branch point
- [ ] A BATS functional test (mocked `git commit` invocation, not a source-grep) asserts the commit instruction path in at least one in-scope skill — deferred to P012 skill testing harness until that harness is resolved

## Related

- P023: `docs/problems/023-governance-skills-should-commit-completed-work.open.md` — the problem this ADR resolves
- P024: `docs/problems/024-risk-scorer-wip-flag-uncommitted-completed-work.open.md` — complementary risk-scorer improvement; once skills auto-commit, P024 becomes a safety net for cases where auto-commit fails or is skipped
- ADR-013: `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — AskUserQuestion rule at branch points; ADR-014 extends this to the commit-gate branch point
- ADR-011: `docs/decisions/011-manage-incident-skill.proposed.md` — manage-incident skill; its Confirmation criteria do not cover commit behaviour; ADR-014 fills that gap for in-scope skills
- ADR-009: `docs/decisions/009-gate-marker-lifecycle.proposed.md` — gate marker lifecycle; ADR-014's ordering sequence respects the bypass-marker mechanism defined here
- `packages/risk-scorer/hooks/risk-score-commit-gate.sh` — the commit gate hook that enforces score-before-commit
