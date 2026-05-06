# Problem 119: Agent bypasses `/wr-itil:manage-problem` Step 2 duplicate-check by writing tickets directly to `docs/problems/`

**Status**: Closed
**Reported**: 2026-04-25
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: S
**WSJF**: 0 (Verification Pending — excluded from dev-work ranking per ADR-022)
**Type**: technical

> Surfaced 2026-04-25 in `/wr-retrospective:run-retro` Step 4b Stage 1 as a codification candidate. This session shipped three duplicate problem tickets (P119/P120/P121, since deleted) by writing directly to `docs/problems/` via the Write tool instead of invoking `/wr-itil:manage-problem`. All three were near-perfect duplicates of P038 and P064 — both Open since 2026-04-17 with ADR-028 already landed 2026-04-21 — and were caught only after an unrelated user prompt triggered a manual grep that surfaced the existing tickets.

## Description

`/wr-itil:manage-problem` Step 2 ("For new problems: Check for duplicates FIRST") is the canonical duplicate-prevention surface for this repo's problem backlog. The Step 2 contract: extract keywords, grep `docs/problems/` filenames + bodies, present matches via `AskUserQuestion`, switch to update flow if the user picks an existing ticket. This works correctly when the skill is invoked.

The gap is structural: there is no enforcement that `docs/problems/<NNN>-<title>.open.md` files MUST be created via the skill. The agent can call the Write tool directly with any path, and no PreToolUse hook intercepts new-file creation under `docs/problems/`. The skill is advisory by convention; the enforcement layer is missing.

This produces a recurring duplicate-creation pattern: the agent observes something codify-worthy mid-task (e.g. inside a retrospective, a session-wrap summary, or a long investigation), instinctively reaches for the Write tool to capture it inline, ships a `.open.md` file, and only later discovers the concept was already tracked. Cleanup is mechanical (file deletes + evidence-merge) but the duplicates corrupt the audit trail in flight, distort the WSJF queue if not caught immediately, and burn user attention on triage.

## Symptoms

- New `.open.md` files appear in `docs/problems/` whose titles overlap concept-space with existing Open / Known Error tickets, with no record of a Step 2 grep having run.
- `docs/problems/README.md` Last-reviewed line records the new ticket but with no audit-trail evidence that duplicate-check fired.
- Cleanup commits (`rm` of just-created tickets + evidence-append to surviving tickets) appear in the same session as the create, indicating the duplicate was caught reactively not preventively.
- The agent's session log shows direct Write calls to `docs/problems/<NNN>-*.open.md` rather than `Skill { wr-itil:manage-problem ... }` invocations.
- Observed 2026-04-25: P119/P120/P121 created via Write, deleted within the same conversation turn pair after user prompt led to manual grep that found P038/P064 as the actual home.

## Workaround

Manual discipline: the agent must remember to invoke `/wr-itil:manage-problem` for any new ticket creation. Brittle — relies on the agent recalling the contract every time, which empirically fails in retrospective / wrap-up contexts where the agent is already mid-thought on a captured observation. The same memory failure mode P078 covers for user-correction-triggered tickets applies here for agent-observation-triggered tickets.

## Impact Assessment

- **Who is affected**:
  - **solo-developer persona** (JTBD-001 — enforce governance without slowing down) — duplicate triage shifts to the user when the agent ships duplicates that should have been caught at create-time.
  - **tech-lead persona** (JTBD-201 — restore service fast with audit trail) — the WSJF queue temporarily lies when duplicates are present; ranking decisions made on a duplicated queue are not defensible post-hoc.
  - **AFK orchestrator (JTBD-006)** — work-problems iterating a backlog with duplicates wastes iteration budget on near-identical work; cleanup-after-the-fact compounds with the iteration cost.
- **Frequency**: every codify-worthy observation the agent encounters mid-task that doesn't route through the skill. Empirically: 3 duplicates in one session (2026-04-25).
- **Severity**: Moderate. Not a runtime breakage; not a release-impact issue; but a recurring backlog-quality defect that corrodes the WSJF queue's signal-to-noise ratio. The trust loss is comparable to P078's.
- **Analytics**: 2026-04-25 session — 3 duplicates created, all 3 deleted within the same conversation turn pair after user prompt triggered manual grep. Cleanup cost: 3 file deletes + 2 evidence-append edits to surviving tickets (P038, P064) + retroactive duplicate-grep across the docs/problems/ surface.

## Root Cause Analysis

### Structural

`packages/itil/skills/manage-problem/SKILL.md` Step 2 is the canonical duplicate-prevention surface, but it only fires when the skill is invoked. There is no PreToolUse hook in `packages/itil/hooks/` that intercepts Write to new files under `docs/problems/`.

The agent's default capture instinct in retrospective / wrap-up contexts is to reach for Write directly — particularly when capturing multiple related observations in quick succession (the 2026-04-25 P119/P120/P121 case: three back-to-back Write calls without a single Skill invocation between them). This is the same default-action pattern P085 covers for the prose-ask anti-pattern — once the agent has decided what it wants to write, it skips the gating step.

The hook-based enforcement pattern is well-established for similar concerns in this repo:
- `packages/voice-tone/hooks/voice-tone-enforce-edit.sh` gates Edit/Write to copy-bearing files on a voice-tone review marker.
- `packages/jtbd/hooks/jtbd-enforce-edit.sh` gates Edit/Write to project files on a JTBD review marker.
- `packages/risk-scorer/hooks/risk-policy-enforce-edit.sh` gates Edit/Write to RISK-POLICY.md on a risk-policy review marker.

A parallel `packages/itil/hooks/manage-problem-enforce-create.sh` matching `PreToolUse` on `Write` to `docs/problems/<NNN>-*.<status>.md` (when the file does not yet exist) would close the gap with the same shape. The marker would be set by the manage-problem skill itself when Step 2's grep completes.

### Investigation Tasks

- [x] Architect review: confirmed hook shape (PreToolUse Write matcher on `docs/problems/` new-file path) and marker contract (per-session, set by manage-problem Step 2 completion). Decision: Write only — Edit-to-existing is a different concern (transition-problem skill).
- [x] Marker scope: per-session, not per-grep. Architect direction A — single skill invocation may write multiple tickets (Step 4b multi-concern split); per-grep would block consecutive Writes. Marker location: `/tmp/manage-problem-grep-${SESSION_ID}` (parallel to existing `/tmp/jtbd-reviewed-*`, `/tmp/voice-tone-reviewed-*` markers). ADR-009 covers session-scoped /tmp markers; no amendment needed.
- [x] New-file detection: `[ ! -f "$FILE_PATH" ]` confirmed as the natural check. Existing-file Write (overwrite) bypasses the gate so the same skill can re-render a transitioned ticket without tripping itself.
- [x] Failure-mode UX: `permissionDecision: deny` with message naming the skill (`/wr-itil:manage-problem`) and the contract (Step 2 grep + AskUserQuestion). Terse + actionable per ADR-013 Rule 1; not progressive-disclosure-shaped (ADR-038 governs UserPromptSubmit prose, not deny messages).
- [x] Implemented `packages/itil/hooks/manage-problem-enforce-create.sh` and registered in `packages/itil/hooks/hooks.json` PreToolUse:Write matcher.
- [x] Bats coverage added at `packages/itil/hooks/test/manage-problem-enforce-create.bats` — 16 behavioural assertions covering deny path, allow path, multi-concern split compatibility, README exemption, Edit-flow exemption, status-suffix coverage (open/known-error/verifying/parked), ADR-031 forward-compat (subdirectory layout), and marker hygiene.
- [x] Updated `packages/itil/skills/manage-problem/SKILL.md` Step 2 with substep 7 (write marker after grep) and "Hook contract (P119)" callout warning against manual marker-setting bypass.

### Fix Strategy

**Shape**: hook (PreToolUse Write matcher on `docs/problems/<NNN>-*.<status>.md` new-file paths) gating on a session marker set by manage-problem Step 2 completion. Parallel to existing `packages/{voice-tone,style-guide,jtbd}/hooks/*-enforce-edit.sh` pattern; reuses the `lib/review-gate.sh` infrastructure (or a sibling `lib/create-gate.sh` if the marker semantics differ enough).

**Target files (likely)**: new `packages/itil/hooks/manage-problem-enforce-create.sh`, update `packages/itil/hooks/hooks.json` to register the PreToolUse Write matcher, optionally extend `packages/itil/hooks/lib/` with a `create-gate.sh` helper, update `packages/itil/skills/manage-problem/SKILL.md` Step 2 to set the marker after grep, new bats test under `packages/itil/hooks/test/`.

**Marker placement**: aligns with the existing review-gate.sh marker convention — per-session under `~/.claude/.../session/<id>/`. Cleared at session boundaries.

**Out of scope**: Edit gating on existing tickets (handled by status-transition contract elsewhere). Gating on `Write` to `docs/problems/README.md` (the README is regenerated by manage-problem Steps 5/6/7 and write-gating it would be a chicken-and-egg).

## Fix Released

Released in `@windyroad/itil` next patch (queued via `.changeset/wr-itil-p119-manage-problem-enforce-create.md`). Awaiting user verification.

**Mechanism shipped**:

- `packages/itil/hooks/manage-problem-enforce-create.sh` — PreToolUse:Write hook. Matches `docs/problems/` paths with numeric-prefix basenames (NNN-…). Allow-lists `README.md` and existing files. Issues `permissionDecision: deny` with a message directing the agent to `/wr-itil:manage-problem` when the per-session Step-2 marker is absent.
- `packages/itil/hooks/lib/create-gate.sh` — sibling helper of `lib/review-gate.sh`. Provides `check_create_gate`, `mark_step2_complete`, `create_gate_deny`. Distinct semantics (no TTL drift detection), kept separate from review-gate.sh per architect direction.
- `packages/itil/hooks/hooks.json` — registers the new PreToolUse:Write matcher.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 — substep 7 added ("write the create-gate marker after the grep completes") plus a "Hook contract (P119)" callout explaining the deny shape.
- `packages/itil/hooks/test/manage-problem-enforce-create.bats` — 16 behavioural assertions covering deny path, allow path, multi-concern split (Step 4b), README exemption, Edit-flow exemption, status-suffix coverage (open / known-error / verifying / parked), ADR-031 forward-compat, marker hygiene, and parse-error fail-open parity with sibling hooks.

**Verification path**: in any future session, attempt to `Write` a new file to `docs/problems/<NNN>-<title>.open.md` without first invoking `/wr-itil:manage-problem` Step 2. The hook should emit a `permissionDecision: deny` blocking the write and naming the skill in the message. After invoking the skill (which runs the grep and writes the marker as Step 2 substep 7), subsequent Writes to new ticket paths in the same session should pass.

**Architect verdict**: APPROVED. **JTBD verdict**: PASS. **Tests**: 38/38 itil hooks; 876/876 full suite.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P078 (assistant does not offer ticket on user correction) — same general "agent should route through manage-problem rather than handling tickets ad-hoc" gap class but different trigger (user correction vs. agent self-observation). Both fix paths are hook-based per ADR-024-style ownership; can ship independently.

## Related

- **P078** (`docs/problems/078-assistant-does-not-offer-problem-ticket-on-user-correction.open.md`) — sibling gap class. P078's trigger is user correction; this ticket's trigger is agent self-observation. Both warrant hook-based enforcement; P078 is on `UserPromptSubmit` / `Stop`, this one is on `PreToolUse:Write`.
- **P085** (`docs/problems/085-assistant-asks-when-obvious-and-uses-prose-instead-of-askuserquestion.verifying.md`) — same "agent default-action skips a contract step" pattern; P085 ships the prose-ask hook + CLAUDE.md combination as a precedent.
- **P016** (`docs/problems/016-manage-problem-should-split-multi-concern-tickets.verifying.md`) — concern-boundary analysis is the inverse problem: a single Write covering multiple concerns. This ticket's hook would also catch multi-concern bypass since a direct Write skips Step 4b's split prompt.
- **P070** (`docs/problems/070-report-upstream-does-not-check-for-existing-upstream-issues.open.md`) — same duplicate-prevention concern on a different surface (upstream issue creation). Different scope, same shape.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 — the duplicate-check this hook gates against.
- `packages/itil/hooks/hooks.json` — registration target.
- `packages/voice-tone/hooks/voice-tone-enforce-edit.sh`, `packages/jtbd/hooks/jtbd-enforce-edit.sh`, `packages/risk-scorer/hooks/risk-policy-enforce-edit.sh` — precedent enforce-gate hook shapes.
- `packages/itil/hooks/lib/` (if it exists; otherwise create) — host for any shared helper.
- ADR-009 (gate marker lifecycle) — the marker contract this hook follows.
- ADR-013 Rule 1 (AskUserQuestion for governance decisions) — the deny message should direct the agent to invoke the skill where Step 2 fires AskUserQuestion if duplicates exist.
- ADR-014 (governance skills commit their own work) — this hook does not commit; manage-problem already does.
- 2026-04-25 session evidence: this retro's `/wr-retrospective:run-retro` invocation; concrete duplicates were P119/P120/P121 (deleted) of P038/P064; commit 80e8e72 captures the cleanup-evidence pattern (update-over-create after Step 2 grep).
