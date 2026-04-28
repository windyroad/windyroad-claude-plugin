---
name: wr-itil:reconcile-readme
description: Detect and correct drift between docs/problems/README.md and the on-disk ticket inventory. Wraps the diagnose-only `packages/itil/scripts/reconcile-readme.sh` script with an agent-applied-edits pattern that preserves narrative content (the "Last reviewed" prose paragraph and Closed-section closure-via free text). Use when README WSJF Rankings, Verification Queue, or Closed sections drift from filesystem state — typically detected by manage-problem Step 0 preflight or work-problems Step 0 preflight.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# Reconcile Problem Backlog README

Reconcile `docs/problems/README.md` against on-disk ticket state when drift is detected. This is the cross-session robustness layer ON TOP of P094 (refresh-on-create) and P062 (refresh-on-transition). Both per-operation contracts hold their per-session evidence — but if any past session committed a ticket change without staging the README refresh, the next session inherits a stale README that no per-operation contract retroactively fixes.

This skill closes that gap. It runs the diagnose-only mechanical drift detector, then applies the corrections to the README in a way that preserves human-curated narrative content.

## Scope

Reconcile drift between `docs/problems/README.md` and these on-disk ticket states:

| File suffix | Belongs in README section | Drift class |
|------------|---------------------------|-------------|
| `*.open.md` / `*.known-error.md` | WSJF Rankings | MISSING (file exists, row absent) or DRIFT (row claims wrong status) |
| `*.verifying.md` | Verification Queue | MISSING (file exists, row absent) or DRIFT (WSJF Rankings row stale) |
| `*.closed.md` | Closed (curated, not exhaustive) | MISMATCH (Closed row points to wrong-status file) or STALE (still in WSJF / VQ) |
| `*.parked.md` | Parked (own section) | not enforced — Parked is its own narrative table |

Out of scope:
- Re-rating WSJF or Effort. The script trusts each ticket file's stored values; re-ranking happens in `/wr-itil:review-problems`.
- Editing ticket file bodies. Reconciliation is README-only.
- Migrating between status suffixes. That belongs in `/wr-itil:transition-problem`.

## When invoked

Three invocation surfaces, all routed through this skill so the agent-applied-edits logic stays single-sourced:

1. **Direct user invocation**: `claude /wr-itil:reconcile-readme` — interactive when the user spots drift in the README.
2. **Manage-problem Step 0 preflight halt**: when `/wr-itil:manage-problem` Step 0 detects drift via the script, it halts with a directive to invoke this skill (interactive) or auto-applies via this skill in non-interactive mode (AFK orchestrator per ADR-013 Rule 6).
3. **Work-problems Step 0 preflight halt**: when `/wr-itil:work-problems` Step 0 detects drift via the script, the same halt-with-directive / auto-apply behaviour applies.

## Steps

### Step 1. Run the diagnose-only script

Invoke the mechanical drift detector:

```bash
bash packages/itil/scripts/reconcile-readme.sh docs/problems
```

Exit codes:
- `0` — clean. No drift; nothing to do. Report "Reconciliation: clean (0 drift entries)" and exit.
- `1` — drift detected. The script prints one structured row per drift entry to stdout (each ≤ 150 bytes per ADR-038 progressive-disclosure budget). Continue to Step 2.
- `2` — parse error. README is missing, malformed, or section headers are absent. Halt with the parse-error message; this is a deeper repair that needs investigation, not mechanical reconciliation. In AFK mode (ADR-013 Rule 6), halt-with-report; do not attempt edits.

### Step 2. Bucket the drift entries by section

Each drift line is one of four shapes:

| Marker | Meaning | Required edit |
|--------|---------|---------------|
| `DRIFT    P<NNN> wsjf-rankings: claims=open actual=<X>` | README WSJF Rankings row claims Open but file is `<X>` | REMOVE the row from WSJF Rankings; if `<X>=verifying`, ADD to Verification Queue; if `<X>=closed`, optionally ADD to Closed |
| `MISSING  P<NNN> wsjf-rankings: actual=<X>` | File exists as `.open.md` / `.known-error.md`; row absent from WSJF Rankings | ADD a row to WSJF Rankings, sourced from the ticket file's `**WSJF**`, `**Priority**`, `**Effort**`, `**Status**`, and `# Problem <NNN>: <title>` line |
| `MISSING  P<NNN> verification-queue: actual=verifying` | File exists as `.verifying.md`; row absent from Verification Queue | ADD a row to Verification Queue, sourced from the ticket file's `## Fix Released` marker (release marker + date) and title |
| `STALE    P<NNN> verification-queue: actual=<X>` | Row in Verification Queue but file is `<X>` (typically `closed`) | REMOVE the row from Verification Queue |
| `MISMATCH P<NNN> closed: actual=<X>` | Row in Closed section names a non-`.closed.md` file | REMOVE the row from Closed (or fix the ID — investigate) |

### Step 3. Read the affected ticket files for ADD edits

For each `MISSING` entry, read the ticket file to extract the row data:

```bash
# For WSJF Rankings ADD:
grep -E '^\*\*(Status|Priority|Effort|WSJF)\*\*:' docs/problems/<NNN>-*.open.md
grep -E '^# Problem <NNN>:' docs/problems/<NNN>-*.open.md
```

Render the WSJF Rankings row in the existing format:

```
| <WSJF> | P<NNN> | <title> | <severity> | <status> | <effort> |
```

For each `MISSING` Verification Queue entry, read the `## Fix Released` block:

```bash
sed -n '/^## Fix Released/,/^## /p' docs/problems/<NNN>-*.verifying.md
```

Render the Verification Queue row in the existing format:

```
| P<NNN> | <title> | <release marker> | <Likely verified? per P048 Candidate 4: yes if ≥14 days, else no (<N> days)> |
```

### Step 4. Apply edits via Edit tool — preserve narrative

This is the load-bearing step. Use the `Edit` tool to apply each row-level change. DO NOT regenerate the entire README from scratch — the per-Closed-row free-text closure-via column is human-curated narrative that a full regeneration would destroy. (The "Last reviewed:" line is now subject to the **Last-reviewed line discipline (P134)** described in Step 5 below — it carries only the most-recent fragment, not an ever-growing prose paragraph; the displaced history lives in `docs/problems/README-history.md`. Step 5 owns the line-3 update; Step 4 leaves it untouched.)

For each REMOVE: `Edit` with the existing row as `old_string`, and remove it (replace with empty string) or replace with a re-positioned row in another section (REMOVE-from-WSJF-Rankings + ADD-to-Verification-Queue is two Edit operations: one to delete the WSJF row, one to insert the VQ row).

For each ADD to WSJF Rankings: locate the correct WSJF position by descending order. Use `Edit` to insert the new row immediately above the next-lower-WSJF row (or append at the bottom of the table if the new row's WSJF is the lowest). The Edit's `old_string` is the line that the new row inserts above; the `new_string` is the new row + the same line below.

For each ADD to Verification Queue: append at the bottom of the VQ table (the table is loosely sorted by release age, oldest first; recent releases land at the bottom).

After all edits, re-run `packages/itil/scripts/reconcile-readme.sh docs/problems` to confirm exit 0. If the second run still reports drift, investigate the residual edits — do NOT re-run reconciliation in a loop, as that hides systematic edit failures.

### Step 5. Update the "Last reviewed" annotation per P134 truncation discipline

Apply the **Last-reviewed line discipline (P134)** contract documented in `manage-problem` SKILL.md Step 5 — line 3 carries ONE most-recent fragment naming this reconciliation; the prior content rotates to `docs/problems/README-history.md` (forward-chronology archive, soft cap ≤ 1024 bytes per fragment, hard ceiling 5120 bytes per ADR-040 Tier 3 envelope, surfaced advisory-only by `packages/itil/scripts/check-problems-readme-budget.sh`).

**Mechanism**:

1. Read the current line 3 of `docs/problems/README.md` (e.g. `awk 'NR==3' docs/problems/README.md`).
2. If the current line 3 is non-empty and not a same-day reconciliation duplicate, append it to `docs/problems/README-history.md` under a `## YYYY-MM-DD` heading (creating the heading on first append for that date).
3. Replace line 3 of README.md with the new fragment of the form:

> Last reviewed: 2026-MM-DD **README reconciled** — (N) drift entries corrected: <comma-separated ID list>. Reconciliation contract per P118 + ADR-014 amended ("Reconciliation as preflight robustness layer").

Keep the new fragment ≤ 1024 bytes (soft cap) and certainly ≤ 5120 bytes (hard ceiling). Do NOT prepend `Prior:` segments. Do NOT re-write the existing prose inline — the displaced content lives in `README-history.md` going forward; truncation is the contract, not a side effect.

**Rationale (P134)**: this skill previously documented the line as "an ever-growing prose paragraph". That convention is what produced the 76-KB line-3 that broke the Read tool entirely. The reconcile path was a load-bearing site of the bloat — every reconcile that happened under the old convention re-wrote line 3 unbounded. The new discipline closes the surface for reconcile parity with `manage-problem` Step 5 P094, Step 6 P094, Step 7 P062, and the sibling `transition-problem`, `transition-problems`, `review-problems` skills.

### Step 6. Commit (when invoked from an AFK orchestrator subprocess)

In AFK mode (per ADR-013 Rule 6), commit the reconciled README in a dedicated single-purpose commit:

```bash
git add docs/problems/README.md
git commit -m "chore(problems): reconcile README against filesystem (P118)"
```

When invoked interactively, do NOT auto-commit — present a diff summary to the user and let them stage + commit. The reconciled state should always be staged together (no partial reconciliation) — when the agent has applied N edits in Step 4, all N belong in the same commit.

## ADR alignment

- **ADR-014** (governance skills commit their own work) — amended to add "Reconciliation as preflight robustness layer" sub-rule. P094 and P062 cover per-operation refresh; this skill covers cross-session drift detection + correction.
- **ADR-022** (Verification Pending lifecycle status conventions) — Confirmation criterion 3 extended to "and matches the Verification Queue table in `README.md` modulo narrative content".
- **ADR-038** (Progressive disclosure for governance tooling context) — script output is per-row terse (≤150 bytes per drift entry); the agent expands narrative-aware edits on demand.
- **ADR-005** (Plugin testing strategy) — script-level bats lives at `packages/itil/scripts/test/reconcile-readme.bats`; ADR-037 (skill testing) governs this skill's own contract bats.
- **ADR-013** (Structured interaction) — Rule 6 (non-interactive fail-safe) governs the AFK auto-apply branch.

## Confirmation

This skill's contract holds when:
1. The script `packages/itil/scripts/reconcile-readme.sh` is read-only — no live README mutation in the script layer (mutation only in this skill's Step 4, via the Edit tool).
2. Each agent-applied edit preserves the README's narrative content (prose paragraph at top, Closed section free text).
3. After Step 4 + Step 5, a re-run of the script reports exit 0 (clean).
4. In AFK mode, the reconciled README rides a single commit (Step 6 single-purpose commit).
5. The skill is invoked from `/wr-itil:manage-problem` Step 0, `/wr-itil:work-problems` Step 0, AND direct user invocation — no other invocation surface (e.g., `/wr-itil:transition-problem` does NOT call this skill; per architect verdict P062 already covers transition-time refresh inside the same commit, redundant preflight here would pay the cost on every transition).

## Related

- `packages/itil/scripts/reconcile-readme.sh` — the diagnose-only mechanical drift detector.
- `packages/itil/scripts/test/reconcile-readme.bats` — script-level bats per ADR-005.
- `packages/itil/skills/manage-problem/SKILL.md` — invokes this skill from Step 0 preflight.
- `packages/itil/skills/work-problems/SKILL.md` — invokes the script (not the skill) from Step 0 preflight; halts with directive on drift.
- `docs/problems/118-readme-drifts-from-filesystem-truth-despite-refresh-contracts-closed.open.md` — the originating problem ticket.
- `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md` — amended Reconciliation sub-rule.
- `docs/decisions/022-problem-lifecycle-verification-pending-status.proposed.md` — Confirmation criterion 3 extension.
- **P094** (`docs/problems/094-...closed.md`) — refresh-on-create. Composes; this skill is robustness on top, not supersession.
- **P062** (`docs/problems/062-...closed.md`) — refresh-on-transition. Composes; same.
