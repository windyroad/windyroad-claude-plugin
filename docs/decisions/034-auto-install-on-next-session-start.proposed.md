---
status: "proposed"
date: 2026-04-21
human-oversight: rejected-pending-supersede
supersede-ticket: P299
oversight-date: 2026-05-26
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-07-21
---

# Auto-install on next session start — SessionStart hook + per-project consent gate

## Context and Problem Statement

When `@windyroad/*` plugins publish new versions (e.g. `@windyroad/itil@0.9.0` shipping P062 + P063 + P068 + the ADR-028 / ADR-032 / ADR-031 decisions this week), adopter projects do NOT automatically pick up the new code. The adopter must remember to run `/install-updates` in each sibling project. In a 6-project sibling set (`windyroad`, `addressr`, `addressr-mcp`, `addressr-react`, `bbstats`, any future adopter), this is manual, repetitive, easy to forget, and silently lets plugin drift accumulate across projects until the user notices (often via a bug caused by old-vs-new behaviour diverging).

The solo-developer persona's documented pain point captures this: *"plugin-version drift across sibling projects on the same machine... manual, repetitive, and easy to forget"*. JTBD-001's "reviews complete in under 60 seconds so they don't break flow" cannot deliver when the user has to track plugin versions in their head across N projects.

P045's pinned direction (2026-04-20): **deferred install on next session start**. Not mid-session (mid-session install would mutate `node_modules` and plugin code while the user is mid-task, risking state corruption — and ADR-032's AFK carve-out would make it unsafe in AFK orchestrator sessions anyway). Not at release drain time (release drain should not mutate adopter repos). At **session start** — a natural cleavage point where the user is initiating work, no task is in flight, and any update surfaces on the first turn of the new session.

This ADR separates *what* `/install-updates` does (governed by ADR-030 repo-local skills) from *when* it fires (governed by this ADR). Sibling to ADR-030; not an extension.

## Decision Drivers

- **JTBD-001** (Enforce Governance Without Slowing Down) — primary. "Under 60 seconds" fails when the user is tracking plugin versions across 6 sibling projects by hand.
- **JTBD-005** (Invoke Governance Assessments On Demand) — secondary. The "must not leave task context" constraint motivates the next-session trigger (update check at session start, not mid-session).
- **JTBD-101** (Extend the Suite with New Plugins) — plugin-developer persona; the "slow test-fix-release cycles" pain point benefits when adopters pick up releases without manual intervention.
- **JTBD-003** (Compose Only the Guardrails I Need) — auto-install is opt-in per project, so composability is preserved.
- **JTBD-006** (Progress the Backlog While I'm Away) — AFK carve-out mirrors ADR-032; AFK-launched sessions defer the update check.
- **P045** — driver ticket.
- **ADR-030** — what `/install-updates` does (repo-local skill + sibling discovery + consent gate on individual siblings).
- **ADR-004** — project-scoped plugin install by default. Drives per-project consent scope.
- **ADR-032** — user-initiated background capture pattern applies to the optional auto-install path.

## Considered Options

1. **SessionStart hook + per-project consent marker (chosen)** — P045's pinned direction shaped by architect review. Hook lives in `packages/itil/hooks/session-start-update-check.sh` (per ADR-030 §4 and ADR-032 precedent — hooks live in plugin packages). Consent marker per project at `.claude/.auto-install-consent` (per ADR-004 isolation). Absent consent → systemMessage only (ADR-013 Rule 6 fail-safe). Present consent → background-capture `/install-updates` invocation per ADR-032 (ADR-013 Rule 5 policy-authorised). AFK sessions defer the check entirely (ADR-032 AFK carve-out mirror).

2. **Always-auto-install silently without per-project consent** — rejected. Violates ADR-004 (project-scoped install); violates ADR-013 Rule 6 by silently mutating adopter repos without explicit authorisation.

3. **SystemMessage-only; no background-install path** — rejected. Solves detection but not the "forgot to run `/install-updates`" pain. User still has to remember to invoke the skill; the reminder is marginal improvement over status quo. Architect agreed: the consent-gated auto-install is worth the complexity for the 6-project-sibling-set use case.

4. **Status quo — manual `/install-updates`** — rejected per P045. Fails JTBD-001 "under 60 seconds".

5. **Per-user consent marker (`~/.claude/.windyroad-auto-install-consent`)** — rejected per architect. A single consent granted in project A silently applies to project B; bypasses ADR-004's "install here, use here" intent and ADR-030 §3's per-project consent-gate principle. Can be revisited as a follow-up ticket if per-project friction is observed.

6. **Mid-session polling for outdated plugins** — rejected. Violates JTBD-005's "must not leave task context"; mid-session installs risk state corruption; doesn't compose with ADR-032's AFK carve-out.

## Decision Outcome

**Chosen option: Option 1** — SessionStart hook + per-project consent marker + AFK carve-out.

### Hook contract

- **Location**: `packages/itil/hooks/session-start-update-check.sh` — fires on SessionStart event. Ships with `@windyroad/itil` per ADR-030 §4 (no repo-local hooks) and ADR-032 precedent (hooks in plugin packages).
- **Detection**: queries npm registry (or uses cached npm metadata if available) for the latest versions of each `@windyroad/*` plugin installed in the project's `package.json` / `.claude-plugin/plugin.json` set. Bounded to one network round-trip per `@windyroad/*` plugin, per session start — sub-second in typical broadband.
- **Trigger condition**: at least one installed `@windyroad/*` plugin has a newer version on npm.
- **AFK detection**: the hook reads an AFK-launch envvar (set by `work-problems` when it spawns its orchestrator; exact envvar name tracked in ADR-019's update or in P045's execution ticket). If AFK is detected, the hook returns early with NO action and NO systemMessage — update check defers to the next user-initiated session. This carve-out mirrors ADR-032's AFK carve-out.

### Branch behaviour (per ADR-013 Rule 5 / Rule 6 compliance)

**Consent marker PRESENT** (`.claude/.auto-install-consent` exists in the project root):
- Per **ADR-013 Rule 5** (policy-authorised silent proceed) — the user's prior consent authorises the hook to proceed silently.
- Hook invokes `/install-updates` via the ADR-032 background-capture pattern (user-initiated session; background is allowed per ADR-032). Background subagent runs the full `/install-updates` skill flow.
- On completion, background subagent writes a receipt file at `docs/problems/open/<NNN>-auto-install-receipt-<date>.md` (or ADR-031-post-migration path) summarising: which plugins updated, which stayed, any errors. User sees the receipt at next `manage-problem review` or opens it directly.
- If `/install-updates` hits any AskUserQuestion branch (e.g. sibling-set confirmation per ADR-030 §3), ADR-032's deferred-question resumption contract applies — the background subagent writes a pending-questions artefact; next UserPromptSubmit hook surfaces it.

**Consent marker ABSENT** (default state for every project until the user opts in):
- Per **ADR-013 Rule 6** (non-interactive fail-safe) — no silent mutation is authorised.
- Hook emits a systemMessage to the session at turn 0: `Detected outdated @windyroad/* plugin(s): <plugin@old → @new list>. Run /install-updates to apply (or grant auto-install consent at end of /install-updates to skip this prompt next session).`
- No mutation. User explicitly invokes `/install-updates` if they want the update.

### Consent-granting path (first-time opt-in)

The consent marker can ONLY be created by an interactive path — never by the SessionStart hook itself (the hook runs before any user input is possible).

- At the end of a successful `/install-updates` run, the skill asks via `AskUserQuestion`:
  > `header: "Auto-install on session start?"`
  > `question: "Skip this prompt next session by granting auto-install consent for this project? You can revoke by deleting .claude/.auto-install-consent."`
  > Options: `Grant consent (recommended)`, `Not now (keep manual trigger)`, `Ask me again next time`.
- On `Grant consent`, the skill writes `.claude/.auto-install-consent` with: today's date, the plugin list at consent time, a short YAML header explaining what the marker authorises.
- On `Not now`, the skill writes nothing; future sessions re-emit the systemMessage.
- On `Ask me again next time`, the skill writes a short-lived `/tmp/install-updates-deferred-<project-hash>` marker that suppresses the systemMessage for this session only; next session re-prompts.

### Observable artefacts

Per ADR-026 grounding:

- Auto-install receipt at `docs/problems/open/<NNN>-auto-install-receipt-<YYYY-MM-DD>.md` with the plugin version deltas + any errors. File-based audit trail.
- Consent marker at `.claude/.auto-install-consent` — its presence is the observable policy-authorisation signal.
- SystemMessage output (when absent consent) is the fallback signal.

## Scope

### In scope (this ADR)

- New SessionStart hook at `packages/itil/hooks/session-start-update-check.sh`.
- Consent-grant AskUserQuestion addition to the end of `/install-updates` skill (`.claude/skills/install-updates/SKILL.md`).
- Consent marker file format at `.claude/.auto-install-consent`.
- AFK-launch detection in the hook.
- Background-capture invocation path for auto-install (per ADR-032).
- Bats doc-lint for the hook + the `/install-updates` consent-grant addition.
- Plugin manifest (`packages/itil/.claude-plugin/plugin.json`) gains the SessionStart hook entry.

### Out of scope (follow-up tickets or future ADRs)

- Per-user consent marker. Revisit if per-project friction is observed across the 6-sibling set.
- Auto-install in AFK orchestrator sessions. The AFK carve-out is explicit; changing it requires a future ADR.
- Cross-project consent propagation (one consent applies to all siblings). Not needed if per-project is the default.
- Non-`@windyroad/*` plugins. This ADR is scoped to the Windy Road suite; other plugins use their own install mechanisms.
- Update-check network budget (e.g. caching npm metadata across sessions). Sub-second per round-trip is already acceptable; optimisation is a follow-up if latency becomes a concern.

## Consequences

### Good

- P045 closes at design level. Plugin drift across sibling projects no longer depends on user memory.
- Per-project consent preserves ADR-004 isolation; each project explicitly opts in.
- ADR-013 Rule 5 + Rule 6 branches are explicit; no silent mutation without authorisation.
- AFK carve-out preserves ADR-032 + ADR-018 + ADR-019 orchestration invariants.
- Consent-grant is interactive and auditable (`.claude/.auto-install-consent` is a checked-in-or-gitignored file the user controls).
- Receipt artefact keeps the audit trail; JTBD-201 audit-trail outcome preserved.
- Hook location in `packages/itil/hooks/` matches ADR-030 §4 and ADR-032 precedent — no new hook-distribution channel.

### Neutral

- SessionStart hook adds a network round-trip per `@windyroad/*` plugin on every session start. Bounded by plugin count (currently ~9 plugins); sub-second in aggregate.
- Consent marker is per-project; a user running many sibling projects may grant consent 6+ times. Acceptable; the alternative (per-user) breaks ADR-004.
- The auto-install receipt sits in `docs/problems/open/` — one more artefact type in the backlog. Cleaned up at `manage-problem review` or manually.
- `/install-updates` skill gets one additional AskUserQuestion at the end of its run. Adds one turn on first consent grant per project; zero turns on subsequent sessions under consent.

### Bad

- **First-run surprise for adopters**: projects that install `@windyroad/itil` at the version that ships this hook will see the hook fire on the next session start with no prior warning. Mitigation: the first emission is a systemMessage (no mutation); user sees exactly what the hook does before granting any consent.
- **Registry network dependency**: the hook queries npm metadata; offline environments see slower session starts or missed update detection. Mitigation: the hook caches the last successful check's result for 1 hour (tunable); on network failure, the hook falls through silently (no systemMessage, no mutation) per Rule 6 fail-safe.
- **Receipt artefact clutter**: `docs/problems/open/*-auto-install-receipt-*.md` accumulates one per auto-install event. Mitigation: receipts older than 14 days auto-archive to `docs/problems/closed/` during `manage-problem review` (extend ADR-031 auto-archive scope; follow-up).
- **Pending-questions chain**: if `/install-updates` hits the sibling-set consent AskUserQuestion (ADR-030 §3) during background execution, the ADR-032 deferred-question artefact fires. User's next prompt surfaces the sibling consent question. Acceptable; ADR-032's contract handles it cleanly. **Sibling-marker coexistence (P120, 2026-04-25)**: `.claude/.install-updates-consent` (P120 / ADR-030 amendment) is a sibling marker governing the Step 6 sibling-set consent cache for the manual `/install-updates` surface — same per-project, gitignored, stable-answer-cache shape, but a separate file with separate semantics. The two markers are independent: presence of one does not imply the other. ADR-034's Rule 5 silent-proceed authorisation (`.claude/.auto-install-consent`) is unchanged; P120's cache-hit on `.claude/.install-updates-consent` resolves the ADR-030 §3 sibling-set consent and short-circuits the pending-questions chain when both markers are present.
- **Auto-install + TDD state interaction**: under `@windyroad/tdd`'s TDD state enforcement (ADR-005 + ADR-025), the background `/install-updates` invocation runs skill/hook file edits that may trigger TDD state transitions. The receipt must cite which test states were affected. This is an implementation detail tracked under P045 execution; the ADR flags it here so the execution ticket catches it.

## Confirmation

### Source review (at implementation time)

- `packages/itil/hooks/session-start-update-check.sh` exists and ships with `@windyroad/itil`.
- `packages/itil/.claude-plugin/plugin.json` declares the SessionStart hook.
- `.claude/skills/install-updates/SKILL.md` (repo-local per ADR-030) gains an "Auto-install consent grant" step at the end of its flow with the AskUserQuestion wording from this ADR.
- Consent marker file format documented in the ADR and the skill.
- AFK-launch detection uses the envvar name documented in ADR-019 (or established in P045 execution if not yet standardised).

### Bats structural tests

- `packages/itil/hooks/test/session-start-update-check.bats`:
  - Consent marker present + outdated plugin detected → hook emits no systemMessage (Rule 5 silent) and invokes `/install-updates` via background.
  - Consent marker absent + outdated plugin detected → hook emits systemMessage with the expected wording; no mutation.
  - No outdated plugins → no systemMessage; hook returns cleanly.
  - AFK envvar set → hook returns early regardless of other state; no detection, no systemMessage.
  - Registry network failure → hook falls through silently; no stale systemMessage; cached result used if fresh.
- `.claude/skills/install-updates/test/install-updates-consent-grant.bats`:
  - Skill's consent-grant AskUserQuestion wording is present.
  - Skill writes `.claude/.auto-install-consent` on `Grant consent`.
  - Skill does NOT write the marker on `Not now` or `Ask me again next time`.

### Behavioural replay (at implementation time)

1. Fresh project without `.claude/.auto-install-consent`. Publish a new `@windyroad/itil` version. Start a new session in the project. Verify: systemMessage appears at turn 0; no mutation.
2. Invoke `/install-updates` in that session. Verify: skill runs; on success, asks to grant consent; on `Grant consent`, writes `.claude/.auto-install-consent`.
3. Start a new session in the same project. Verify: no systemMessage; hook invokes `/install-updates` via background; receipt artefact appears in `docs/problems/open/`.
4. Delete the consent marker. Start a new session. Verify: systemMessage reappears; no mutation.
5. Run a session with the AFK envvar set. Verify: hook fires but returns early; no systemMessage; no mutation.
6. Offline session (no network). Verify: hook falls through silently; no stale systemMessage.

## Pros and Cons of the Options

### Option 1: SessionStart hook + per-project consent (chosen)

- Good: preserves ADR-004 isolation; explicit Rule 5/6 branches; AFK carve-out; ADR-032-compatible.
- Bad: per-project consent must be granted 6+ times in sibling sets; receipt artefact clutter until archiving.

### Option 2: Always-silent-auto-install

- Good: zero-friction user experience.
- Bad: violates ADR-004 + ADR-013 Rule 6; mutates adopter repos without authorisation.

### Option 3: SystemMessage-only

- Good: simplest design; no mutation path at all.
- Bad: doesn't actually solve "forgot to run /install-updates"; marginal over status quo.

### Option 4: Status quo

- Good: zero design cost.
- Bad: P045 isn't closed; JTBD-001 "under 60 seconds" still fails across sibling-set plugin drift.

### Option 5: Per-user consent

- Good: grant once, applies everywhere.
- Bad: bypasses ADR-004; single-grant implicit approval across unrelated projects is a security/trust surface expansion.

### Option 6: Mid-session polling

- Good: catches updates faster.
- Bad: violates JTBD-005 "must not leave task context"; risks state corruption during active work.

## Reassessment Criteria

Revisit this decision if:

- Opt-in consent rate stays near zero 3+ months post-release. Signal: per-project consent is too much friction; consider per-user consent with namespace.
- Unintended auto-install fires in AFK-launched session. Signal: AFK detection envvar is unreliable; strengthen detection or revert the carve-out.
- `/install-updates` background invocation hits AskUserQuestion resumption at high frequency (>50% of auto-install runs). Signal: the sibling-set consent gate is fighting the auto-install flow; revisit ADR-030 §3's per-sibling consent grain.
- Registry network dependency produces visible session-start latency complaints. Signal: the 1-hour cache TTL needs extending or the detection needs a slower async path.
- Receipt artefact clutter in `docs/problems/open/` overwhelms the backlog. Signal: the auto-archive follow-up is overdue; prioritise it.
- The AFK carve-out envvar convention changes across Claude Code versions. Signal: the detection mechanism needs a different signal (e.g. orchestrator-wrote-marker-file).
- Per-project consent scope proves insufficient (e.g. users want suite-wide consent). Signal: revisit per-user option 5 with namespacing.

## Related

- **ADR-030** (Repo-local skills for workflow tooling) — what `/install-updates` does; this ADR is sibling, governing when.
- **ADR-032** (Governance skill invocation patterns) — user-initiated background capture; AFK carve-out mirrored here.
- **ADR-013** (Structured user interaction) — Rule 5 (policy-authorised) + Rule 6 (non-interactive fail-safe) both cited explicitly.
- **ADR-004** (Project-scoped plugin install by default) — drives per-project consent scope.
- **ADR-018** (Inter-iteration release cadence for AFK loops), **ADR-019** (AFK orchestrator preflight) — AFK carve-out preserves.
- **ADR-026** (Agent output grounding) — file-based observable artefacts (receipt, marker, systemMessage transcript).
- **ADR-031** (Problem-ticket directory layout) — receipt artefact lives at the per-state-subdir path post-migration.
- **ADR-005** + **ADR-025** (TDD state + test content quality review) — note on auto-install + TDD-state interaction captured in Consequences.
- **ADR-009** (Gate marker lifecycle) — precedent for TTL on cached-metadata results.
- **P045** — driver ticket; closes at decision level. Execution tracks under P045.
- **P070** — report-upstream dedup; tangentially related (both touch on automation + consent-gated external action).
- `packages/itil/hooks/` — hook location.
- `.claude/skills/install-updates/SKILL.md` — consent-grant addition target.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary beneficiary.
- **JTBD-005** (Invoke Governance Assessments On Demand) — next-session trigger motivated by the "must not leave task context" constraint.
- **JTBD-003** (Compose Only the Guardrails I Need), **JTBD-006** (AFK), **JTBD-101** (Extend the Suite with New Plugins), **JTBD-201** (Audit Trail) — secondary beneficiaries.
