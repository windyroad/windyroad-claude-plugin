---
name: wr-itil:transition-problems
description: "Batch-advance multiple problem tickets through the lifecycle in one invocation — Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed. Loops the per-ticket /wr-itil:transition-problem mechanic (rename, Status edit, P057 re-stage, P063 external-root-cause detection, P062 README refresh) without paying N× SKILL.md reload latency or violating split-skill execution ownership. Produces ONE shared commit covering all surviving transitions per ADR-014 batch-grain. Use when closing the Verification Queue at the end of a `/wr-retrospective:run-retro` Step 4a pass, batch-closing release-aged verifyings during `/wr-itil:work-problems` AFK orchestration, or confirming multiple Step 9d verifications in `/wr-itil:manage-problem review`. Singular sibling — `/wr-itil:transition-problem` (one ticket per invocation)."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill, Agent
---

# Transition Problems — Batch Lifecycle Advance

Advance multiple problem tickets along the ITIL lifecycle in one invocation. The skill is the **batch executor** for the user-initiated transition path — it accepts a list of `<NNN> <status>` pairs, runs each pair's per-ticket mechanic inline (pre-flight checks, P063 external-root-cause detection, `git mv` + Status edit + P057 re-stage, `## Fix Released` for the `verifying` destination), refreshes `docs/problems/README.md` ONCE at the end (P062 at batch grain), and commits all surviving transitions in ONE commit per ADR-014.

This skill is the plural sibling of `/wr-itil:transition-problem`, mirroring the P071 singular/plural split precedent established by `/wr-itil:work-problem` (singular) and `/wr-itil:work-problems` (plural). Per ADR-010 amended Skill Granularity rule, batch-transition is a distinct user intent from single-transition (different ergonomics, different commit grain, different cost profile) and therefore lives on its own skill surface.

## Why this skill exists (P117)

Closing N tickets via the singular skill costs N× SKILL.md reload into the caller's context every time the singular is invoked from a batch caller (run-retro Step 4a, manage-problem review Step 9d, work-problems release-batched closures). This is the very SKILL.md-runtime-size pressure P097 captures, and the inline-batch workaround documented in P117 (running `git mv` + Edit + commit outside the singular skill's authoritative-executor scope) violates the ADR-010 amended ownership boundary.

The plural surface eliminates both costs: ONE SKILL.md load (this file), N pair iterations in-band, ONE commit at the end. Per ADR-010 amended "Split-skill execution ownership", the plural carries an inline scoped copy of the singular's per-ticket mechanic ("copy, not move") rather than re-invoking the singular via the Skill tool — Skill-tool re-invocation N times would reintroduce the very N× reload cost the ticket targets.

## Name distinction (transition-problem vs transition-problems)

- **`/wr-itil:transition-problem`** (singular) — one ticket per invocation. The authoritative executor for the single-transition user-initiated path (P093 / ADR-010 amended). Use when the user wants to transition one specific ticket and stop.
- **`/wr-itil:transition-problems`** (plural, this skill) — batch transition. Accepts a list of `<NNN> <status>` pairs and runs each through an inline copy of the per-ticket mechanic, single commit at the end. Use when closing multiple verifyings at once or batch-marking known-error after a multi-ticket review.

Both names coexist intentionally per the P071 singular/plural precedent. Plugin-developers reading this skill should recognise the same shape as `work-problem`/`work-problems`, `list-problems`, and `review-problems` — distinct intents for distinct ergonomic surfaces.

## Arguments

A space-separated list of `<NNN> <status>` pairs. Repeating the singular skill's argument shape N times — same convention, no new syntax. No `P` prefix on the ID; no `=`/`:` separator inside a pair; no CLI flag-style (`--pairs`).

```
/wr-itil:transition-problems <NNN> <status> [<NNN> <status>] ...
```

- `<NNN>` — three-digit ticket ID (e.g. `063`).
- `<status>` — destination status. One of:
  - `known-error` — Open → Known Error (root cause + workaround documented).
  - `verifying` — Known Error → Verification Pending (fix released; awaiting user verification per ADR-022).
  - `close` — Verification Pending → Closed (user has confirmed the fix works in production).

**Examples:**

```
/wr-itil:transition-problems 063 close 067 close 092 close 094 close
/wr-itil:transition-problems 070 known-error 080 verifying 094 close
```

The pair tokens are **data parameters**, not word-subcommands — the same shape rule the singular's argument table cites against P071. Pairs are processed in argument order; each runs the full per-pair mechanic independently.

If the argument count is odd, or any pair's tokens are malformed (`<NNN>` not three digits; `<status>` not in the enum), emit a usage message and stop without touching git.

## Scope

**In scope:**
- Parse the pair list and validate each pair's argument shape (count is even; IDs are `\d{3}`; statuses are in the enum).
- For each pair, run the per-ticket mechanic inline: ticket-file discovery, transition-path validation, pre-flight checks, P063 external-root-cause detection (Open → Known Error only), `git mv` to the new suffix, Status field edit, `## Fix Released` section write (Known Error → Verification Pending only), explicit P057 re-stage.
- After the loop, refresh `docs/problems/README.md` ONCE per P062 (single render reflecting all surviving renames).
- Commit ALL surviving transitions + the refreshed README in ONE commit per ADR-014 batch-grain unit-of-work.
- Report the per-pair outcome: succeeded pairs, failed pairs (with reason category), commit SHA.

**Out of scope:**
- Per-pair commits — replaced by the single batch commit at the end. The singular skill's per-invocation commit semantics are deliberately re-aggregated at this batch grain.
- Backlog re-ranking — that's `/wr-itil:review-problems`.
- Ticket creation or bare-update flows — those stay on `/wr-itil:manage-problem`.
- Parking — the `.parked.md` suffix has its own path on `/wr-itil:manage-problem`.
- Auto-transitions inside review — Step 9b uses manage-problem's in-skill Step 7 block ("copy, not move") per ADR-010 amended.
- Release draining — `push:watch` / `release:watch` are owned by the caller (`/wr-itil:work-problems` orchestrator Step 6.5, or `/wr-itil:manage-problem` Step 12).

## Steps

### 1. Parse the pair list

From `$ARGUMENTS`, tokenise by whitespace and pair off tokens (0,1) / (2,3) / ... Validate:

- Token count is even and ≥ 2. If odd or zero, emit the usage message and stop.
- Each `<NNN>` matches `^\d{3}$`. If any does not, emit the usage message naming the bad token and stop.
- Each `<status>` is one of `known-error`, `verifying`, `close`. If any is not, emit the usage message naming the bad token and stop.

If parsing fails at this stage, NO git operations have run. The user can re-invoke with corrected arguments cleanly.

### 2. Per-pair execution loop (inline copy of the singular's per-ticket mechanic)

> **Copy, not move (per ADR-010 amended Split-skill execution ownership).** The body below is a scoped inline copy of `/wr-itil:transition-problem` Steps 2–6 (discovery, validation, pre-flight, P063 detection, rename + Edit + re-stage). The per-pair commit step (singular Step 8) is INTENTIONALLY OMITTED — batch semantics replace it with the single commit in Step 4 below.
>
> Drift between the singular and this inline copy is detected by the contract-assertion bats (`packages/itil/skills/transition-problems/test/transition-problems-contract.bats`) which asserts shared substring presence (e.g. the `git add docs/problems/` re-stage phrase) in BOTH files. If you edit one, edit the other.

For each pair `(NNN, status)` in argument order:

**2a. Discover the ticket file.** Dual-tolerant lookup spans flat layout AND per-state subdir layout per RFC-002 migration window:

```bash
ls docs/problems/<NNN>-*.md docs/problems/*/<NNN>-*.md 2>/dev/null
```

If no file is found OR multiple files are found (suffix-exclusive lifecycle violation), record the pair as a failure with reason `discovery-failed` and continue to the next pair. Do NOT touch git.

**2b. Validate the transition path.** Compare the current filename suffix against the destination:

| Current suffix | `<status>` | Valid? |
|----------------|------------|--------|
| `.open.md` | `known-error` | yes |
| `.known-error.md` | `verifying` | yes |
| `.verifying.md` | `close` | yes |
| any other pairing | — | no — record as `invalid-transition` and continue |

**2c. Run pre-flight checks** for the destination (same gating as the singular):

- Open → Known Error (`known-error`): root cause documented; ≥ 1 investigation task ticked; reproduction test or reference; workaround documented; effort bucket re-rated if scope shifted (P047).
- Known Error → Verification Pending (`verifying`): fix implemented; release marker available (version, commit SHA, or date) for the `## Fix Released` section.
- Verification Pending → Closed (`close`): user has explicitly confirmed the fix works in production. AFK callers (work-problems orchestrator) MUST supply the close pair via prior user authorisation (e.g. an `AskUserQuestion`-batched closure prompt at the orchestrator layer); this skill never auto-closes on inference.

If any pre-flight fails, record the pair as `pre-flight-failed` with the failed-check list and continue to the next pair.

**2d. P063 external-root-cause detection** (Open → Known Error only — fires per pair).

Strict tokens (within Root Cause Analysis): `upstream`, `third-party`, `external`, `vendor`; or scoped npm package pattern `@[\w-]+/[\w-]+`.

```bash
if grep -iE '\b(upstream|third-party|external|vendor)\b|@[[:alnum:]_-]+/[[:alnum:]_-]+' "$problem_file"; then
  external_root_cause_detected=1
fi
```

**Already-noted check** — before firing, grep for `- **Upstream report pending** —` or `- **Reported Upstream:**` or a `## Reported Upstream` section. If present, skip the prompt for this pair.

**Branch on interactivity (per ADR-013 Rule 1 / Rule 6):**

- **Interactive** (`AskUserQuestion` available): use the same three-option prompt the singular's Step 5 documents (invoke /wr-itil:report-upstream / defer-and-note / not-actually-upstream).
- **AFK / non-interactive** (orchestrator markers — "AFK", "work-problems", "batch-work", "ALL_DONE" — present in the invoking context): default to defer-and-note. Append `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready` to the ticket's `## Related` section. Do NOT auto-invoke `/wr-itil:report-upstream` (its Step 6 security branch is interactive — per ADR-024).

The detection is per-pair; each Open → Known Error pair runs its own check independently.

**2e. Rename, edit, re-stage** (P057 staging-trap rule applied per pair).

> **Staging trap (P057).** `git mv` stages only the rename. After the `Edit` tool modifies the renamed file, you MUST explicitly `git add` it before continuing — without the explicit re-stage, the content edit leaks into the next commit. The plural inherits this rule per pair; the per-pair re-stage is non-negotiable.

```bash
# Open → Known Error
git mv docs/problems/<NNN>-<title>.open.md docs/problems/<NNN>-<title>.known-error.md
# Edit Status field to "Known Error"
git add docs/problems/<NNN>-<title>.known-error.md
```

```bash
# Known Error → Verification Pending (per ADR-022)
git mv docs/problems/<NNN>-<title>.known-error.md docs/problems/<NNN>-<title>.verifying.md
# Edit Status to "Verification Pending" AND add ## Fix Released section
# (release marker, one-sentence summary, Awaiting user verification)
git add docs/problems/<NNN>-<title>.verifying.md
```

```bash
# Verification Pending → Closed
git mv docs/problems/<NNN>-<title>.verifying.md docs/problems/<NNN>-<title>.closed.md
# Edit Status field to "Closed"
git add docs/problems/<NNN>-<title>.closed.md
```

If `git mv` or `git add` fails for a pair (e.g. the file has been moved by a parallel process), record the pair as `git-failed` with the error and continue to the next pair. Do NOT attempt to roll back prior pairs' staged renames — those are now part of the in-progress batch.

Record each pair's outcome (succeeded / failed-with-reason) for the summary in Step 5.

### 3. Partial-failure semantics (skip-and-surface)

Per architect-resolved design (2026-04-26): if a pair fails in any of the substeps above (discovery, validation, pre-flight, git-op), it is skipped and recorded as a failed pair. The loop continues with the next pair. There is NO halt, NO rollback of previously-staged surviving pairs.

Rationale grounded in existing decisions:
- ADR-014's "complete unit of work" boundary is the BATCH at this grain — a partial batch (succeeded subset) is a legitimate unit. Halting and discarding succeeded pairs (option a) loses validated work the user already authorised.
- ADR-013 Rule 6 forbids non-interactive destructive operations; rolling back staged renames (option c) requires `git reset` which is exactly the destructive class Rule 6 names.
- Mirrors the `/wr-itil:work-problems` Step 4 classifier precedent (skip-and-surface; commit succeeded work; failed pairs surfaced in summary).

**Zero-success path.** If ALL pairs failed (no pair survived to the staging step), DO NOT commit. Skip Steps 4 and 5's commit branches; emit a failure summary listing each failed pair's reason and stop without touching git.

### 4. Refresh README + commit ONCE (single commit at batch grain per ADR-014)

After the per-pair loop finishes, IF AT LEAST ONE PAIR SUCCEEDED:

**4a. Refresh `docs/problems/README.md` ONCE (P062 at batch grain).**

Per P062, every Step 7 status transition refreshes README.md. At the batch grain, the refresh runs ONCE — a single render reflecting ALL surviving renames + Status updates. Not N refreshes (that would force the README to thrash N times mid-batch and amplify diff noise).

The refresh follows the same render rules as `/wr-itil:review-problems` Step 9e (glob `docs/problems/*.open.md` / `*.known-error.md` / `*.verifying.md` / `*.parked.md`; rank open + known-error by WSJF; Verification Queue sorted by `Released date ASC` with same-day tiebreak by ID ASC per ADR-022 + P048; Parked section). It does NOT re-rank — existing WSJF values on ticket files are trusted; the refresh is a render, not a re-rank. <!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 --> Drift on the VQ sort direction re-opens P150.

**Likely-verified cell shape (P186)**: the `Likely verified?` column carries an **evidence-first** cell — `yes — observed: <evidence>` / `no — not observed` / `no — observed regression`. At batch grain the refresh writes the per-pair cell from the per-pair transition context: a `verifying` destination defaults to `no — not observed` (the batch just released the fix; evidence accrues subsequently); a `close` destination assumes session-observed evidence was the trigger for the batch close (the upstream caller — `run-retro` Step 4a, `review-problems` Step 9d — already verified the evidence) and the row exits the queue (not re-rendered as VQ). <!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 --> Drift on the cell shape re-opens P186.

```bash
git add docs/problems/README.md
```

Update the "Last reviewed" line per the **inline P134 rotation mechanism** below. The mechanism is inlined here at the execution site (not deferred via cross-document reference to `manage-problem` SKILL.md Step 5) so a single-pass agent reading this Step 4a does not silently skip the archive step. **Skipping the BEFORE-rewrite archive step destroys the displaced fragment and re-opens P331** (iter-7 + iter-8 of 2026-05-30's AFK work-problems session silently skipped the rotation in 2 of 9 transition-bearing iters under exactly that failure mode). At batch grain the rotation fires ONCE for the entire batch (not per-pair) but the per-pair semantics are otherwise identical to the singular's Step 7. The mechanism MUST execute IN ORDER:

1. **Read** line 3 of `docs/problems/README.md`: `awk 'NR==3' docs/problems/README.md` (`head -3 | tail -1` or `sed -n '3p'` are acceptable equivalents).
2. **Append-if-non-empty (BEFORE step 3, not after)** — if line 3 is non-empty AND not a same-session same-verb near-duplicate of the new batch fragment, append the existing line 3 verbatim to `docs/problems/README-history.md` under a `## YYYY-MM-DD` heading (creating the heading on first append for that date; subsequent same-day appends nest under the existing heading). Run this BEFORE the Edit-tool rewrite in step 3 — Edit's replace pattern destroys the displaced content otherwise.
3. **Rewrite** line 3 of `docs/problems/README.md` with the new batch fragment of form `> Last reviewed: YYYY-MM-DD **batch transition** — P<NNN> <status>, P<NNN> <status>, …` (e.g. `> Last reviewed: 2026-06-01 **batch transition** — P063 close, P067 close, P092 close, P094 close`). Soft cap ≤ 1024 bytes per fragment — if the cohort would exceed it, abbreviate to ID + verb only and let the per-ticket bodies carry the rationale; hard ceiling 5120 bytes per ADR-040 Tier 3 envelope.
4. **Stage both** — `git add docs/problems/README.md docs/problems/README-history.md` so the same single batch commit per ADR-014 captures both files.

Canonical rationale anchor: `manage-problem` SKILL.md Step 5 § Last-reviewed line discipline (P134). The cross-reference is preserved for the "why"; the "what" is inlined above for execution-time legibility per P331.

**4b. Commit gate (per ADR-014).**

Satisfy via one of two paths (either produces a bypass marker):

- **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
- **Fallback** (per ADR-015 / P035): if `wr-risk-scorer:pipeline` is unavailable in the current tool set, invoke `/wr-risk-scorer:assess-release` via the Skill tool — `PostToolUse:Agent` writes the equivalent bypass marker. Do NOT silently skip the gate.

**4c. Commit ONCE.**

ONE commit covers: every surviving renamed ticket file + every Status edit + every `## Fix Released` section + the refreshed `docs/problems/README.md`. NO per-pair commits.

**Commit message conventions** (batch variants extending ADR-014's table):

- Homogeneous-destination batch: `docs(problems): batch transition — close P063, P067, P092, P094 (4 tickets)`
- Mixed-destination batch: `docs(problems): batch transition — P063 close, P070 known-error, P094 verifying (3 tickets)`
- If the batch destination is `verifying` and rides with a fix commit, the commit-message scope follows the singular's pattern: `fix(<scope>): <description> (closes P063, P067)` — but the batch surface is unusual in the riding-with-fix shape; the canonical caller is verification-close housekeeping, not fix-release.

If risk is above appetite and `AskUserQuestion` is available: ask whether to commit anyway, remediate first, or park. If `AskUserQuestion` is unavailable (AFK), skip the commit and report the uncommitted state per ADR-013 Rule 6 fail-safe — apply the same rule the singular does at the same gate.

### 5. Report the outcome

Emit a structured summary:

```
## Batch transition summary

### Succeeded ({N})
| Ticket | Previous status | New status | New filename |
|--------|-----------------|------------|--------------|
| P063 | Verification Pending | Closed | docs/problems/063-...closed.md |
| P067 | Verification Pending | Closed | docs/problems/067-...closed.md |
| ...

### Failed ({M})
| Ticket | Destination | Reason |
|--------|-------------|--------|
| P099 | known-error | discovery-failed: no ticket found |
| P101 | verifying | invalid-transition: ticket is .open.md (must go to known-error first) |
| ...

Commit: {sha}  ({N tickets committed in one batch})
```

If zero pairs succeeded, the summary contains the Failed table only and explicitly notes "No commit — all pairs failed".

Release draining is owned by the caller (orchestrator Step 6.5 / manage-problem Step 12). This skill does NOT invoke `npm run push:watch` / `release:watch` on its own.

## Ownership boundary

`transition-problems` (plural) owns:
- Pair-list parse + per-pair argument validation.
- Per-pair execution (inline copy of singular Steps 2–6) — discovery, transition-path validation, pre-flight, P063 detection, rename + Edit + P057 re-stage.
- Per-pair partial-failure tracking (skip-and-surface).
- ONE README.md refresh at the end (P062 at batch grain).
- ONE ADR-014 commit at the end through the risk-scorer commit gate.
- Structured per-pair outcome summary.

`transition-problems` does NOT:
- Re-invoke `/wr-itil:transition-problem` per pair via the Skill tool — that would re-introduce the N×SKILL.md-reload cost P117 targets. Inline copy per ADR-010 amended "copy, not move".
- Run per-pair commits — only the single batch commit at the end is permitted. The singular's per-invocation commit grain is deliberately re-aggregated at this skill's batch grain.
- Re-rank the backlog (use `/wr-itil:review-problems`).
- Create tickets or run the bare-`<NNN>` update flow (use `/wr-itil:manage-problem`).
- Park tickets (use `/wr-itil:manage-problem` — `.parked.md` has its own path).
- Drain the release queue (caller owns it).

## Drift management (singular ↔ plural inline copy)

Per ADR-010 amended "Split-skill execution ownership", three call sites now share the per-ticket transition mechanic via "copy, not move":

1. `/wr-itil:transition-problem` Steps 2–8 (singular, user-initiated single).
2. `/wr-itil:transition-problems` Step 2 (this skill, user-initiated batch — inline copy of the singular's Steps 2–6, batch-aggregated commit replacing Step 8).
3. `/wr-itil:manage-problem` in-skill Step 7 block (auto-transitions, Parked path, Step 9d closure).

Drift detection lives in the contract-assertion bats. `packages/itil/skills/transition-problems/test/transition-problems-contract.bats` asserts shared substring presence (e.g. the `git add docs/problems/` re-stage phrase) in both this file and the singular SKILL.md so a future edit that drops the re-stage rule from one is immediately visible.

When the per-ticket mechanic changes (e.g. a new pre-flight check or P063 token added), update ALL THREE copies in lockstep — the contract bats will fail otherwise, surfacing the drift.

## Related

- **P117** (`docs/problems/117-no-batch-transition-for-multiple-problem-tickets.open.md`) — originating ticket. Closing 4+ tickets in one run-retro / manage-problem review costs N×SKILL.md reload OR an ownership-boundary violation; this skill closes that gap.
- **P071** (`docs/problems/071-argument-based-skill-subcommands-are-not-discoverable.open.md`) — singular/plural split precedent; established `work-problem`/`work-problems` and `list-problems`/`review-problems` siblings.
- **P093** (`docs/problems/093-transition-problem-and-manage-problem-circular-delegation-for-nnn-status-args.*.md`) — the circular-delegation ticket whose resolution gave the singular `transition-problem` ownership of the per-ticket mechanic. This skill extends that ownership to the batch grain.
- **P097** (`docs/problems/097-skill-md-runtime-size.open.md`) — the SKILL.md-runtime-size pressure cluster. P117 is a concrete cost case of P097's broader concern; this plural skill addresses the cost case directly.
- **ADR-010 amended** (`docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md` — Skill Granularity + Split-skill execution ownership) — authorises the singular/plural split AND the "copy, not move" inline-copy pattern.
- **ADR-013** — Rule 1 for interactive prompts; Rule 6 for the AFK non-interactive branch (P063 fallback inherited from the singular per pair).
- **ADR-014** — governance skills commit their own work. Batch grain is one unit of work — ONE commit at the end covering all surviving transitions.
- **ADR-022** — `.verifying.md` suffix on release; Verification Pending is a first-class status. Batch verification-close is a common caller (release-aged verifyings drained at the end of a session).
- **ADR-032** — governance skill invocation patterns. `/wr-itil:work-problems` may delegate batch closures here during AFK orchestration; this skill is foreground-synchronous in that delegation.
- **ADR-037** — contract-assertion bats pattern. The contract-bats for this skill ALSO performs cross-file drift detection between this SKILL.md and the singular's SKILL.md (the inline-copy invariant).
- **P057** — `git mv` + Edit staging trap; the per-pair re-stage rule applied N times in this skill's loop.
- **P062** — README.md refresh on every transition. At batch grain, the refresh fires ONCE at the end (single render covers all surviving renames).
- **P063** — external-root-cause detection at Open → Known Error. Fires per pair; AFK fallback inherited from the singular (append the stable Upstream report pending marker).
- **JTBD-001** (`docs/jtbd/developer/JTBD-001-enforce-governance.proposed.md`) — eliminates the N×SKILL.md reload tax + ownership-boundary violation at batch closures; serves the "without slowing down" half of the job.
- **JTBD-006** (`docs/jtbd/developer/JTBD-006-work-backlog-afk.proposed.md`) — work-problems orchestrator may delegate release-batched closures through this surface during extended AFK runs.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — singular/plural split is the established pattern; plugin-developers reading this should immediately recognise the shape.
- `packages/itil/skills/transition-problem/SKILL.md` — singular sibling. Source-of-truth for the per-ticket mechanic this skill carries an inline copy of. When the mechanic changes, update both files in lockstep.
- `packages/itil/skills/manage-problem/SKILL.md` — third call site of the per-ticket mechanic (in-skill Step 7 block). Per ADR-010 amended "copy, not move", three inline copies coexist.
- `packages/itil/skills/review-problems/SKILL.md` — sibling refresh skill; same README render contract this skill uses for the Step 4a refresh.
- `packages/itil/skills/work-problem/SKILL.md` and `packages/itil/skills/work-problems/SKILL.md` — singular/plural pair this skill mirrors.
- `packages/retrospective/skills/run-retro/SKILL.md` — Step 4a verification-close housekeeping is the canonical caller of this batch surface.

$ARGUMENTS
