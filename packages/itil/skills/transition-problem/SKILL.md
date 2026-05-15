---
name: wr-itil:transition-problem
description: Advance a problem ticket's lifecycle status — Open → Known Error, Known Error → Verification Pending (verifying), Verification Pending → Closed. Renames the ticket file, updates the Status field, and refreshes docs/problems/README.md in the same commit. Hosts the transition execution inline (pre-flight checks, P057 staging-trap handling, P063 external-root-cause detection, P062 README refresh, ADR-014 commit) per ADR-010 amended "Split-skill execution ownership". Use when the user asks to "transition", "close", "mark known-error", or "release" a specific ticket.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill
---

# Transition Problem — Lifecycle Advance

Advance a specific problem ticket along the ITIL lifecycle: Open → Known Error → Verification Pending → Closed. The skill is the **authoritative executor** for the user-initiated transition path — it identifies the ticket and the destination status, then executes the transition inline: pre-flight checks, external-root-cause detection (P063), `git mv` + Status edit with staging re-stage (P057), `## Fix Released` section write for the `verifying` destination, README.md refresh (P062), and ADR-014 commit.

This skill is phase 4 of the P071 phased-landing split of `/wr-itil:manage-problem <NNN> <status>` per ADR-010's amended Skill Granularity rule (one skill per distinct user intent). Per ADR-010's "Split-skill execution ownership" rule (P093), the skill does **not** re-invoke `/wr-itil:manage-problem` to run Step 7 (no round-trip); the deprecation-window forwarder on manage-problem routes one-way to this skill and returns its output verbatim. The in-skill Step 7 block on manage-problem remains in place for in-skill callers (Step 9b auto-transition, Parked path, Step 9d closure inside review) — "copy, not move" per ADR-010 amended.

The deprecated `/wr-itil:manage-problem <NNN> known-error` subcommand route remains as a one-way forwarder during the deprecation window but is scheduled for removal in `@windyroad/itil`'s next major version.

## Arguments

- `<NNN>` — the ticket ID (data parameter, e.g. `042`). Required.
- `<status>` — the destination status. One of:
  - `known-error` — Open → Known Error (root cause confirmed, fix path clear, fix not yet released).
  - `verifying` — Known Error → Verification Pending (fix released, awaiting user verification per ADR-022).
  - `close` — Verification Pending → Closed (user has confirmed the fix works in production).

The `<NNN>` and `<status>` tokens are **data parameters**, not word-subcommands. Per the P071 split rule (ADR-010 amended), data parameters (IDs, paths, URLs, enum destinations) are permitted; word-subcommands that name distinct user intents are not. This skill's argument shape is `data + data`, which is the same shape as `/wr-itil:report-upstream <NNN>`.

## Scope

**In scope:**
- Validate that the ticket file exists and the destination status is reachable from the current status (e.g. an `.open.md` file cannot transition directly to Verification Pending — it must go through Known Error first).
- Execute the transition inline: pre-flight checks, P063 external-root-cause detection (for the Open → Known Error destination), `git mv` to the new suffix, Status field edit, `## Fix Released` section write (for the Known Error → Verification Pending destination), P057 staging re-stage, P062 README.md refresh, ADR-014 commit.
- Report the outcome (new filename, new Status, commit SHA).

**Out of scope:**
- Backlog re-ranking — that's `/wr-itil:review-problems`.
- Ticket creation or bare-update flows — that's `/wr-itil:manage-problem` (no-args form for creation, `<NNN>` bare for update).
- Parking a ticket — that's a distinct lifecycle move handled by `/wr-itil:manage-problem` directly (the `.parked.md` suffix has its own pre-flight path including P063 external-root-cause detection for `upstream-blocked` reasons).
- Auto-transitions fired inside `/wr-itil:review-problems` Step 9b (Open → Known Error when root cause + workaround are documented) — those use manage-problem's in-skill Step 7 block per ADR-010 amended "Split-skill execution ownership" ("copy, not move").

## Steps

### 1. Parse the arguments

From `$ARGUMENTS`, extract the ticket ID (`<NNN>`, three digits) and the destination status (one of `known-error`, `verifying`, `close`). If either is missing or malformed, emit a usage message and stop:

```
Usage: /wr-itil:transition-problem <NNN> <status>
  <NNN>    — three-digit ticket ID (e.g. 042)
  <status> — one of: known-error, verifying, close
```

### 2. Discover the ticket file

Locate the ticket file by ID — dual-tolerant lookup spans both the flat layout (`docs/problems/<NNN>-<title>.<state>.md`) AND the per-state subdir layout (`docs/problems/<state>/<NNN>-<title>.md`) per RFC-002 migration window:

```bash
ls docs/problems/<NNN>-*.md docs/problems/*/<NNN>-*.md 2>/dev/null
```

If no file is found, emit: `No ticket found for ID <NNN>` and stop.

If multiple files are found (should not happen — suffix-exclusive lifecycle), emit a warning and list the matches; stop and let the user resolve.

### 3. Validate the transition path

Check the current filename suffix and verify the destination status is reachable in one step:

| Current suffix | Destination argument | Valid? |
|----------------|----------------------|--------|
| `.open.md` | `known-error` | yes |
| `.known-error.md` | `verifying` | yes |
| `.verifying.md` | `close` | yes |
| any other pairing | — | no — emit an error and stop |

If the pairing is invalid, emit a clear message naming the current status, the requested destination, and the valid next step. Do not silently skip or auto-correct — invalid transitions are almost always user typos and a clear error is the cheapest recovery.

### 4. Run pre-flight checks

Destination-specific pre-flight checks gate the transition. If any check fails, report which ones and stop — do not auto-remediate.

**Open → Known Error** (`<status>` = `known-error`) requires:

- [ ] Root cause is documented in the Root Cause Analysis section (not just "Preliminary Hypothesis")
- [ ] At least one investigation task is checked off
- [ ] A reproduction test exists or is referenced
- [ ] A workaround is documented (even if "feature disabled")
- [ ] Effort bucket re-rated against the now-documented fix strategy; if the bucket changed since creation, update the Effort / WSJF lines and note the reason (P047 — creation-time estimates drift as scope clarifies)

**Known Error → Verification Pending** (`<status>` = `verifying`) requires:

- [ ] The fix has been implemented (the transition typically rides with the `fix(<scope>): ... (closes P<NNN>)` commit)
- [ ] A release marker is available (version, commit SHA, or date) so the `## Fix Released` section can name it

**Verification Pending → Closed** (`<status>` = `close`) requires:

- [ ] The user has explicitly confirmed the fix works in production (this skill never auto-closes on inference — only on explicit user confirmation or orchestrator-supplied `close` argument)

### 5. External-root-cause detection (P063 — Open → Known Error only)

Fires on the Open → Known Error transition only. Parking with the `upstream-blocked` reason reuses the same mechanism but is handled by `/wr-itil:manage-problem`'s Step 7 (this skill does not park).

**Strict detection tokens** (any of the following within the Root Cause Analysis section counts as a hit):

- Literal label words: `upstream`, `third-party`, `external`, `vendor`.
- Scoped npm package pattern: `@[\w-]+/[\w-]+` (e.g. `@anthropic/claude-code`, `@windyroad/itil`).

Bash heuristic:

```bash
if grep -iE '\b(upstream|third-party|external|vendor)\b|@[[:alnum:]_-]+/[[:alnum:]_-]+' "$problem_file"; then
  external_root_cause_detected=1
fi
```

Detection is intentionally **strict** (explicit label or scoped-npm package only) to avoid prompt fatigue (P063 Direction decision). A passing reference to a bare package name (`gh`, `npm`) does NOT trigger the prompt.

**Already-noted check** — before firing the prompt, grep the ticket for the stable marker `- **Upstream report pending** —` (written by option 2 / the AFK fallback below) or `- **Reported Upstream:**` / a `## Reported Upstream` section (written by `/wr-itil:report-upstream` Step 7 back-write per ADR-024 Confirmation criterion 3a). If any of those are already present, skip the prompt — the detection has already fired on a prior run.

**If the detection fires and nothing has been noted yet** (per ADR-044 framework-resolution boundary): the agent applies the AFK fallback default WITHOUT firing `AskUserQuestion`. Per ADR-044, this decision IS framework-resolved — the safe action is "defer and note marker", and the user can correct via authentic-correction (ADR-044 category 6) if a manual `/wr-itil:report-upstream` invocation is wanted instead. Per-transition `AskUserQuestion` for upstream-detection is sub-contracting framework-resolved decisions back to the user (lazy deferral per Step 2d Ask Hygiene Pass classification).

**Default behaviour (silent agent action, per ADR-044)**: append the pending-upstream-report line to the ticket's `## Related` section using the stable marker:

```
- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready
```

The marker wording is fixed so subsequent runs (and the work-problems `upstream-blocked` skip path) can detect "already noted" without re-firing. The transition proceeds normally after the marker is appended.

**Recovery / override paths** (user-initiated, not asked-per-transition):

- If the detection misfired (false positive — not actually upstream), user appends `- **Upstream report pending** — false positive; detection misfire` directly to the ticket's `## Related` section. The next detection-pass observes the marker and skips firing again.
- If the user wants to invoke `/wr-itil:report-upstream` immediately rather than deferring, they invoke it directly (`/wr-itil:report-upstream <NNN> <upstream-repo-url>`). The skill writes the `## Reported Upstream` appendage per ADR-024.

**AFK and interactive modes use identical behaviour** — the silent-default-with-recovery-path shape is the framework-resolution boundary application; there's no `AskUserQuestion`-vs-fallback differentiation.

### 6. Rename the file, edit content, and re-stage (P057 staging trap)

Per destination, run the rename + edit + explicit re-stage sequence. The explicit re-stage after `Edit` is mandatory — without it the content edit leaks into the next commit and the audit trail breaks.

> **Staging trap (P057).** `git mv` stages only the rename — it does NOT pick up subsequent `Edit`-tool content changes. After the `Edit` tool modifies the renamed file (Status field, `## Fix Released` section, etc.), re-stage it explicitly: `git add <new>`. Without the explicit re-stage, the transition commit captures the rename-only change and the content edit leaks into the next commit, corrupting the audit trail.

**Open → Known Error**:

```bash
git mv docs/problems/<NNN>-<title>.open.md docs/problems/<NNN>-<title>.known-error.md
# ... use the Edit tool to update the Status field to "Known Error" ...
git add docs/problems/<NNN>-<title>.known-error.md
```

**Known Error → Verification Pending** (per ADR-022, on release):

```bash
git mv docs/problems/<NNN>-<title>.known-error.md docs/problems/<NNN>-<title>.verifying.md
# ... use the Edit tool to update Status to "Verification Pending" AND add the `## Fix Released` section ...
git add docs/problems/<NNN>-<title>.verifying.md
```

The `## Fix Released` section contains: release marker (version, commit SHA, or date), one-sentence fix summary, "Awaiting user verification" line, and any exercise evidence from the releasing session. The `.verifying.md` suffix signals to every downstream consumer (work-problems classifier, review step 9d, README rendering) that the remaining work is user-side verification — no file-body scan needed.

When this transition is folded into a `fix(<scope>): ... (closes P<NNN>)` commit (the common case), the `git mv` + `Edit` + re-stage + README refresh all join that single commit — never split across commits.

**Verification Pending → Closed**:

```bash
git mv docs/problems/<NNN>-<title>.verifying.md docs/problems/<NNN>-<title>.closed.md
# ... use the Edit tool to update the Status field to "Closed" ...
git add docs/problems/<NNN>-<title>.closed.md
```

### 7. Refresh docs/problems/README.md (P062)

Every Step 7 status transition regenerates `docs/problems/README.md` and stages it in the same commit so the dev-work table, Verification Queue, Parked section, and "Last reviewed" line never lag the on-disk ticket inventory. Without this step, README.md accumulates staleness between review invocations.

The refresh uses the same rendering rules as `/wr-itil:review-problems` Step 9e (glob `docs/problems/*.open.md` / `*.known-error.md` / `*.verifying.md` / `*.parked.md`; rank open/known-error by WSJF; list verifyings in the Verification Queue ordered by release age; list parkeds in the Parked section) but skips the full re-scoring pass — existing WSJF values on the ticket files are trusted. The refresh is a render, not a re-rank.

**Verification Queue sort direction (P150)**: Verification Queue rows are sorted by `Released date ASC` (oldest at row 1; same-day releases tiebreak by ID ASC) per ADR-022 + P048 user-task semantics — older entries are the most likely-verified candidates the user wants to surface first when closing the queue. <!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 --> Drift here re-opens P150.

**Likely-verified cell shape (P186)**: the `Likely verified?` column carries an **evidence-first** cell — `yes — observed: <evidence>` / `no — not observed` / `no — observed regression`. On a Known Error → Verification Pending transition the refresh writes `no — not observed` as the default (no observed evidence yet at the moment of release). On a Verification Pending → Closed transition the closing commit's session-observed evidence should populate the cell as `yes — observed: <evidence>` before the row exits the queue. <!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 --> Drift on the cell shape re-opens P186.

**Mechanism:**

1. After renaming + Editing + `git add`-ing the transitioned ticket file (per the staging-trap rule above), regenerate `docs/problems/README.md` in-place reflecting the new filename set and the transitioned ticket's new Status.
2. `git add docs/problems/README.md` — stage the refreshed README with the same commit as the transition.
3. Update the "Last reviewed" line per the **Last-reviewed line discipline (P134)** contract documented in `manage-problem` SKILL.md Step 5 — name the transition as the most-recent fragment (e.g. `P<NNN> <status> — <one-line fix summary>`); displaced prior fragments rotate to `docs/problems/README-history.md` (forward-chronology archive, soft cap ≤ 1024 bytes per fragment, hard ceiling 5120 bytes per ADR-040 Tier 3 envelope, surfaced advisory-only by `packages/itil/scripts/check-problems-readme-budget.sh`). When the rotation displaces prior content, the staged file set MUST include both `docs/problems/README.md` AND `docs/problems/README-history.md` per ADR-014 single-commit grain.

### 8. Commit per ADR-014

Governance skills commit their own work. Transition commits include the renamed ticket file + any content edits + the refreshed `docs/problems/README.md`.

**Commit gate** — satisfy via one of two paths (either produces a bypass marker):

- **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
- **Fallback**: if `wr-risk-scorer:pipeline` is not available in the current tool set (e.g. this skill is running inside a spawned subagent), invoke `/wr-risk-scorer:assess-release` via the Skill tool. Per ADR-015 it wraps the same pipeline subagent and the `PostToolUse:Agent` hook writes an equivalent bypass marker. Do not silently skip the gate because the primary path is unavailable — the fallback exists specifically to close this gap (see P035).

**Commit message conventions**:

- Open → Known Error transition (standalone): `docs(problems): P<NNN> known error — <root cause summary>`
- Known Error → Verification Pending (folded with fix): `fix(<scope>): <description> (closes P<NNN>)` — per ADR-022, include the rename-to-`.verifying.md` + `## Fix Released` section in the same commit
- Known Error → Verification Pending (standalone, no fix riding with it): `docs(problems): P<NNN> verification pending — <release marker>`
- Verification Pending → Closed: `docs(problems): close P<NNN> <title>`

If risk is above appetite and `AskUserQuestion` is available: ask whether to commit anyway, remediate first, or park the work. If `AskUserQuestion` is unavailable (AFK), skip the commit and report the uncommitted state (ADR-013 Rule 6 fail-safe). This applies only to the risk-above-appetite branch, not to the delegation-unavailable case above.

### 9. Report the outcome

Report: ticket ID, previous Status, new Status, new filename, commit SHA. If the destination was `verifying`, name the `## Fix Released` section's release marker so the user can correlate with the shipped version.

Release draining is owned by the caller — `/wr-itil:manage-problem` Step 12 (interactive) or the `/wr-itil:work-problems` orchestrator (AFK, Step 6.5 cadence). This skill does not invoke `npm run push:watch` / `release:watch` on its own.

## Ownership boundary

`transition-problem` owns (for the user-initiated transition path):
- Argument parsing (`<NNN> <status>`).
- Ticket-file discovery via the dual-tolerant lookup `ls docs/problems/<NNN>-*.md docs/problems/*/<NNN>-*.md` (RFC-002 transitional shape; both layouts).
- Destination-reachability validation (Open → Known Error → Verification Pending → Closed, one step at a time).
- Pre-flight checks for the supplied destination.
- P063 external-root-cause detection (Open → Known Error only) — including the AFK fallback that appends the stable `- **Upstream report pending** —` marker.
- `git mv` rename + Status field edit + (for `verifying`) `## Fix Released` section write + explicit P057 re-stage.
- `docs/problems/README.md` refresh (P062) staged alongside the transition.
- ADR-014 commit through the risk-scorer commit gate.

`transition-problem` does NOT:
- Re-invoke `/wr-itil:manage-problem` to run Step 7 — the deprecation-window forwarder on manage-problem is one-way (P093 / ADR-010 amended "Split-skill execution ownership", no round-trip).
- Re-rank the backlog — that's `/wr-itil:review-problems`.
- Create tickets or run the bare-`<NNN>` update flow — those stay on `/wr-itil:manage-problem`.
- Park tickets — the `.parked.md` suffix has its own path on `/wr-itil:manage-problem` (P063 AFK fallback fires there too).
- Auto-transition inside review — Step 9b's Open → Known Error auto-transition uses manage-problem's in-skill Step 7 block ("copy, not move").
- Drain the release queue — `push:watch` / `release:watch` are owned by the caller (`/wr-itil:manage-problem` Step 12, or the `/wr-itil:work-problems` orchestrator).

## Related

- **P071** (`docs/problems/071-argument-based-skill-subcommands-are-not-discoverable.open.md`) — originating ticket. This skill is phase 4 of the P071 phased-landing plan (list-problems was phase 1; review-problems was phase 2; work-problem was phase 3).
- **ADR-010 amended** (`docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md` — Skill Granularity section) — canonical skill-split naming + forwarder contract + `deprecated-arguments: true` frontmatter flag.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 1 for interactive prompts; Rule 6 for the AFK non-interactive branch.
- **ADR-014** — governance skills commit their own work. This skill owns the per-transition commit (P093 — authoritative executor for the user-initiated path).
- **ADR-022** — `.verifying.md` suffix on release; Verification Pending is a first-class status distinct from Known Error. Known Error → Verification Pending is the most common transition this skill forwards.
- **ADR-032** — governance skill invocation patterns. `/wr-itil:work-problems` may delegate transition iterations to this skill during AFK release orchestration.
- **ADR-037** (`docs/decisions/037-skill-testing-strategy.proposed.md`) — contract-assertion bats pattern applied to this skill.
- **P057** — `git mv` + Edit staging trap rationale; the delegated Step 7 block implements the re-stage. Named here as a transitive contract so callers can reason about the dependency.
- **P062** — `/wr-itil:review-problems` is the canonical README.md cache writer, but Step 7 transitions also refresh README.md in-place per P062's mechanism. Named here as a transitive contract.
- **P186** — evidence-first `Likely verified?` cell shape (`yes — observed: <evidence>` / `no — not observed` / `no — observed regression`); `<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->` marker drives cross-skill drift detection (P138 / P150 fix-shape precedent).
- **P063** — external-root-cause detection at Open → Known Error and at the `upstream-blocked` park path. The delegated Step 7 block owns the prompt; this skill inherits the AFK fallback without re-implementing.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — discoverable surface via `/wr-itil:` autocomplete. Users type `/wr-itil:transition-problem 042 known-error` rather than remembering the `manage-problem <NNN> known-error` subcommand.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — one skill per distinct user intent.
- `packages/itil/skills/manage-problem/SKILL.md` — hosts the deprecation-window forwarder for the `manage-problem <NNN> <status>` form (one-way to this skill, no round-trip per P093). Also retains its own in-skill Step 7 block for in-skill callers (Step 9b auto-transition, Parked path, Step 9d closure) per ADR-010 amended "Split-skill execution ownership" — copy, not move.
- **P093** (`docs/problems/093-transition-problem-and-manage-problem-circular-delegation-for-nnn-status-args.*.md`) — the circular-delegation ticket that authorised this skill's absorbing the Step 7 block inline.
- `packages/itil/skills/review-problems/SKILL.md` — sibling refresh skill; this skill's transitions trigger the same README.md regeneration mechanism P062 codifies.
- `packages/itil/skills/list-problems/SKILL.md` — sibling read-only display skill; same cache contract.
- `packages/itil/skills/work-problem/SKILL.md` — sibling selection skill; delegates per-ticket execution (including transitions) through `/wr-itil:manage-problem`.

$ARGUMENTS
