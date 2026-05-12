---
name: wr-itil:list-stories
description: List INVEST-shaped story tickets from docs/stories/ as a markdown table. Read-only display — no edits, no interaction. Optional `--rfc RFC-<NNN>` filter to surface a specific RFC's ordered story list per ADR-060 Phase 2.
allowed-tools: Read, Bash, Grep, Glob
---

# List Stories

Display the story corpus from `docs/stories/` as a markdown table. Read-only view of the story tier per ADR-060 Phase 2; this skill does not edit, transition, close, or create stories. For those operations, use the dedicated skills (`/wr-itil:capture-story`, `/wr-itil:manage-story`).

Mirrors the `/wr-itil:list-problems` precedent (P071 phased-landing split per ADR-010 amended Skill Granularity rule: one skill per distinct user intent). The list-stories surface separates the read-only view from the heavyweight `/wr-itil:manage-story list` subcommand route (which is itself a candidate for phased-landing split in a future slice).

## Scope

Stories live under `docs/stories/<state>/STORY-<NNN>-<slug>.md` in lifecycle subdirectories:

- `docs/stories/draft/*.md` — draft (captured via `/wr-itil:capture-story`; pre-INVEST-acceptance)
- `docs/stories/accepted/*.md` — accepted (INVEST-shape verified per I10; pre-implementation)
- `docs/stories/in-progress/*.md` — in-progress (implementation underway; auto-transitioned from accepted on first `Refs: STORY-<NNN>` commit AFTER the capture commit per ADR-060 line 292)
- `docs/stories/done/*.md` — done (acceptance-criteria all-ticked + linked RFC closes; auto-transitioned from in-progress)
- `docs/stories/archived/*.md` — archived (closed without completion; manual transition)

Per ADR-060 I11 invariant (Phase 2 deferred): stories MUST NOT carry a WSJF field. Ordering inside an RFC is per the RFC's frontmatter `stories: [STORY-<NNN>, ...]` array (ordered = execution sequence per ADR-060 line 259), NOT per any per-story WSJF.

## Argument grammar

**Positional (optional)**: `--rfc RFC-<NNN>` flag-style filter. When provided, the display lists ONLY stories that trace to the named RFC, IN THE ORDER specified by the RFC's frontmatter `stories:` array per ADR-060 line 259. Without the flag, all stories across all lifecycle states are listed grouped by state.

```
/wr-itil:list-stories                    # All stories, grouped by lifecycle state
/wr-itil:list-stories --rfc RFC-002      # Only stories under RFC-002, in execution order
```

## Steps

### 1. Check `docs/stories/README.md` cache freshness

Reuse the same `git log`-based freshness test as `/wr-itil:list-problems` Step 1 (per P031 — filesystem mtime is unreliable in worktrees and fresh checkouts):

```bash
readme_commit=$(git log -1 --format=%H -- docs/stories/README.md 2>/dev/null)
if [ -z "$readme_commit" ] || \
   git log --oneline "${readme_commit}..HEAD" -- 'docs/stories/*/*.md' ':!docs/stories/README.md' 2>/dev/null | grep -q .; then
  echo "stale"
fi
```

**Cache fresh** (no output AND no `--rfc` filter): read `docs/stories/README.md` directly — display the Story Rankings section + Done section as-is. Note in the output: "Using cached ranking from [timestamp in README.md]".

**Cache stale OR `--rfc` filter provided OR `README.md` missing**: run the live scan in Step 2. (The filter case always live-scans because the README cache is whole-corpus ranking, not a per-RFC filtered view.)

### 2. Live scan (cache-stale fallback OR filter mode)

**Unfiltered live scan** — enumerate every state directory:

```bash
ls docs/stories/draft/*.md docs/stories/accepted/*.md docs/stories/in-progress/*.md docs/stories/done/*.md docs/stories/archived/*.md 2>/dev/null
```

For each story file, parse the YAML frontmatter to extract: `story-id`, `status`, `problems`, `jtbd`, `rfcs`, `story-maps`, `estimated-effort`. Read the H1 line for the title.

**Filtered live scan** (`--rfc RFC-<NNN>` provided) — resolve the RFC file first, then enumerate its ordered `stories:` array:

```bash
rfc_file=$(ls docs/rfcs/RFC-<NNN>-*.md 2>/dev/null | head -1)
[ -z "$rfc_file" ] && echo "RFC-<NNN> not found" >&2 && exit 1

# Extract the ordered stories: array from RFC frontmatter
# (Phase 2 Slice 11 extension — see ADR-060 RFC frontmatter extension)
stories_list=$(awk '/^stories:/,/^[a-z]/' "$rfc_file" | grep -oE 'STORY-[0-9]+')
```

For each `STORY-<NNN>` in the ordered list, resolve to a file under `docs/stories/*/STORY-<NNN>-*.md` and parse the frontmatter as above. Preserve the RFC's array ordering in the output.

### 3. Display

**Unfiltered mode** — render lifecycle-grouped sections:

```markdown
## Draft

| ID | Title | Problems | JTBD | RFCs | Story Maps |
|----|-------|----------|------|------|------------|
| STORY-<NNN> | <title> | <P<NNN>...> | <JTBD-<NNN>...> | <RFC-<NNN>...> | <STORY-MAP-<NNN>...> |

## Accepted

| ID | Title | Problems | JTBD | RFCs | Story Maps | Effort |
|----|-------|----------|------|------|------------|--------|
...

## In Progress

(same shape as Accepted)

## Done

| ID | Title | Done date | Driving problems |
|----|-------|-----------|------------------|
...
```

Omit empty sections rather than rendering empty headers. The Estimated Effort column is omitted from the Draft section because effort is deferred at capture and only required at accepted per I10 INVEST Estimable.

**Filtered mode** (`--rfc RFC-<NNN>`) — render a single ordered table:

```markdown
## Stories under RFC-<NNN>

(In execution order per RFC frontmatter `stories:` array.)

| Order | ID | Title | Status | Effort |
|-------|----|-------|--------|--------|
| 1 | STORY-<NNN> | <title> | <status> | <effort> |
| 2 | STORY-<NNN> | <title> | <status> | <effort> |
...
```

The Order column makes the execution sequence visible — critical for the working-the-problem flow per ADR-060 line 314 ("read frontmatter `stories:` array (ordered) → pick first not-done story").

### 4. Trailing suggestions

After the table(s), print one short pointer depending on output:

- **Filtered mode + first not-done story exists**: `Run /wr-itil:work-problem to advance the next story under RFC-<NNN> (STORY-<NNN> — <title>).` (Note: working-the-problem traversal per ADR-060 line 300-320 lands in Slice 13.)
- **Filtered mode + all stories done**: `All stories under RFC-<NNN> are done. Run /wr-itil:manage-rfc <RFC-<NNN>> verifying to transition the RFC.`
- **Unfiltered mode + Draft section non-empty**: `Run /wr-itil:manage-story <STORY-<NNN>> accepted to advance a draft through INVEST gates.`
- **Unfiltered mode + only Done section non-empty**: `No active stories. Run /wr-itil:capture-story to draft a new story.`

## Ownership boundary

`list-stories` does not modify, rename, or commit any files. If the README.md cache is stale, list-stories performs a live scan but does NOT rewrite `docs/stories/README.md` — refreshing the cache is `/wr-itil:manage-story review`'s ownership (Slice 8 lands the review surface). The trailing-suggestion pointer surfaces this boundary.

## Related

- **ADR-060** — Problem-RFC-Story framework + Phase 2 amendment 2026-05-12 (story tier).
- **ADR-060 line 259** — RFC frontmatter `stories:` ORDERED array (execution sequence).
- **ADR-060 line 294** — `/wr-itil:list-stories` skill description with `--rfc RFC-<NNN>` filter.
- **ADR-060 lines 300-320** — working-the-problem flow (Slice 13 lands the traversal).
- **ADR-060 line 253** — I11 no-WSJF-leak invariant (Phase 2).
- **P071** — phased-landing split precedent (list-problems split from manage-problem list).
- **ADR-010 amended** — Skill Granularity rule.
- **ADR-022** — lifecycle conventions (story lifecycle mirrors problem lifecycle).
- **ADR-037** — contract-assertion bats pattern.
- **P031** — git-history freshness check rationale.
- **JTBD-008** — Decompose a Fix Into Coordinated Changes. The list view supports the working-the-problem flow that operationalises JTBD-008's "first-class entity" Desired Outcome.
- **JTBD-006** — Progress the Backlog While I'm Away. Filtered mode (`--rfc`) feeds the AFK orchestrator's per-RFC iter dispatch (Slice 13).
- `packages/itil/skills/list-problems/SKILL.md` — direct precedent shape.
- `packages/itil/skills/list-incidents/SKILL.md` — sibling list-* skill at the incident tier.

$ARGUMENTS
