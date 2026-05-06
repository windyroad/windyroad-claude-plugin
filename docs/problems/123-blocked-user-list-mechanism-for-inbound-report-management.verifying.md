# Problem 123: Blocked-user list mechanism for inbound report management — refuse future tickets from clearly-malicious reporters

**Status**: Verification Pending
**Reported**: 2026-04-26
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)
**Effort**: M — new per-repo persistence artefact (`docs/blocked-reporters.json`), enforcement at two surfaces (P079's inbound discovery filter + `/wr-itil:report-upstream`'s outbound-target filter), ADR call on the persistence shape + scope boundary. Carved out from P079 per user direction 2026-04-26 to keep P079 focused on the assessment pipeline; P123 gets its own ADR (ADR-046) on per-repo vs per-machine scope.
**WSJF**: (12 × 0) / 2 = **0** (Verification Pending — excluded from dev-work ranking per ADR-022)
**Type**: technical

**Root cause**: documented in **ADR-046** (`docs/decisions/046-blocked-reporters-persistence.accepted.md`, 2026-04-28). The ADR records the resolved persistence-shape decision (per-repo, hashed GitHub user IDs), names the audit-log-only v1 implementation contract, and surfaces 3 Open Questions (block-list shape Q1, provenance Q2, un-block path Q3) that block transition of ADR-046 from `proposed` → `accepted`. Each Open Question carries a proposed default an implementation iter could adopt with user approval. The audit-log-only slice is shippable independently per this ticket's pacing decision; full malicious-actor defence requires P079's inbound-filter integration + `/wr-itil:report-upstream`'s outbound pre-check (ADR-024 extension), both deferred to subsequent iters when those features ship.

> Surfaced 2026-04-26 from the P079 (inbound sync of upstream-reported problems) interactive design-question resolution. User direction added a multi-step assessment pipeline for inbound reports including a "clear-malicious" branch that closes the upstream ticket AND adds the user to a blocked-user list (refusing all future tickets from them). The block-list mechanism is a new lifecycle artefact distinct from P079's inbound-discovery scope, and warrants its own ticket so each can ship independently.

## Description

P079's assessment pipeline classifies inbound upstream-reported problems through a dual-axis risk evaluation (request-text risk + fix-work risk) and a JTBD-alignment check. The "clear-malicious" branch — when a report is identifiably malicious (info-extraction attempt, backdoor request, malicious code injection request) — needs to do TWO things:

1. Close the upstream ticket (with the dual-gated pushback comment per P079's safe path).
2. Record the reporter in a persistent block list so future reports from the same reporter are refused at discovery time, without reaching the assessment pipeline.

P123 is the second action's persistence + enforcement infrastructure. Without it, a malicious actor can keep filing reports indefinitely; we'd assess each one fresh, each one would land at the same "clear-malicious" verdict, and we'd burn cycle on already-known-bad sources.

## Symptoms

- A malicious reporter can file unlimited reports; the assessment pipeline runs each time; no signal accumulates across reports.
- The "block this user" decision is made implicitly during the close action but not recorded anywhere; the next inbound report from the same user goes through full assessment again.
- No outbound surface guard either: `/wr-itil:report-upstream` could in principle file a report against a project whose maintainer has blocked us (we wouldn't know).

## Workaround

None today. Maintainer manually closes each malicious report and burns mental cycle remembering "this user is bad — don't engage further". Doesn't survive cross-session and doesn't survive multiple maintainers.

## Impact Assessment

- **Who is affected**: every adopter of the P079 inbound-assessment pipeline whose tracker receives reports from a recurring malicious actor. Lower frequency than P079's broad surface, but higher per-incident severity.
- **Frequency**: Possible — depends on whether the project is targeted. Unknown today (no inbound surface yet), but the architecture should support it from day one rather than retrofit after a real incident.
- **Severity**: Significant — a successful malicious report (one that bypasses the assessment pipeline) could land malicious code, leak sensitive context, or exhaust maintainer attention. The block list is a defence-in-depth layer.
- **Likelihood**: Possible — depends on adoption surface and target attractiveness. Higher for popular plugins; lower for niche ones.
- **Analytics**: N/A — pre-incident defence; success means no incidents to count.

## Root Cause Analysis

### Confirmed scope decision (2026-04-26 user direction)

**Persistence scope**: **Per-repo** — `docs/blocked-reporters.json` (or similar) lives in the repo. Tracked in git. Every contributor sees the same block list; new clones inherit it. Block decisions are project-wide policy, not per-machine preference. Aligns with how SECURITY.md, CODEOWNERS, and other governance artefacts work.

**Acknowledged risk** of per-repo persistence: a visible, git-tracked block list is a public signal. Listed users can see they've been blocked; this could attract attention or escalation. Mitigation: the block list could record only opaque hashes (e.g., GitHub user ID hash) rather than usernames, with a private mapping file held out of the repo. ADR call at implementation time on the visibility-vs-traceability trade-off.

### Visibility decision (2026-04-26 user direction — post-AFK-loop /wr-retrospective:run-retro AskUserQuestion)

**Visibility shape**: **Hashed GitHub user IDs**. Store SHA-256 hashes of GitHub user IDs (numeric, stable across username changes — username changes preserve user ID). Public-but-opaque shape mitigates the public-signal concern from the Acknowledged-risk paragraph above. Un-block requires the original user ID; one-extra-step recovery is the trade-off the user accepted. Resolves the first of 4 unresolved ADR design questions named in the Investigation Tasks below. The remaining 3 (block-list shape, provenance, un-block path) stay open for ADR-time resolution; this ticket can ship as soon as those are settled.

### Investigation Tasks

- [ ] ADR draft for the persistence + enforcement contract. Decisions to settle:
  - **Visibility**: usernames-in-the-clear vs hashed-IDs vs out-of-repo private mapping.
  - **Block-list shape**: flat list vs structured (per-channel: GH issues / discussions / security advisories may have different block surfaces).
  - **Block-decision provenance**: who recorded the block, when, with what evidence link (ticket ID + automated assessment verdict).
  - **Un-block path**: how does a blocked user appeal? Manual maintainer review only, or a structured request channel?
- [ ] Enforcement at P079's inbound discovery: filter discovered reports against the block list before they enter the assessment pipeline. The filter runs at the discovery loop, NOT at the assessment-pipeline output, so blocked-user reports never consume assessment cycles.
- [ ] Enforcement at `/wr-itil:report-upstream`'s outbound: when filing a new report against an upstream project, check whether the upstream project has blocked us (we'd need to discover their block list using the same lookup pattern report-upstream uses for SECURITY.md). If blocked, halt with a clear message rather than file silently.
- [ ] Audit-log shape: every block / un-block records to a sibling audit log so the decision history is reviewable across sessions.
- [ ] Integration with P079's clear-malicious branch: the close-and-block action atomically closes the upstream ticket AND appends the block-list entry, in one commit (ADR-014).
- [ ] Bats coverage: the per-repo file shape is testable via doc-lint contract assertions per ADR-037.

### Fix Strategy

**Shape**: New JSON artefact + new helper library + integration points in P079 and `/wr-itil:report-upstream`.

**Target files**:
- `docs/blocked-reporters.json` — NEW. Per-repo persistent block list.
- `packages/itil/hooks/lib/block-list.sh` — NEW shared helper. Functions: `is_blocked(<reporter-id>)`, `add_block(<reporter-id>, <evidence-ticket>, <provenance>)`, `remove_block(<reporter-id>, <reason>)`, `list_blocks()`.
- `packages/itil/skills/report-upstream/SKILL.md` — outbound-filter integration: check the upstream project's block list (if discoverable) before filing.
- P079's eventual implementation files — inbound-filter integration and clear-malicious-branch atomic close-and-block action.
- `docs/decisions/<NNN>-blocked-reporters-persistence.proposed.md` — NEW ADR. Decisions on visibility, structure, audit log, un-block path.
- `packages/itil/hooks/test/block-list.bats` — NEW. 6-8 behavioural assertions: add+is_blocked round-trip, list_blocks shape, idempotent add, remove path, audit log presence, hashed-ID handling.
- `.changeset/wr-itil-p123-*.md` — minor bump (new shared helper + ADR + integration points).

**Out of scope**: integration with non-GitHub reporting channels (Discord, etc.) — handled when those channels become primary intake surfaces. Cross-repo block-list federation (sharing block lists between maintainers of different `@windyroad/*` adopters) — out of scope; per-repo only for v1.

## Dependencies

- **Blocks**: P079 (the clear-malicious branch of P079's assessment pipeline depends on this ticket's close-and-block action; P079 can ship with audit-log-only as a stop-gap, but the full malicious-actor defence requires P123)
- **Blocked by**: (none — P123 can ship independently as audit-log-only first, then gain enforcement when P079 + report-upstream integration land)
- **Composes with**: P079 (consumes the block list at inbound discovery + clear-malicious branch), P070 (verifying — `/wr-itil:report-upstream` consumes the block list at outbound filing), P064 (risk gate — the close-and-block action's pushback comment goes through this), P038 (voice-tone gate — same), P122 (orchestrator interactive-default — when running interactively, block decisions could surface via AskUserQuestion before being recorded; AFK mode auto-records per the assessment pipeline verdict)

## Related

- **P079** (`docs/problems/079-no-inbound-sync-of-upstream-reported-problems.open.md`) — parent ticket; carved out from P079's assessment pipeline per 2026-04-26 user direction. P079's clear-malicious branch consumes P123's block-list infrastructure.
- **P070** (`docs/problems/070-report-upstream-does-not-check-existing-issues.verifying.md`) — `/wr-itil:report-upstream`'s outbound-filing surface; P123 adds a block-list pre-check before any outbound file.
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-communications.open.md`) — risk gate on external comms; P123's close-and-block pushback comment routes through this gate.
- **P038** (`docs/problems/038-no-voice-and-tone-gate-on-external-communications.open.md`) — voice-tone gate; same path as P064.
- **P122** (`docs/problems/122-work-problems-stop-condition-2-defaults-to-afk-table-instead-of-asking-interactively.open.md`) — orchestrator interactive-default routing; P123 block decisions inherit the same interactive-vs-AFK routing pattern.
- **ADR-024** (`docs/decisions/024-cross-project-problem-reporting-contract.proposed.md`) — outbound report contract; P123 extends this with an outbound block-list filter.
- **ADR-030** (`docs/decisions/030-repo-local-skills-for-workflow-tooling.proposed.md`) — per-project artefact pattern (parallel to consent caches `.claude/.install-updates-consent` + `.claude/.auto-install-consent`); P123's per-repo persistence inherits the same shape.
- `docs/blocked-reporters.json` — primary new artefact.
- `packages/itil/hooks/lib/block-list.sh` — primary new shared helper.
- **JTBD-101** (plugin-developer / maintainer) — primary fit. Maintainer attention is the resource the block list defends.
- **JTBD-201** (downstream adopter) — composes; the same maintainer-side defence applies to adopters of `@windyroad/itil` who use the inbound-assessment pipeline in their own projects.
- 2026-04-26 session evidence: surfaced from P079's interactive design-question resolution (P122 trigger). User direction was explicit about the per-repo scope ("Per-repo (Recommended)") and the block-list's role in the P079 assessment pipeline.

## Fix Released

**Released**: 2026-04-28 (next `@windyroad/itil` release after this commit lands).

**Fix summary**: ADR-046's v1 audit-log-only slice ships. `packages/itil/hooks/lib/block-list.sh` exposes `is_blocked` / `add_block` / `remove_block` / `list_blocks`; `docs/blocked-reporters.json` is the per-repo persistent block list (empty array on creation, hashed GitHub user IDs only); `docs/blocked-reporters.audit.jsonl` is the sibling append-only audit log with the five-field shape adopted in ADR-046 Q2 (`type, reporter_id_hash, evidence_ticket, timestamp, author`). `packages/itil/hooks/test/block-list.bats` carries 10 behavioural assertions covering round-trip, idempotent add, remove path, audit-log presence (block + unblock), `list_blocks` output shape, and hex-shape validation rejections. ADR-046 transitions `proposed → accepted` in the same commit; Q1/Q2/Q3 all marked Adopted (Q3's monitor-mechanism implementation specifics deferred to a future iter).

**Out of scope (deferred per ticket pacing decision line 78)**:
- P079's inbound-discovery filter integration — when P079's assessment pipeline ships, it consumes `is_blocked()` at the discovery loop.
- `/wr-itil:report-upstream`'s outbound pre-check — when P070 closes (currently Verifying), the outbound surface adds `is_blocked()` against the upstream-project's block list before filing.
- ADR-046 Q3's agent-monitored review-cycle implementation (monitor channel + surface format + response-handling) — direction adopted, implementation in a future iter.

**Verification path**: confirm the audit-log-only v1 slice works as advertised — run the bats (`bats packages/itil/hooks/test/block-list.bats` ⇒ 10/10 green) plus the full itil hooks suite (`bats packages/itil/hooks/test/` ⇒ 95/95 green this iter, no regression). Optional manual exercise: source `block-list.sh`, call `add_block <fake-hash> P123 test@example.com`, observe `docs/blocked-reporters.json` updated to `["<hash>"]` and `docs/blocked-reporters.audit.jsonl` carrying the block-typed entry.

Awaiting user verification.
