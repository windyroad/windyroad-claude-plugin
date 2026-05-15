---
name: wr-itil:list-problems
description: List open and known-error problem tickets from docs/problems/ sorted by WSJF priority. Read-only display of the current backlog — no edits, no interaction. Shown as a markdown table with ID, title, severity, status, and effort columns.
allowed-tools: Read, Bash, Grep, Glob
---

# List Problems

Display the current problem backlog — open and known-error tickets — sorted by Weighted Shortest Job First (WSJF) priority. This skill is a pure read-only view of `docs/problems/`; it does not edit, transition, close, or create tickets. For those operations, use the dedicated skills (`/wr-itil:manage-problem`, `/wr-itil:transition-problem`, etc.).

This skill is the P071 phased-landing split of `/wr-itil:manage-problem list` per ADR-010 amended Skill Granularity rule: one skill per distinct user intent. The original `/wr-itil:manage-problem list` subcommand route remains as a thin-router forwarder during the deprecation window but is scheduled for removal in `@windyroad/itil`'s next major version.

## Scope

Included in the ranking table (RFC-002 migration window — each glob is dual-tolerant, covering BOTH the flat `docs/problems/<NNN>-<title>.<state>.md` filename-suffix layout AND the per-state subdir `docs/problems/<state>/<NNN>-<title>.md` layout):

- `docs/problems/*.open.md` + `docs/problems/open/*.md` — open tickets (under investigation)
- `docs/problems/*.known-error.md` + `docs/problems/known-error/*.md` — known errors (root cause confirmed, fix NOT yet released)

Shown in separate sections, excluded from the dev-work WSJF ranking per ADR-022:
- `docs/problems/*.verifying.md` + `docs/problems/verifying/*.md` — Verification Pending (fix released, awaiting user verification; WSJF multiplier 0)
- `docs/problems/*.parked.md` + `docs/problems/parked/*.md` — Parked on upstream or user-suspended (WSJF multiplier 0)

`docs/problems/*.closed.md` + `docs/problems/closed/*.md` is omitted entirely (the view is of active backlog, not the closed archive).

## Steps

### 1. Check README.md cache freshness

Reuse the same `git log`-based freshness test as `/wr-itil:manage-problem review` Step 9 (per P031 — filesystem mtime is unreliable in worktrees and fresh checkouts, so git history is the authoritative staleness signal):

```bash
readme_commit=$(git log -1 --format=%H -- docs/problems/README.md 2>/dev/null)
if [ -z "$readme_commit" ] || \
   git log --oneline "${readme_commit}..HEAD" -- 'docs/problems/*.md' 'docs/problems/*/*.md' ':!docs/problems/README.md' 2>/dev/null | grep -q .; then
  # Pathspec pair `'docs/problems/*.md' 'docs/problems/*/*.md'` is the
  # RFC-002 dual-tolerant transitional shape — covers BOTH the flat
  # layout AND the per-state subdir layout.
  echo "stale"
fi
```

**Cache fresh** (no output): read `docs/problems/README.md` directly — it already contains the ranked table from the last review. Display the WSJF Rankings section + Verification Queue section + Parked section as-is. Note in the output: "Using cached ranking from [timestamp in README.md]".

**Cache stale** (prints "stale") or `README.md` missing: run the live scan in Step 2.

### 2. Live scan (cache-stale fallback)

Enumerate the backlog files via dual-tolerant globs (RFC-002 migration window — each line covers BOTH the flat `<NNN>-<title>.<state>.md` filename-suffix layout AND the per-state subdir `<state>/<NNN>-<title>.md` layout):

```bash
ls docs/problems/*.open.md docs/problems/*.known-error.md docs/problems/open/*.md docs/problems/known-error/*.md 2>/dev/null
ls docs/problems/*.verifying.md docs/problems/verifying/*.md 2>/dev/null  # for Verification Queue section
ls docs/problems/*.parked.md docs/problems/parked/*.md 2>/dev/null        # for Parked section
```

For each `.open.md` and `.known-error.md` file, read the `**Status**`, `**Priority**`, `**Effort**`, and `**WSJF**` lines from the frontmatter section. Compute WSJF if missing: `WSJF = (Severity × StatusMultiplier) / EffortDivisor` per `/wr-itil:manage-problem` WSJF Prioritisation. Default to M (divisor 2) when Effort is absent; flag missing scores so the user knows a review is overdue.

For each `.verifying.md` file, read the `## Fix Released` marker. The `Likely verified?` column carries an **evidence-first** cell per P186 (supersedes the original P048 Candidate 4 14-day heuristic). <!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 --> When this skill runs against a stale cache, the live-scan path reads the cell value from the `.verifying.md` ticket's `## Fix Released` section (or carries forward the prior cell value from the cached README when present); it does NOT compute the cell from age — that responsibility moved to `/wr-itil:review-problems` Step 4 (user confirmation populates `yes — observed: …`) and `run-retro` Step 4a close-on-evidence citations.

### 3. Display

Render three sections matching the README.md format so cached and live output look identical:

**WSJF Rankings** — dev-work queue (open + known-error), sorted by WSJF descending:

```
| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| <score> | P<NNN> | <title> | <severity> | <status> | <effort> |
```

**Verification Queue** — `.verifying.md` tickets, sorted by `Released date ASC` (oldest at row 1; same-day releases tiebreak by ID ASC) per ADR-022 + P048 user-task semantics. <!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 --> Drift here re-opens P150. The `Likely verified?` column carries an **evidence-first** cell per P186 — three canonical values: `yes — observed: <evidence>`, `no — not observed` (default for newly-released tickets), `no — observed regression`. <!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 --> Drift on the cell shape re-opens P186.

```
| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|
| P<NNN> | <title> | <release marker> | <yes — observed: …  /  no — not observed  /  no — observed regression> |
```

**Parked** — `.parked.md` tickets:

```
| ID | Title | Reason | Parked since |
|----|-------|--------|-------------|
| P<NNN> | <title> | <reason> | <date> |
```

If a section is empty, omit it rather than rendering an empty header.

### 4. Trailing suggestions

After the tables, print one of two short pointers depending on what the output showed:

- When dev-work queue is non-empty: `Run /wr-itil:work-problem to work the highest-WSJF ticket, or /wr-itil:manage-problem <NNN> to update a specific ticket.` (Note: `/wr-itil:work-problem` is singular — distinct from `/wr-itil:work-problems` plural AFK orchestrator.)
- When Verification Queue is non-empty: `Run /wr-itil:manage-problem review to trigger the verification prompt for pending tickets.`

## Ownership boundary

`list-problems` does not modify, rename, or commit any files. If the README.md cache is stale, `list-problems` performs a live scan but does NOT rewrite `README.md` — refreshing the cache is `/wr-itil:manage-problem review`'s ownership. The trailing-suggestion pointer surfaces this boundary so the user can refresh via the correct skill when they notice stale output.

## Related

- **P071** (`docs/problems/071-argument-based-skill-subcommands-are-not-discoverable.open.md`) — originating ticket. This skill is phase 1 of the P071 phased-landing plan.
- **ADR-010 amended** (`docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md` — Skill Granularity section) — canonical skill-split naming + forwarder contract + `deprecated-arguments: true` frontmatter flag.
- **ADR-022** (`docs/decisions/022-verification-pending-status.proposed.md`) — Verification Pending status conventions; `.verifying.md` exclusion from WSJF ranking.
- **ADR-037** (`docs/decisions/037-skill-testing-strategy.proposed.md`) — contract-assertion bats pattern applied to this skill.
- **P031** — git-history freshness check rationale (mtime unreliable in worktrees).
- **P048** Candidate 4 — original `Likely verified?` column (14-day age-heuristic). Superseded by P186.
- **P186** — evidence-first cell shape (`yes — observed: <evidence>` / `no — not observed` / `no — observed regression`) replaces the age-based heuristic; `<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->` drives cross-skill drift detection.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — discoverable surface via `/wr-itil:` autocomplete.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — one skill per distinct user intent.
- `packages/itil/skills/manage-problem/SKILL.md` — hosts the thin-router forwarder for the deprecated `manage-problem list` form.

$ARGUMENTS
