# Problem 080: No bidirectional update of upstream-reported problems — local lifecycle transitions never propagate back to the reporter

**Status**: Open
**Reported**: 2026-04-21
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M (marginal) — new sibling skill `/wr-itil:update-upstream` (per user direction 2026-04-26) that fires from `manage-problem`/`transition-problem` Step 7 transitions, drafts the lifecycle-update comment, runs it through the P064 risk gate + P038 voice-tone gate, and auto-posts when both gates pass within appetite. Above-appetite triggers `AskUserQuestion` (interactive) or halt-with-report (AFK).

**WSJF**: 1.5 (transitive) — re-rated 2026-04-26 — `(12 × 1.0) / max(M=2, P079_transitive=8, P064=L=4, P038=XL=8) = 12 / 8 = 1.5`. Three transitive dependencies: P079 (this ticket needs the inbound side's matched-local-ticket detection to know which upstream issue maps to which local transition); P064 (risk gate on external comms — required for the comment-posting path); P038 (voice-tone gate — same path). Marginal scope alone would be `(12 × 1.0) / 2 = 6.0` but ships are blocked behind the 3 dependencies.
**Type**: technical

<!-- transitive: M (marginal) → XL (transitive) via P038 -->

## User direction (2026-04-26 interactive AskUserQuestion resolution)

Two of the original three architect-design questions resolved:

- **(a) Skill shape**: **New sibling `/wr-itil:update-upstream`** — matches P071's split-skill direction per ADR-010 amended. Distinct user intent (lifecycle-update vs initial-report) gets its own skill name + autocomplete surface + scoped SKILL.md.
- **(b) Confirmation pattern**: **Risk + voice-tone gated, then auto-comment**. Every transition with a `## Reported Upstream` link fires the update; the drafted comment goes through P064 risk gate + P038 voice-tone gate. Within-appetite → comment posts automatically. Above-appetite → `AskUserQuestion` (interactive) or halt-with-report (AFK). This matches the **same dual-gate pattern P079's assessment pipeline uses for inbound comments** — the external-comms surface is unified across inbound and outbound.
- **(c) P064 gate composition**: same as (b) — gates compose by running both before any post; failure of either blocks. Specific composition shape (gate ordering, short-circuit semantics, audit-log shape) is the architect call when implementing.

## Description

Plugin users who file upstream reports (via our shipped `problem-report.yml` intake templates OR via `/wr-itil:report-upstream` when the local session invokes outbound reporting) get one acknowledgement — the initial issue filing. After that, they're out of the loop.

When a locally-tracked problem with a `## Reported Upstream` section (per `ADR-024` Confirmation criterion 3a) transitions through its lifecycle:

- **Open → Known Error**: root cause confirmed. The reporter would benefit from knowing someone investigated and found the cause.
- **Known Error → Verification Pending (fix released)**: fix is on npm. The reporter can upgrade and verify.
- **Verification Pending → Closed**: fix verified. The reporter knows the loop is closed.

None of these transitions post a comment to the upstream issue. The reporter has to manually poll the upstream tracker (which they reported TO) to see if anything happened. This violates the core trust-and-transparency contract the `plugin-user` persona (`JTBD-301`) depends on.

The user's direction (2026-04-21 interactive): when we work a reported problem, we should have a process to update the reported problem. Currently we don't. That's the gap this ticket closes.

This is the outbound-lifecycle-update leg of the reporter-loop. P079 closes the inbound-discovery leg (new reports visible to maintainer). Together P079 + P080 make the reporter experience end-to-end.

## Symptoms

- Plugin user files a `problem-report.yml` issue. Maintainer acknowledges + triages (manually, because P079 is still open) and opens a local ticket with a `## Reported Upstream` section referencing the upstream issue.
- Maintainer investigates the local ticket over a session or two; root cause is confirmed; local ticket transitions `.open.md` → `.known-error.md`. No comment is posted to the upstream issue. Reporter sees no movement.
- Fix ships via changeset release; local ticket transitions `.known-error.md` → `.verifying.md` with a `## Fix Released` section. No comment is posted to the upstream issue. Reporter has no way to know the fix is available without checking npm.
- Maintainer closes the local ticket after user-side verification; upstream issue is NOT closed on the upstream side (still Open on GitHub despite local `.closed.md`).
- Upstream issue tracker accumulates stale-looking issues ("nothing's happening on these — maintainer abandoned the project?") even though the work landed.
- `gh issue close` requires maintainer to manually walk each `## Reported Upstream` link — error-prone and skipped under load.

## Workaround

Maintainer manually posts a comment to each upstream issue at each lifecycle transition, using a copy-paste template. In practice this drops — the transitions happen during AFK loops or quick sessions and the upstream-update step gets forgotten. Unreliable.

## Impact Assessment

- **Who is affected**:
  - **plugin-user persona** (`JTBD-301` — report-upstream job) — reporter's expected feedback loop breaks after submission. "I filed, nothing happened" is the default experience even when work DID happen.
  - **solo-developer persona** (`JTBD-001`) — maintainer must remember to update each upstream issue at each transition; manual step defeats governance-without-slowing-down.
  - **tech-lead persona** (`JTBD-201`) — audit trail is incomplete: local ticket says "closed", upstream issue says "open"; downstream observer can't reconcile.
  - **plugin-developer persona** (`JTBD-101`) — downstream plugin authors inherit the same gap for their own projects if they adopt our patterns; the pattern mis-teaches the bidirectional contract.
- **Frequency**: every locally-reported-upstream ticket, at every lifecycle transition. Typically 3 transitions per ticket (Open→KE→Verifying→Closed) → 3 missed-update opportunities per ticket.
- **Severity**: High. Directly-observable trust breakage at the reporter-relationship boundary. Sending a silent "fix shipped, please upgrade" comment is high-value, low-effort; NOT sending it is a recurring quality defect.
- **Analytics**: N/A today. Post-fix candidate metrics: (1) ratio of local lifecycle transitions to upstream-issue comments on matched tickets, (2) upstream-issue close rate after local `.closed.md` transitions, (3) reporter-response rate on auto-comments (signal of comment quality).

## Root Cause Analysis

### Structural

`packages/itil/skills/report-upstream/SKILL.md` scope (per ADR-024) is **outbound-initial-filing only**. The skill runs once per local ticket, files the upstream report, and writes the `## Reported Upstream` section with the upstream URL. It does not revisit the upstream issue later.

`packages/itil/skills/manage-problem/SKILL.md` Step 7 (status transitions: Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed) operates on local files only:

- `git mv` the ticket file to the new suffix.
- Edit the Status field.
- Optionally add a `## Fix Released` section (for .verifying.md).
- Re-stage per P057.

No step reads the `## Reported Upstream` section, no step posts to the upstream issue, no step closes the upstream issue on `.closed.md` transition.

### Why it wasn't caught earlier

ADR-024 explicitly scoped report-upstream as initial-filing. The bidirectional surface (lifecycle updates) was noted as a follow-up in ADR-024's Out-of-Scope section but never produced a ticket. P063 (trigger surface for outbound filing) closed the "when to file" gap; the "what happens after filing" gap stayed open.

P070 added dedup-before-filing with a maintainer-annoyance risk evaluator — that infrastructure is exactly what this ticket's upstream-update gate needs, but P070's scope is pre-filing, not post-filing.

### Candidate fix

**Option A: Extend `/wr-itil:report-upstream` with an `--update` mode.**

`/wr-itil:report-upstream --update <local-ticket-path>` reads the ticket's `## Reported Upstream` section, determines the current local status (from filename suffix), generates the appropriate update comment from a template, runs the comment through the external-comms risk gate (P064), and posts if within appetite.

Pros: single skill for all upstream-write surfaces; consistent auth + auth-check logic.
Cons: argument-based subcommand pattern that P071 is migrating AWAY from; would be short-lived.

**Option B: New sibling skill `/wr-itil:update-upstream` (preferred).**

Separate skill, discoverable via `/wr-itil:` autocomplete. Invoked from `manage-problem` Step 7's transition blocks when the local ticket has a `## Reported Upstream` section. Each transition type has its own template:

- **Open → Known Error**: "Root cause identified. Local tracking ticket now at `## Known Error`. Investigation notes: [excerpt]. Fix path: [from ticket's Fix Strategy]. Will update here on release."
- **Known Error → Verification Pending**: "Fix released in `<package>@<version>` (commit `<sha>`). Upgrade + verify when convenient; we'll close this issue after your confirmation OR after a 14-day quiet period (per `P048` Candidate 4 default)."
- **Verification Pending → Closed**: "Closed locally after user-side verification. Closing upstream issue to match. Thanks for the report." + `gh issue close <n>`.

Each update is gated by:
1. **Appropriateness check** — does the local transition add new information for the reporter? (Open→KE: yes, reporter learns root cause exists. KE→Verifying: yes, reporter can upgrade. Verifying→Closed: yes, closes the loop.)
2. **Maintainer-annoyance risk gate** — reuse P070's infrastructure. Cheap updates (one per transition) pass; redundant updates (same status comment already posted) skip. Appetite-driven same as P070.
3. **Voice-and-tone gate** (per ADR-028 amended External-comms gate) — external-facing copy goes through voice-tone review before posting.

Pros: matches P071 / ADR-010 sibling-skill pattern; reuses existing risk + voice gates; cleaner single-responsibility.
Cons: one more skill in the suite.

**Option C: Build the update logic into `manage-problem` transition steps directly.**

Each transition in Step 7 adds an inline "post-to-upstream-if-linked" sub-step.

Pros: no new skill surface; transitions stay a single-commit flow.
Cons: bloats `manage-problem` SKILL.md; couples lifecycle to external-comms; harder to disable upstream updates without disabling transitions.

### Lean direction

**Option B — new sibling skill `/wr-itil:update-upstream`.** Matches the sibling-skill convention under ADR-010 amended + ADR-032 sibling-pattern. Reuses:
- P070's maintainer-annoyance risk evaluator (composes via the P064 + ADR-028 external-comms gate).
- ADR-028 amended's voice-tone + risk gate (the same gate P073 + P074 feed into).
- `/wr-itil:report-upstream`'s auth + preference-order logic for channel resolution.

Architect call required at implementation time to:
1. Confirm Option B vs A/C.
2. Decide the close-on-verification policy: auto-close after user verification? After N-day quiet period? Require explicit user opt-in?
3. Decide whether `update-upstream` auto-invokes from `manage-problem` transition steps OR is user-triggered only.
4. Decide whether a NEW ADR is needed or an amendment to ADR-024 (lean: amendment — this is the bidirectional extension ADR-024 explicitly scoped out).

### Related sub-concerns

**Sub-concern 1**: auto-invoke vs manual. If `manage-problem` transitions auto-fire the update, the risk gate must be strict — a spammy auto-update is worse than no auto-update. Lean: auto-invoke for KE→Verifying and Verifying→Closed (high-value updates); leave Open→KE as user-initiated (investigation notes may be partial and want review before posting).

**Sub-concern 2**: multiple `## Reported Upstream` entries. A local ticket may accumulate multiple upstream references if the same problem was filed to multiple trackers. The update logic should post to EACH linked upstream issue, not just the first. Risk gate composes per-channel.

**Sub-concern 3**: historical catch-up. Existing `.verifying.md` / `.closed.md` tickets with `## Reported Upstream` sections need retroactive updates on first deployment. A one-shot migration pass would post "catching up: this was resolved in version X" to each unclosed upstream issue. Architect review to decide whether migration is in-scope for this ticket or a sibling.

**Sub-concern 4**: downstream-scaffolded trackers. When a downstream project uses ADR-036-scaffolded intake templates, the downstream maintainer handles bidirectional updates on their side. Our `update-upstream` only acts when the local ticket's `## Reported Upstream` references OUR outbound path (i.e. this repo filed to an upstream we depend on). This scope boundary mirrors P079's channel scoping.

### Investigation Tasks

- [ ] Architect review: pick Option A / B / C. ADR shape (amend ADR-024 vs new ADR).
- [ ] Draft the `update-upstream` SKILL.md (or the ADR-024 amendment per architect).
- [ ] Define the update-template shape for each transition type (Open→KE, KE→Verifying, Verifying→Closed).
- [ ] Compose with P064 + ADR-028 amended external-comms gate (voice-tone + risk). Architect review decides gate ordering.
- [ ] Integrate with `manage-problem` Step 7 transition blocks: each transition checks for `## Reported Upstream`; if present, invokes `update-upstream`.
- [ ] Integrate with `work-problems` AFK orchestrator: transitions fired by iteration subagents should still post upstream updates (non-interactive default per ADR-013 Rule 6 when the risk gate passes).
- [ ] Bats doc-lint assertions per ADR-037: skill contract, template presence per transition, risk-gate composition, policy-decision traceability.
- [ ] Reuse P070's maintainer-annoyance risk evaluator — confirm composability; architect review decides whether extract-to-shared-lib or copy-adapt.
- [ ] Historical catch-up: one-shot migration pass OR runtime first-fire detection. Architect decides.
- [ ] End-to-end test: transition a test ticket with a synthetic `## Reported Upstream`; confirm the upstream issue receives a comment matching the transition template.

## Related

- **P079** (`docs/problems/079-no-inbound-sync-of-upstream-reported-problems.open.md`) — sibling concern. Inbound-discovery leg; together P079 + P080 close the reporter-loop end-to-end.
- **P055** (`docs/problems/055-no-standard-problem-reporting-channel.closed.md`) — shipped `/wr-itil:report-upstream` (Part B); this ticket adds the bidirectional-update mode the original skill scoped out.
- **P063** (`docs/problems/063-manage-problem-does-not-trigger-report-upstream-for-external-root-cause.verifying.md`) — outbound-initial-filing trigger surface. This ticket adds the outbound-lifecycle-update trigger surface.
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-comms.open.md`) — external-comms risk gate the upstream-update comment MUST compose through (per ADR-028 amended).
- **P067** (`docs/problems/067-report-upstream-classifier-is-not-problem-first.open.md`) — classifier-shape dependency; bidirectional updates follow the same problem-first copy shape.
- **P070** (`docs/problems/070-report-upstream-does-not-check-for-existing-upstream-issues.open.md`) — maintainer-annoyance risk evaluator this ticket reuses for the update-gate.
- **P072** (`docs/problems/072-no-persona-models-external-repo-reporter.verifying.md`) — `plugin-user` persona + `JTBD-301` this ticket serves.
- **ADR-024** (`docs/decisions/024-cross-project-problem-reporting-contract.proposed.md`) — outbound-initial-filing contract this ticket's amendment (or new paired ADR) extends to bidirectional.
- **ADR-028** (`docs/decisions/028-external-comms-gate.proposed.md` — amended) — voice-tone + risk gate for external-facing copy the update comments pass through.
- **ADR-010** (`docs/decisions/010-skill-naming.proposed.md` — amended) — sibling-skill naming convention; new `/wr-itil:update-upstream` follows this pattern.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 6 non-interactive fail-safe applies to AFK-transition-triggered upstream updates.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — upstream-update commit + post action both belong in the transition commit's ownership.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — foreground synchronous for user-initiated updates; AFK iteration isolation wrapper for orchestrator-initiated updates during transitions.
- **JTBD-001**, **JTBD-101**, **JTBD-201**, **JTBD-301** — personas whose end-to-end promise this ticket serves.
