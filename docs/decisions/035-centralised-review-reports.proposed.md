---
status: "proposed"
date: 2026-04-21
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-07-21
---

# Centralised review reports for cross-project skill improvement — JSONL at `~/.claude/review-reports/`

## Context and Problem Statement

Every `@windyroad/*` reviewer-agent invocation produces a verdict: architect-enforce-edit emits PASS / ISSUES FOUND against ADRs; jtbd-enforce-edit emits PASS against persona jobs; voice-tone / style-guide / risk-scorer emit equivalent verdicts against their respective policies. These verdicts inform the gate-or-delegate decision in the current session, and then they're gone. There is no aggregate record.

Consequence: the suite has no cross-project feedback loop. The architect agent can't tell that `cache-control` was flagged on 14 of the last 30 reviews across 6 projects — because there's no store of reviews. Skill-improvement hypotheses ("the voice-tone gate has a 30% false-positive rate on changeset bodies") have no data. The P051 run-retro improvement axis can surface patterns at a single session's scale but can't read across sessions or projects.

P034 captures the gap: a home-directory store (one per user) holds structured review-report artefacts; a new read-surface skill queries the store; run-retro's P051 improvement axis consumes the patterns as improvement-candidate inputs. User-pinned direction 2026-04-20: `~/.risk-reports/` home-dir storage + skill-improvement feedback loop for 8+ plugins + new ADR.

Architect review of the planning design (2026-04-21) raised 6 items the ADR must address: reviewer scope specificity (mandatory vs opt-in per agent), ADR-023 per-request-cost quantification, JSONL schema contract, P037 reason/evidence field inheritance, reassessment criteria, and naming (`~/.risk-reports/` conflicts with "cross-plugin, not risk-only" framing). Pick `~/.claude/review-reports/` per architect lean.

## Decision Drivers

- **JTBD-002** (Ship AI-Assisted Code with Confidence) — primary. "Audit trail exists showing governance was followed" requires a persistent store beyond in-session verdict-in-the-transcript.
- **JTBD-001** (Enforce Governance Without Slowing Down) — structured report output makes review findings queryable without adding a manual step.
- **JTBD-101** (Extend the Suite with New Plugins) — `/wr-risk-scorer:review-history` as a user-invocable skill follows the ADR-015 "assessment agent → on-demand skill" pairing pattern; plugin developers get a repeatable "reviewer-emits-report" contract.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — cross-project aggregation serves the tech-lead's "consistent standards across teams / engagements" constraint.
- **P034** — driver ticket.
- **P051** (run-retro improvement axis) — consumer of aggregated patterns.
- **P033** (persistent risk register, Verification Pending) — sibling surface; risk register is the risk-scorer's own aggregated state; review-reports is the reviewer-agents' aggregated state.
- **P037** (jtbd reviewer returns bare verdict without reason, Verification Pending) — precedent for "reviewer output must carry structured evidence". Review-reports inherit the P037 reason/evidence requirement.
- **ADR-026** (Agent output grounding) — review-reports ARE a persist-surface for the `cite + persist + uncertainty` contract. Future agents can cite a specific report line as grounding.
- **ADR-023** (wr-architect performance-review scope) — per-invocation report-write cost MUST be quantified under this ADR's scope.
- **ADR-013** (Structured user interaction) — Rule 6 fail-safe governs the opt-in / opt-out flow; AFK default is opt-out (privacy-preserving).
- **ADR-004** (Project-scoped install by default) — writes are project-scoped; cross-project reads require explicit user invocation.
- **ADR-015** (On-demand assessment skills) — `/wr-risk-scorer:review-history` fits the assessment-skill pairing pattern.

## Considered Options

1. **JSONL reports at `~/.claude/review-reports/<project-path-sanitised>/<YYYY-MM-DD>/<session-id>.jsonl`; new read-surface skill + run-retro P051 improvement-axis consumer; per-project opt-out marker** (chosen) — user direction shaped by architect review. Matches P034 pinned direction with the home-dir name corrected to `~/.claude/review-reports/` (architect advisory on cross-plugin framing). One JSONL line per verdict. Reader skills parse the store; writers append at invocation.
2. **In-repo `docs/review-reports/` per project** — rejected per P034. Pollutes the project's tree with transient per-session output; commits the audit record in-tree (contradicts its "log, don't commit" intent).
3. **Dedicated observability service (OTEL or similar)** — rejected per P034. Adds runtime dependency; external confidentiality exposure; not commensurate with the single-user developer-laptop audience.
4. **Per-invocation single file (`<session>.md`) instead of JSONL appended** — rejected. Markdown parsing is lossier and unstructured; JSONL is idempotent append-only and directly queryable.
5. **No persistent store — rely on transcript replay** — status quo. Rejected per P034 (transcripts are session-scoped; cross-session patterns invisible).

## Decision Outcome

**Chosen option: Option 1** — home-dir JSONL store + read-surface skill + run-retro consumer + opt-out marker.

### Store location and naming

- **Root**: `~/.claude/review-reports/` (renamed from P034's tentative `~/.risk-reports/` per architect advisory; the store is cross-plugin, not risk-scorer-exclusive).
- **Per-project subdirectory**: `~/.claude/review-reports/<project-hash>/` where `<project-hash>` is a sha256 of the absolute project path (first 12 characters), plus a human-readable basename suffix (`<project-hash>-<basename>`). The hash prevents path-leak through filenames (RISK-POLICY.md Confidential Information Concern: project paths that contain client names are NOT exposed in the filename).
- **Per-day partition**: `<project-hash>-<basename>/<YYYY-MM-DD>/`.
- **Per-session file**: `<session-id>.jsonl`. Session-id is ephemeral per Claude Code session; the file is append-only within the session.

### JSONL schema (Decision Outcome contract)

Each line is one verdict emitted by one reviewer agent. Schema:

```json
{
  "schema_version": "1.0",
  "timestamp": "2026-04-21T10:23:45Z",
  "session_id": "a1b2c3d4...",
  "project_path_hash": "sha256(first12)",
  "reviewer": "wr-architect:agent",
  "reviewer_version": "@windyroad/architect@0.4.1",
  "invocation_cause": "PreToolUse:Edit packages/itil/skills/manage-problem/SKILL.md",
  "verdict": "PASS|FAIL|ISSUES_FOUND|ADVISORY",
  "issues": [
    {
      "severity": "blocking|advisory|note",
      "citation": "ADR-027 line 29",
      "summary": "short description",
      "evidence": "specific file path + line number + matched substring"
    }
  ],
  "decision_drivers_cited": ["ADR-027", "ADR-009", "P057"],
  "grounded_quantitative_claims": [
    { "claim": "per-request cost 0.5ms", "citation": "benchmarks/hook-runtime.json", "uncertainty": "±0.2ms" }
  ]
}
```

**Schema evolution**: additive-only within a major version. Breaking changes require a `schema_version` bump and a migration note in this ADR's Reassessment Criteria.

**P037 inheritance**: the `issues` array's `evidence` field is the P037 reason-not-bare-verdict requirement applied at the report-write surface. A reviewer agent writing an entry with empty `evidence` on a FAIL / ISSUES_FOUND is itself a contract violation (bats doc-lint asserts this at test time).

**ADR-026 inheritance**: every quantitative claim in the report body MUST be grounded per `cite + persist + uncertainty` OR emit the explicit `"not estimated — no prior data"` string in place of a fabricated value. Reports themselves become citable persist-sources in turn.

### Reviewer scope

Report-writing is **mandatory for every invocation** of these agents (architect's issue #1 resolved in favour of mandatory to avoid opt-in-per-agent drift):

- `wr-architect:agent`
- `wr-jtbd:agent`
- `wr-voice-tone:agent` (both in-repo and external-comms per ADR-028)
- `wr-risk-scorer:pipeline`
- `wr-risk-scorer:external-comms` (new per ADR-028 amendment)
- `wr-risk-scorer:wip`
- `wr-style-guide:agent` (when it exists; follows the same pattern)
- Any future `@windyroad/*` reviewer agent — the agent's SKILL.md/agent-doc carries a "report-writing" section confirming it emits JSONL per this ADR.

Each agent's source doc gains a one-line write-before-return clause: at end-of-agent-turn, append one JSONL line per emitted verdict to the current session's review-reports file. Bats doc-lint asserts the clause presence.

### Consumer shape

Per architect advisory — both, with clear role separation:

- **`/wr-risk-scorer:review-history`** (NEW on-demand skill per ADR-015 pairing) — reads the aggregated store across projects. Surfaces patterns: "architect flagged ADR-023 cache-control drift on 14 of last 30 reviews", "jtbd reviewer's false-positive rate against JTBD-005 is 30% over 2 weeks", "voice-tone gate fires on `.changeset/*.md` more than on `gh issue comment` 3:1". Output shape: structured summary + specific citations back to source lines (JSONL file + line number). Triggered by explicit user invocation only.
- **run-retro P051 improvement-axis consumer** (existing, extended) — Step 2's codification reflection gains a prompt: "Did `review-history` surface any patterns worth codifying?". If yes, the pattern becomes an improvement-candidate input routed through P051's existing improvement-stub / improve-routing flow.

### Privacy and consent

- **Project-scoped write, explicit-invocation read**: report-write runs automatically per reviewer agent. Cross-project read happens ONLY when the user explicitly invokes `/wr-risk-scorer:review-history` OR when run-retro queries aggregated patterns (and run-retro is always user-initiated). No agent in project A can passively read project B's reports.
- **Opt-out file**: `.claude/.review-reports-opt-out` (empty file marker) in a project's root disables report-writing for that project. Reviewer agents check the marker before writing; on marker present, skip the write silently (no-op; no error). Per ADR-013 Rule 5 policy-authorisation.
- **First-run prompt (per-project, interactive mode only)**: the first time any reviewer agent fires in a project without the opt-out marker AND without an explicit opt-in marker (`.claude/.review-reports-opt-in`), the agent emits a systemMessage notifying the user that reports will be written. The user can create the opt-out marker to disable.
- **AFK first-run fail-safe (per ADR-013 Rule 6)**: in AFK mode (orchestrator-launched session; detection via envvar per ADR-019 convention), the first-run prompt cannot fire interactively. Default behaviour: **skip report-writing for this session** AND emit a pending-questions artefact per ADR-032 deferred-question contract asking the user (on next user-initiated session) whether to opt in/out. This is Rule 6 fail-safe — privacy-preserving default under non-interactive conditions.
- **Confidentiality**: reports MUST NOT contain secrets extracted from the project. Reviewer agents path-sanitise (no absolute paths outside `<project>/`), content-sanitise (any detected credential patterns replaced with `[REDACTED]`), and hash the project path in filenames. Compliance checked by a sentinel bats test that seeds a mock-secret into a test project and asserts the secret does NOT appear in the written JSONL.
- **No cross-machine sync**: `~/.claude/review-reports/` is explicitly outside sync paths. Plugin ships with a README at `~/.claude/review-reports/README.md` (written on first report) explaining the location, the opt-out file, and the retention policy.

### Retention

- **Default retention**: 90 days. Files older are auto-deleted by a background pass in `/wr-risk-scorer:review-history` on each invocation (amortised cleanup). Configurable via `REVIEW_REPORTS_RETENTION_DAYS` envvar.
- **Size cap** (secondary bound): if `~/.claude/review-reports/` exceeds 500 MB (per-user total), the next `review-history` invocation warns the user and suggests retention tightening or full-wipe. 500 MB chosen as a hand-estimate (not ADR-026-grounded — this is a first-pass budget; reassessment will set a grounded number from real data once reports exist).

### Performance cost (ADR-023 compliance)

- **Per-invocation cost**: one JSONL append per reviewer agent invocation. Append-only write is bounded by filesystem write speed; typical cost ~1-5ms per line on SSD; bytes per line ~500-2000 depending on issue count.
- **Frequency estimate**: NOT ESTIMATED — NO PRIOR DATA (per ADR-026 — no existing measurement of reviewer-agent invocation frequency across typical sessions). The ADR acknowledges this and flags in Reassessment Criteria: first 3 months of data will ground the frequency + aggregate-load estimates for the next revision.
- **Aggregate load delta**: same grounding limitation. Worst-case upper bound: if every Bash edit triggers all 5 review agents (which is not the case today; agents fire selectively per hook scope), and a developer does 200 edits/day, aggregate write volume is 1000 writes/day × ~1 KB = 1 MB/day per project. 90-day retention → 90 MB per project worst-case. With 6 projects = 540 MB. Brushing against the 500 MB size cap triggers a reassessment — this is intentional; the cap is chosen to force us to look at real data.
- **Cache miss or filesystem full**: report-write failures MUST be non-fatal. Reviewer agent continues with its verdict; a systemMessage warns about the failure; the emitted JSONL line is lost. Fail-safe is "lose the audit line rather than block the review".

## Scope

### In scope (this ADR)

- Store location, per-project hashed subdirectory layout, per-day partition, per-session JSONL.
- JSONL schema contract (Decision Outcome).
- Per-agent amendment: each reviewer agent's source doc gains a report-writing clause.
- New `/wr-risk-scorer:review-history` on-demand skill + ADR-015 pairing entry.
- run-retro P051 consumer integration (Step 2 prompt addition citing review-history).
- Per-project opt-out marker + first-run prompt + AFK fail-safe.
- Privacy/confidentiality rules (path hashing, content sanitisation, secret redaction, no sync).
- Retention policy + size cap + reassessment trigger for grounded budgets.
- ADR-026 inheritance (grounded quantitative claims) and P037 inheritance (structured issues with evidence).
- Bats coverage: schema-conformance tests, sentinel-secret test, opt-out-marker test, retention-prune test.

### Out of scope (follow-up tickets or future ADRs)

- Cross-machine aggregation (one user, multiple machines). Rejected per P034; could revisit if the pattern emerges.
- Multi-user aggregation (team-shared review reports). Breaks ADR-004 + RISK-POLICY.md Confidentiality; significant design effort; out of scope.
- Non-`@windyroad/*` plugin integrations. The JSONL schema is open; third parties could adopt, but this ADR doesn't mandate.
- Real-time review-history streaming. Polling-on-invocation is the read model.
- Backfill of historical reviews from transcripts. Forward-only collection.

## Consequences

### Good

- P034 closes at design level. Cross-project pattern surfacing now has a substrate.
- ADR-026 persist-surface extended; future agents cite report lines as grounding.
- P037 reason-not-bare-verdict contract enforced at the report-write surface.
- Run-retro P051 improvement axis gets cross-session data; pattern-driven codification candidates surface naturally.
- Per-agent report-writing clause gives plugin-developers a repeatable "reviewer-emits-report" template.
- Privacy defaults preserve ADR-004 + RISK-POLICY.md Confidentiality.

### Neutral

- Every reviewer-agent invocation now does a filesystem append. Bounded by ~1-5ms per line; per-session aggregate is small.
- `~/.claude/review-reports/` is one more directory in the user's home. Plugin ships a README explaining what it is.
- Per-project first-run prompt adds one interactive turn. Skipped in AFK per Rule 6.
- Schema evolution requires additive-only discipline; major-version bumps rare.

### Bad

- **Disk usage**: 500 MB per-user worst-case projection (90-day retention × 6 projects × 1 MB/day). Acceptable for developer laptops; compressed in follow-up if sustained retention exceeds budget.
- **Reviewer-agent failure mode expansion**: report-write path introduces a new failure mode. Mitigated by non-fatal semantics; audit-line lost but verdict preserved.
- **Schema drift**: reviewer agents that write malformed JSONL break `review-history` parsing. Mitigated by per-agent bats schema-conformance tests.
- **First-run prompt friction**: new projects get one interactive turn on first reviewer invocation. Acceptable; avoidable via explicit opt-in.
- **Ungrounded frequency estimate**: the 1000-writes/day aggregate projection is an admittedly-ungrounded worst case. Reassessment will ground it from real data.
- **AFK deferred opt-in**: if an AFK orchestrator runs repeatedly before the user opens a user-initiated session, report-writing is skipped repeatedly. Acceptable per Rule 6 fail-safe; pending-questions artefact accumulates but the user sees it on return.
- **Cross-project read is trust-expansion**: `/wr-risk-scorer:review-history` reads across all project subdirectories under `~/.claude/review-reports/`. Per-machine, per-user only; no network surface. But the skill's invocation grants the calling session read access to all stored reports. Accepted: the user invoked it.

## Confirmation

### Source review (at implementation time)

- `~/.claude/review-reports/` directory structure matches the spec (project-hash subdirs, day partitions, session JSONL).
- Each reviewer agent doc carries the "report-writing" clause. Specifically: `packages/architect/agents/agent.md`, `packages/jtbd/agents/agent.md`, `packages/voice-tone/agents/agent.md`, `packages/risk-scorer/agents/*.md`, `packages/style-guide/agents/agent.md` (when it exists).
- JSONL schema lives as a reference at `packages/shared/review-reports-schema.json` (JSON Schema draft).
- `/wr-risk-scorer:review-history` SKILL.md exists and follows ADR-015 pairing (the agent reviewer behind it is the existing `wr-risk-scorer:pipeline` or a new read-surface subagent).
- run-retro Step 2 prompt extension cites `review-history` patterns.
- Opt-out marker `.claude/.review-reports-opt-out` respected (reviewer agents skip writing when present).
- First-run systemMessage fires on absence of both markers.
- AFK fail-safe uses ADR-032 deferred-question contract.
- Retention cleanup runs on `review-history` invocation.
- Content sanitisation: sentinel bats test seeds a mock secret and asserts it's redacted in written JSONL.

### Bats structural tests

- `packages/shared/test/review-reports-schema.bats` — schema conformance for a sample entry.
- `packages/<plugin>/agents/test/<agent>-review-report-write.bats` (per reviewer agent) — asserts the agent's doc contains the report-writing clause + cites ADR-035.
- `packages/shared/test/review-reports-opt-out.bats` — asserts writes are skipped when the opt-out marker is present.
- `packages/shared/test/review-reports-secret-redaction.bats` — sentinel test seeding mock secrets into report input and asserting redaction.
- `packages/risk-scorer/skills/review-history/test/review-history-contract.bats` — the new skill's SKILL.md structural test.

## Pros and Cons of the Options

### Option 1: Home-dir JSONL + read-surface skill + run-retro consumer (chosen)

- Good: aligns with pinned P034 direction; ADR-026 persist-surface; P037 evidence-inheritance; plugin-developer extensibility.
- Bad: disk footprint (bounded but real); per-invocation write cost (~1-5ms); frequency estimate ungrounded until real data.

### Option 2: In-repo `docs/review-reports/`

- Good: reports versioned with the project.
- Bad: commits transient per-session noise into git; contradicts "log, don't commit" intent.

### Option 3: External observability service

- Good: scalable.
- Bad: runtime dep; cross-machine confidentiality exposure; over-engineered for developer-laptop audience.

### Option 4: Markdown per-invocation files

- Good: human-readable.
- Bad: unstructured; parsing is lossy; `review-history` becomes expensive/brittle.

### Option 5: No store (status quo)

- Good: zero effort.
- Bad: P034 open; no cross-session feedback loop; ADR-026 persist-surface can't be extended.

## Reassessment Criteria

Revisit this decision if:

- `review-history` is never invoked after 3 months of report-writing. Signal: the write pipeline is dead weight. Retire or reconsider.
- `~/.claude/review-reports/` exceeds 500 MB for any user before retention kicks in. Signal: size cap undersized; raise cap or tighten retention.
- Reviewer-agents' invocation frequency is 10x the current worst-case estimate (once real data exists). Signal: rebase cost budget; possibly switch to batched writes or compression.
- Schema evolution proves too restrictive (additive-only). Signal: revisit schema-evolution policy; consider explicit schema versioning in each line.
- Cross-machine aggregation becomes a recurring ask. Signal: revisit the local-first stance; design a sync opt-in.
- Content-sanitisation misses a secret class. Signal: extend sanitisation ruleset; bats sentinel test added for the new class.
- run-retro P051 consumer produces more false-positive improvement candidates than actionable ones. Signal: retune the aggregation heuristic or deprecate the run-retro integration.
- A second reviewer-agent plugin emerges (e.g. licence-compliance) — the per-agent amendment template in this ADR must cover it without re-drafting.

## Related

- **P034** — driver ticket.
- **P033** (persistent risk register) — sibling surface; risk register is risk-scorer-specific state; review-reports is multi-reviewer state.
- **P037** (jtbd reviewer bare verdict) — evidence-field-required precedent, inherited at the report-write surface.
- **P051** (run-retro improvement axis) — consumer of aggregated patterns.
- **ADR-004** (Project-scoped install) — write-scope preserved; read-scope explicitly user-invoked.
- **ADR-013** (Structured user interaction) — Rule 5 + Rule 6 govern opt-in and AFK fail-safe.
- **ADR-015** (On-demand assessment skills) — `review-history` skill pairing pattern.
- **ADR-023** (wr-architect performance review scope) — per-invocation cost quantified (with explicit ADR-026 ungrounded-flag on frequency).
- **ADR-026** (Agent output grounding) — persist-surface extended; quantitative-claim grounding inherited.
- **ADR-028** (External-comms gate, amended 2026-04-21) — `wr-risk-scorer:external-comms` reviewer emits reports per this ADR.
- **ADR-032** (Governance skill invocation patterns) — deferred-question contract used for the AFK first-run fail-safe.
- **ADR-014** (Governance skills commit their own work) — review-history's commits when it rewrites retention-aged files follow standard commit discipline (rare).
- **ADR-019** (AFK orchestrator preflight) — AFK envvar detection convention reused.
- **JTBD-001**, **JTBD-002**, **JTBD-101**, **JTBD-201** — personas whose needs drive this ADR.
- **JTBD-006** — AFK persona; opt-out-default under AFK respects the "does not trust the agent to make judgement calls" constraint.
- `packages/risk-scorer/skills/review-history/` (future) — new skill location.
- `packages/shared/review-reports-schema.json` (future) — JSON Schema reference.
