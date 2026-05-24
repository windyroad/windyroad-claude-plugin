---
status: accepted
date: 2026-04-28
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, downstream `@windyroad/itil` adopters]
reassessment-date: 2026-10-28
---

> **Acceptance note (2026-04-28)** — transitioned from `proposed` after the v1 audit-log-only slice landed (P123 iter 4). Q1 (flat list), Q2 (five-field shape), and Q3 (agent-monitored review-cycle) all carry "Adopted" markers below. Q3's monitor-mechanism + surface-format implementation specifics remain deferred to a future iter (per Q3's adopted note); the persistence-layer direction encoded in this ADR is settled. P123 transitions Known Error → Verification Pending in the same commit per ADR-022.

# ADR-046 — Blocked-reporters persistence: per-repo, hashed-ID, audit-log-first

## Context and Problem Statement

P079 (`docs/problems/079-no-inbound-sync-of-upstream-reported-problems.open.md`) introduces a multi-step assessment pipeline for inbound upstream-reported problem tickets. The pipeline classifies each report through a dual-axis risk evaluation (request-text risk + fix-work risk) and a JTBD-alignment check, producing one of several verdict branches. The "clear-malicious" branch — when a report is identifiably malicious (info-extraction attempt, backdoor request, malicious-code-injection request) — needs to do two things atomically:

1. Close the upstream ticket with the dual-gated pushback comment per P079's safe path.
2. Record the reporter in a persistent block list so future reports from the same reporter are refused at discovery time, before the assessment pipeline runs.

P123 carved the second action out as its own ticket per the 2026-04-26 user direction during P079's design-question resolution. Without persistent block-list infrastructure, a malicious actor can file unlimited reports; the assessment pipeline runs each time; no signal accumulates across reports. The same surface protects two flows:

- **Inbound** (P079's discovery loop) — filter out reports from blocked reporters before they reach the assessment pipeline.
- **Outbound** (`/wr-itil:report-upstream`'s filing surface, ADR-024) — pre-check whether the upstream project's maintainer has blocked us before filing. If so, halt with a clear message rather than file silently.

This ADR records the persistence-layer decisions for the block list itself. Three downstream questions remain unresolved at ADR-time and are surfaced explicitly in the Open Questions section below; this ADR's scope is the foundation that makes the audit-log-only slice shippable independently while leaving room for the open questions to resolve via a future amend cycle.

## Decision Drivers

- **JTBD-101 — Extend the Suite with New Plugins** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — primary persona served. The plugin-developer / maintainer's documented pain point is reverse-engineering undocumented conventions; an ADR that names the persistence shape + open questions removes that friction for the downstream implementation iter and for adopters consuming the same pattern.
- **JTBD-202 — Pre-flight Governance Check** (`docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md`) — composes. The tech-lead persona's adopter-of-`@windyroad/itil` framing inherits the same maintainer-side defence; the per-repo shape ensures every collaborator sees the same block list without per-machine drift.
- **JTBD-001 — Enforce Governance Without Slowing Down** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — the block list is itself a governance artefact; codifying it as a tracked file with audit-log provenance keeps the framework's "decide once, encode it, then act" discipline.
- **ADR-024 — Cross-project problem-reporting contract** (`docs/decisions/024-cross-project-problem-reporting-contract.proposed.md`) — outbound report contract. ADR-046 extends this with an outbound block-list pre-check before any upstream filing.
- **ADR-029 — Diagnose before implement** (`docs/decisions/029-diagnose-before-implement.proposed.md`) — the dominant constraint here. P123 names three unresolved decisions (shape, provenance, un-block path); shipping helper code or test coverage that locks in a shape choice before those decisions land violates ADR-029. ADR-046 lands the diagnosis in `proposed` state; implementation waits.
- **ADR-030 — Repo-local skills for workflow tooling** (`docs/decisions/030-repo-local-skills-for-workflow-tooling.proposed.md`) — per-repo artefact precedent. Consent caches (`.claude/.install-updates-consent` + `.claude/.auto-install-consent`) and tracked governance artefacts (SECURITY.md, CODEOWNERS) both live in the repo. The block list inherits the same shape — project-wide policy, not per-machine preference.
- **ADR-044 — Decision-Delegation Contract** (`docs/decisions/044-decision-delegation-contract.proposed.md`) — the three open questions in this ADR are deviation-approval / direction-setting decisions per ADR-044's 6-class taxonomy (categories 1, 2, and 5: direction, deviation, taste). They cannot be resolved by agent action; this ADR queues them as proposed defaults for user batch-resolution per the anti-BUFD-for-framework-evolution clause.

## Considered Options

### Option A — Per-machine block list (`~/.claude/...`)

Persist the block list outside the repo, in a Claude Code user-space file. Block decisions belong to whichever maintainer is currently active.

- **Pros**: invisible to outside observers; no public-signal concern; no risk of leaking maintainer identity through the block list.
- **Cons**: doesn't survive cross-collaborator handoff; new clones don't inherit the list; block decisions become per-machine preference rather than project-wide policy. Inconsistent with how SECURITY.md, CODEOWNERS, and other governance artefacts work. Two maintainers reviewing the same inbound report from a known-malicious source would each have to redo the malicious classification.

**Rejected** — block decisions are project-wide policy, not per-machine preference.

### Option B — Per-repo, usernames-in-the-clear

Persist `docs/blocked-reporters.json` in the repo with reporter usernames in plaintext.

- **Pros**: easy to audit; clear traceability; no separate hashing or ID-resolution step required.
- **Cons**: a public, git-tracked block list with usernames-in-the-clear is a strong public signal. Listed users can search the repo and find themselves; this can attract attention or escalation. Higher target value for popular plugins.

**Rejected** — the public-signal concern outweighs the traceability benefit, especially given the GitHub user ID hashing alternative below preserves traceability via the user-ID-to-hash recovery path.

### Option C — Per-repo, hashed GitHub user IDs (CHOSEN)

Persist `docs/blocked-reporters.json` in the repo, recording SHA-256 hashes of GitHub numeric user IDs (not usernames). GitHub numeric user IDs are stable across username changes; hashing them produces an opaque-to-the-public artefact that is still verifiable by a maintainer who knows the original user ID.

- **Pros**: visible-but-opaque shape mitigates the public-signal concern. Stable across username changes (GitHub user IDs are immutable). Project-wide policy survives cross-collaborator handoff and new clones.
- **Cons**: un-block requires the original user ID to recompute the hash. One extra step for the un-block path; acceptable trade-off per 2026-04-26 user direction. No retroactive visibility into "who is in this list" without the recovery side.

**Chosen** — confirmed by the 2026-04-26 post-AFK-loop AskUserQuestion direction recorded on the P123 ticket.

### Option D — Per-repo with private mapping out-of-repo

Persist hashed entries in the repo + maintain a private mapping (`hash → username`) outside the repo (e.g., maintainer's local notes).

- **Pros**: maximum opacity in the tracked artefact; private mapping enables fast lookup.
- **Cons**: introduces cross-machine drift on the mapping side; no enforcement that the private mapping is kept in sync; collaborators don't share the mapping. Effectively Option A's drawback recreated on the lookup side.

**Rejected** — the mapping's local-only shape recreates Option A's cross-collaborator handoff problem.

## Decision Outcome

**Chosen: Option C — per-repo hashed GitHub user IDs.**

### The persistence shape

- **Location**: `docs/blocked-reporters.json` in the repo. Tracked in git. Inherited by new clones.
- **Identifier**: SHA-256 hash of GitHub numeric user ID (stable across username changes per GitHub's user-identity model).
- **Decision authority**: per-repo. Each adopter project maintains its own block list; no cross-repo federation in v1 (out of scope per the P123 ticket).
- **Visibility**: opaque hashes only. No usernames, no display names, no email addresses. Recovery requires the original user ID (held by whoever made the block decision; reproducible on demand).

### v1 implementation contract — audit-log-only

The first implementable slice of this ADR is **audit-log-only**: the persistence file exists and is writable, but no downstream surface enforces against it yet. P079's inbound-discovery filter and `/wr-itil:report-upstream`'s outbound-filing pre-check land in subsequent iters when those features ship. This sequencing is intentional per ADR-029 (diagnose before implement) and per the P123 ticket's explicit pacing decision: "P123 can ship independently as audit-log-only first, then gain enforcement when P079 + report-upstream integration land".

The audit-log-only slice consists of:

1. `docs/blocked-reporters.json` — primary persistent artefact. Empty array on creation.
2. `packages/itil/hooks/lib/block-list.sh` — shared helper. Functions: `is_blocked(<reporter-id-hash>)`, `add_block(<reporter-id-hash>, <evidence-ticket>, <provenance>)`, `remove_block(<reporter-id-hash>, <reason>)`, `list_blocks()`.
3. Bats coverage per ADR-005 + ADR-037: round-trip add+is_blocked, list_blocks shape, idempotent add, remove path, audit log presence, hashed-ID handling.
4. No integration with P079 or `/wr-itil:report-upstream` in v1. Those land when the consuming features ship.

### Open Questions (block transition from `proposed` → `accepted`)

The following three questions remain unresolved and require user direction per ADR-044's 6-class authority taxonomy. They are surfaced here as deviation-candidate / direction-setting items for batch resolution at the next interactive turn. Each carries a **proposed default** that an implementation iter could adopt if the user approves the proposal as-is, or override with explicit direction.

#### Q1 — Block-list shape: flat list vs structured per-channel

GitHub reports can arrive via multiple channels: issues, discussions, security advisories, pull request comments. A blocked reporter on the issues channel may or may not warrant a block on the discussions channel. The shape choice:

- **Flat list (proposed default)**: one block applies project-wide across all channels. Simpler implementation; lower per-block cognitive load. Risk: over-blocks legitimate cross-channel activity.
- **Structured per-channel**: each block names the channels it applies to. More expressive; more cognitive load per block decision. Risk: under-blocks if maintainer forgets to extend a block to a new channel.

**Proposed default**: flat list. Cross-channel behaviour appears to be the norm in observed malicious-report patterns; the per-channel shape can be added in a future amend cycle if real-world friction demonstrates the need (anti-BUFD-for-framework-evolution per ADR-044).

**Adopted 2026-04-28** — flat list (proposed default accepted). User confirmed via batch AskUserQuestion at iter 9's quota-halt: *"Flat list per-repo (Recommended — architect default)"*. Per-channel shape deferred to amend cycle if real-world friction surfaces.

#### Q2 — Block-decision provenance: which fields are recorded?

Each block-list entry needs metadata for accountability and for audit-log review. The minimum field set:

- **Proposed default**: `{type: "block"|"unblock", reporter_id_hash: <sha256>, evidence_ticket: <P###>, timestamp: <ISO-8601>, author: <git config user.email or marker>}`. Five fields per entry. Each block traces to a specific ticket; each unblock traces to a justification.
- **Lighter shape considered**: drop `author` (single-maintainer projects don't differentiate). Rejected — multi-maintainer projects need accountability. Cost is one extra field.
- **Heavier shape considered**: add `assessment_verdict`, `assessment_pipeline_version`, `evidence_link` (URL to upstream ticket), `appeal_decision_link`. Rejected for v1 — over-codifies before the assessment pipeline (P079) ships and the actual fields surface from real use.

**Proposed default**: the five-field shape above.

**Adopted 2026-04-28** — five-field shape (proposed default accepted). User confirmed via batch AskUserQuestion at iter 9's quota-halt: *"5-field shape (Recommended — architect default)"*.

#### Q3 — Un-block path: maintainer manual vs structured request

A blocked reporter who genuinely files something legitimate later (or who was wrongly classified) needs a recovery path. The shape choice:

- **Manual maintainer review only (proposed default)**: appeals route via direct message to the maintainer (e.g., email, DM, out-of-band). Maintainer makes the decision, runs `remove_block(<hash>, <reason>)`, commits. Audit log records the unblock. Simpler; matches solo-developer persona constraints.
- **Structured request channel**: a dedicated GitHub Discussion or label-based intake for appeal requests. Higher operational overhead; surfaces the block list more visibly to outside observers.

**Proposed default**: manual maintainer review only. Aligns with the per-repo opacity decision (the block list itself shouldn't advertise itself); aligns with solo-developer persona constraints (don't add operational surface ahead of demonstrated need).

**Adopted 2026-04-28 — expanded direction**. User direction verbatim: *"we need to think about this some more. Basically, as a maintainer, I won't be looking for unblock requests, so we should have a monitor of some sorts. I would then need to review and approve or reject. I expect you to bring these to me and ask and then handle the response (close request or unblock)."*

The user rejected pure-manual ("won't be looking for unblock requests") and rejected pure-structured ("higher operational overhead"). The adopted shape is **agent-monitored review-cycle**:

1. **Monitor** — a periodic check (e.g., new entry in a `request-unblock.yml` issue template, or a designated GitHub Discussion category, or some other inbound channel) that the agent watches without maintainer attention. Specific monitor channel deferred to implementation iter — the user's direction is the agent OWNS the monitoring; the maintainer is NOT expected to actively check.
2. **Surface** — when an unblock request arrives, agent surfaces it to the maintainer with sufficient context (the request's content, the original block's evidence ticket, the reporter's hash, the timestamps) for an informed approve/reject decision. AskUserQuestion-shaped per ADR-013 Rule 1.
3. **Handle response** — agent applies the decision: on approve, removes the entry from the block list and commits + closes the request acknowledging the unblock; on reject, closes the request with a reason.

Implementation work needed: monitor mechanism (channel choice + polling/event hook), surface format (what context to include in the AskUserQuestion), response-handling (commit + close-with-reason). Deferred to a future implementation iter beyond P123's audit-log-only v1 slice. Audit-log-only v1 ships without this workflow; the workflow ships in a follow-up slice.

The four-state taxonomy (proposed-with-open-questions → all-three-Adopted-but-Q3-deferred-implementation → ...) is itself worth observing for any future ADR that has multi-stage Open Questions resolution. Q1 and Q2 close this ADR's Open Questions cleanly; Q3 closes the *direction* but leaves *implementation specifics* for a future iter.

### Sequencing — when each Open Question resolves

These three questions block transition of ADR-046 from `proposed` to `accepted`. They do NOT block landing the audit-log-only v1 slice — that slice can adopt the proposed defaults as-implemented, with the explicit understanding that any of the three questions resolving differently in the future will require an amend cycle on this ADR plus a migration path on the persistence file.

The implementation iter for the audit-log-only slice should:

1. Surface this ADR's three Open Questions to the user (via AskUserQuestion or interactive batch-resolve at retro time per ADR-044).
2. Record the user's resolution in this ADR's Decision Outcome section, replacing the "Proposed default" labels with "Adopted".
3. Implement against the resolved shapes.
4. Transition this ADR from `proposed` to `accepted`.

If the implementation iter cannot reach the user (AFK loop), it adopts the proposed defaults and notes the deferred ratification in the iter's outstanding-questions queue.

## Consequences

### Good

- The persistence shape is named and traceable from day one; future implementation iters don't have to re-derive it.
- The hashed-ID visibility decision is pinned, mitigating the public-signal concern that motivated the carve-out from P079.
- The audit-log-only sequencing aligns with ADR-029 (diagnose before implement) — no helper code lands ahead of the open-question resolution.
- The three open questions are explicit, citable, and queued for batch resolution per ADR-044.
- Adopters of `@windyroad/itil` consuming the eventual block-list infrastructure inherit the same persistence shape via the marketplace, with the same Open Question batch-resolve discipline.

### Bad

- The Open Questions section is non-trivial; readers must follow the three sub-questions before assuming the contract is fully settled. Mitigated by the explicit "block transition from `proposed` → `accepted`" framing.
- A future amend cycle (any of Q1/Q2/Q3 resolving differently) requires a migration path on `docs/blocked-reporters.json` if any entries already exist. The audit-log-first sequencing minimises this — the file is empty until the first block decision.
- The audit-log-only v1 slice has no enforcement surface yet. A malicious actor can still file unlimited reports until P079 + `/wr-itil:report-upstream` integration land. The block list is a foundation, not a working defence, until those features ship.

### Neutral

- ADR-046 is a `proposed` ADR with explicit Open Questions. The proposed-with-open-questions shape is novel for this project's ADR catalogue; if it proves load-bearing across multiple ADRs, a meta-ADR may be warranted to codify the pattern. For now, this is a one-off shape on a multi-stage decision.

## Confirmation

The decision is satisfied when:

1. **Open Questions resolved** — Q1, Q2, Q3 each carry an "Adopted" decision, recorded in this ADR's Decision Outcome section. ADR-046 status transitions from `proposed` to `accepted`.
2. **`packages/itil/hooks/lib/block-list.sh` lands** — the helper exists, exposes the four named functions, and is shared-code-synced per ADR-017 if any consuming SKILL needs it.
3. **`packages/itil/hooks/test/block-list.bats` lands and stays green** — 6-8 behavioural assertions per ADR-005 + ADR-037: add+is_blocked round-trip, list_blocks shape, idempotent add, remove path, audit log presence, hashed-ID handling.
4. **`docs/blocked-reporters.json` exists in the repo** — empty array on creation, writable by the helper, tracked in git.
5. **P123 transitions to verifying** — the audit-log-only slice ships per ADR-022's verification-pending status.
6. **P079 + `/wr-itil:report-upstream` integration** — separate tickets / amend cycles. ADR-046 does not block on those; they consume the block list when they ship.

## Reassessment

Re-evaluate this ADR if any of:

- One of Q1, Q2, Q3 resolves with a shape that contradicts a proposed default and existing block-list entries already exist. Triggers an amend cycle on this ADR plus a migration path on `docs/blocked-reporters.json`.
- Cross-repo block-list federation becomes load-bearing (currently out of scope per the P123 ticket). Would warrant a sibling ADR rather than an amend, since the per-repo decision is foundational to this ADR.
- A non-GitHub reporting channel (Discord, email-only intake) becomes a primary intake surface. The hashed-GitHub-user-ID identifier scheme assumes GitHub-as-primary; non-GitHub channels would need a parallel identifier scheme or a unification ADR.
- The public-signal concern that motivated the hashing decision proves load-bearing in a way the hashing doesn't sufficiently mitigate (e.g., a small project where the recipient pool is small enough that the hash doesn't provide meaningful opacity).
- Real-world malicious-report patterns demonstrate the flat-list shape (Q1 proposed default) consistently under-blocks or over-blocks. Triggers an amend cycle on Q1.

## Related

- **P123** (`docs/problems/123-blocked-user-list-mechanism-for-inbound-report-management.open.md`) — primary ticket. ADR-046 lands the diagnosis; P123 transitions to known-error pending Q1/Q2/Q3 resolution + downstream P079/P070 integration.
- **P079** (`docs/problems/079-no-inbound-sync-of-upstream-reported-problems.open.md`) — parent ticket. P079's clear-malicious branch consumes the block list at inbound discovery + at the close-and-block atomic action.
- **P070** (`docs/problems/070-report-upstream-does-not-check-for-existing-upstream-issues.verifying.md`) — `/wr-itil:report-upstream`'s outbound-filing surface. Consumes the block list for the outbound pre-check per ADR-024 extension.
- **ADR-014** (`014-governance-skills-commit-their-own-work.proposed.md`) — commit-grain precedent. P123's transition rides with this ADR's commit per ADR-014 (one ticket-unit-of-work per commit; ADR + ticket transition + README refresh in the same commit).
- **ADR-017** (`017-shared-code-sync-pattern.proposed.md`) — shared-code-sync precedent. The eventual `block-list.sh` helper follows this pattern if consumed cross-plugin.
- **ADR-022** (`022-problem-lifecycle-verification-pending-status.proposed.md`) — lifecycle. P123 transitions to known-error today; verifying when the audit-log-only slice ships.
- **ADR-024** (`024-cross-project-problem-reporting-contract.proposed.md`) — outbound report contract. ADR-046 extends with outbound block-list pre-check.
- **ADR-029** (`029-diagnose-before-implement.proposed.md`) — diagnose-before-implement. ADR-046 is the diagnosis; implementation deferred until Open Questions resolve.
- **ADR-030** (`030-repo-local-skills-for-workflow-tooling.proposed.md`) — per-repo artefact precedent. The block list inherits the same shape.
- **ADR-037** (`037-skill-testing-strategy.proposed.md`) — testing strategy. The eventual bats coverage follows this.
- **ADR-044** (`044-decision-delegation-contract.proposed.md`) — decision-delegation contract. The three Open Questions are deviation-candidate / direction-setting items per ADR-044's 6-class taxonomy.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — primary persona served. Block-list infrastructure protects maintainer attention.
- **JTBD-202** (`docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md`) — composes. Tech-lead persona's adopter-of-`@windyroad/itil` framing inherits the same defence.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — composes. Block list as governance artefact.
