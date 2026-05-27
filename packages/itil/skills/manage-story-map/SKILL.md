---
name: wr-itil:manage-story-map
description: Heavyweight story-map intake + lifecycle management following ADR-060 Phase 2. Authors backbone × ribs × slices structure on draft maps, transitions through draft → accepted → in-progress → completed → archived, re-validates I3 + I4 invariants at every transition, and refreshes docs/story-maps/README.md per the P062 / P094 contract pattern. Companion to /wr-itil:capture-story-map (lightweight aside surface).
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Manage Story Map Skill

Heavyweight story-map lifecycle management. Mirrors `/wr-itil:manage-story` shape per ADR-032 lightweight + heavyweight split, applied at the story-map tier with HTML encoding.

## Story-Map Lifecycle

Per ADR-060 amendment 2026-05-10 lines 145-189 + encoding amendment 2026-05-12:

| Status | Filename pattern | Meaning |
|--------|-----------------|---------|
| **draft** | `docs/story-maps/draft/STORY-MAP-<NNN>-<slug>.html` | Captured (problem + JTBD traces present); skeleton backbone |
| **accepted** | `docs/story-maps/accepted/STORY-MAP-<NNN>-<slug>.html` | Backbone × ribs × slices authored; story references in place |
| **in-progress** | `docs/story-maps/in-progress/STORY-MAP-<NNN>-<slug>.html` | Slices being implemented; stories transitioning |
| **completed** | `docs/story-maps/completed/STORY-MAP-<NNN>-<slug>.html` | All slices done |
| **archived** | `docs/story-maps/archived/STORY-MAP-<NNN>-<slug>.html` | Closed without completion |

## I-invariant enforcement

| Invariant | What it asserts | Where it fires |
|-----------|-----------------|----------------|
| **I3** trace-to-problem | Every map traces to ≥ 1 problem (ADR-060 line 187) | Hard-block at `/wr-itil:capture-story-map` + re-validated at every transition |
| **I4** trace-to-JTBD | Every map traces to ≥ 1 JTBD (ADR-060 line 188) | Hard-block at `/wr-itil:capture-story-map` + re-validated at every transition |
| **I5** no-WSJF-leak | Maps MUST NOT carry WSJF (ADR-060 line 189) | Behavioural test: argument grammar + frontmatter carry no WSJF |

**Bootstrap-exemption marker** per ADR-060 line 339 + ADR-053 Bootstrapping precedent: STORY-MAP-001 ships with the `<!-- bootstrap-exempt -->` marker during retrofit; non-bootstrap captures with the marker fail.

## Argument grammar

```
/wr-itil:manage-story-map <STORY-MAP-NNN>             # Update flow
/wr-itil:manage-story-map <STORY-MAP-NNN> accepted     # Transition draft → accepted
/wr-itil:manage-story-map <STORY-MAP-NNN> in-progress  # Manual transition
/wr-itil:manage-story-map <STORY-MAP-NNN> completed    # Transition in-progress → completed
/wr-itil:manage-story-map <STORY-MAP-NNN> archived     # Close without completion
/wr-itil:manage-story-map review                       # Re-validate all maps + refresh README
```

No WSJF token in any grammar form (I5 invariant).

## Rule 6 audit

| Decision | Resolution | Authority class |
|----------|-----------|-----------------|
| Story-map ID resolution | Mechanical: regex match `^STORY-MAP-[0-9]{3}$` against `docs/story-maps/*/STORY-MAP-<NNN>-*.html` | silent-mechanical |
| Lifecycle transition validation | Mechanical state machine | silent-mechanical |
| Backbone/ribs/slices authoring | AskUserQuestion (taste) at accepted; agent applies user input as HTML edits | taste |
| `<meta>` block updates | Mechanical: update status `<meta>` on transitions; preserve all other meta | silent-mechanical |
| README refresh on every transition | Mechanical: regenerate `docs/story-maps/README.md` lifecycle-grouped section from FS truth | silent-mechanical |
| Reverse-trace refresh on driving artefacts | Mechanical: refresh `## Story Maps` on problems + JTBDs via Slice 2a/2b helpers | silent-mechanical |

## Steps

### 0. Preflight

```bash
wr-itil-reconcile-readme docs/problems > /tmp/wr-itil-drift-$$.txt
wr-itil-reconcile-story-maps docs/story-maps > /tmp/wr-itil-story-maps-drift-$$.txt
# Halt-and-route on drift to the appropriate reconcile skill.
```

### 1. Parse arguments + resolve story-map file

```bash
story_map_id="$1"
action="${2:-update}"
```

If `$story_map_id == "review"`, branch to Step 8 (review flow). Otherwise resolve `docs/story-maps/<state>/STORY-MAP-<NNN>-*.html`; if unresolved, halt.

### 2. Read story-map HTML

Parse `<meta>` block (problems, rfcs, jtbd, adrs, status, reported, decision-makers). Read backbone structure (`<section class="backbone">` → `.rib-header` → `.rib` → `<a class="slice">` data-* attributes).

### 3-6. (Update flow — bare `<STORY-MAP-NNN>`)

Display current map state. Surface gaps: missing backbone ribs, slices with unresolved `data-story-id` references, mismatched `<meta name="status">` vs filename `<state>` subdir.

Use AskUserQuestion for backbone authoring direction (taste class); silent-mechanical for housekeeping (status normalisation).

### 7. Status transitions

For any transition `<from> → <to>`:

1. **Verify pre-transition invariants**:
   - `accepted`: I3 + I4 re-validated; backbone authored with ≥ 1 rib + ≥ 1 slice; every slice `data-story-id` resolves to a `docs/stories/*/STORY-NNN-*.md` file.
   - `in-progress`: at least one slice has `data-status="in-progress"` or `"done"`.
   - `completed`: every slice has `data-status="done"`.
   - `archived`: no invariants (manual close).

2. **`git mv` to new state subdir + Edit `<meta name="status">`** + P057 re-stage.

3. **README refresh** — regenerate `docs/story-maps/README.md` lifecycle-grouped section from FS truth. Stage in same commit.

4. **Reverse-trace refresh** — for each problem + JTBD in `<meta>` block:

```bash
for pid_token in $(grep -oE '<meta name="problems" content="[^"]*"' "$map_file" | grep -oE 'P[0-9]{3}'); do
  pid_num="${pid_token#P}"
  problem_file=$(ls docs/problems/${pid_num}-*.md docs/problems/*/${pid_num}-*.md 2>/dev/null | head -1)
  [ -z "$problem_file" ] && continue
  wr-itil-update-problem-references-section "$problem_file" "Story Maps"
  git add "$problem_file"
done

# Same for JTBDs via wr-itil-update-jtbd-references-section "Story Maps"
```

Per architect amend finding 2 on Slice 7: story-map HTML files do NOT carry an auto-maintained markdown reverse-trace section themselves (the `<a class="slice">` data-attribute traces are authored manually during backbone design). No reverse-trace refresh on the map itself; reverse-trace only flows OUT to problem + JTBD parents.

### 8. List flow (`list`)

Forward-points to `/wr-itil:list-story-maps` (read-only sibling).

### 9. Review flow (`review`)

Re-validate every map's I3 + I4. Regenerate README. Single commit.

### 10. Single commit per ADR-014

Stage: renamed map file + README + driving problem/JTBD files whose `## Story Maps` section refreshed.

Commit message: `feat(itil): transition STORY-MAP-<NNN> <from> → <to> — <title>` + `Refs: STORY-MAP-<NNN>` trailer.

### 11. Report

Story-map ID + new status + invariants verified + parent artefacts touched + trailing pointer to `/wr-itil:list-story-maps`.

## Composition with capture-story-map

| Concern | manage-story-map | capture-story-map |
|---------|------------------|-------------------|
| I3 + I4 | Re-validated at every transition | Hard-block at capture |
| Backbone authoring | Step 7 accepted-transition AskUserQuestion fires | Out of scope (deferred-placeholder rib only) |
| Status transitions | draft → accepted → in-progress → completed → archived | Out of scope (creation only) |
| README refresh | Inline per transition (P094 mirror) | Deferred to `manage-story-map review` or `reconcile-story-maps` |
| Commit grain | One commit per intake / per transition | One commit per capture |

## Related

- **ADR-060** — Problem-RFC-Story framework; Phase 2 amendment 2026-05-10 lines 145-189 + encoding amendment 2026-05-12 lines 381-435.
- **ADR-060 line 145** — I5 no-WSJF-on-maps invariant.
- **ADR-060 line 339 + ADR-053** — bootstrap-exemption marker contract.
- **`docs/STYLE-GUIDE.md`** — HTML style rules manage-story-map enforces.
- **P170** — driver problem ticket.
- **JTBD-008** — primary anchor.
- **JTBD-302** — README-currency rule.
- **`/wr-itil:capture-story-map`** — companion lightweight aside.
- **`/wr-itil:reconcile-story-maps`** — drift detection + recovery.
- **manage-story SKILL.md** — sibling at the story tier; manage-story-map mirrors with HTML-encoding adjustments (`<meta>` block parse + backbone-authoring AskUserQuestion + no I7/I8/I9/I10 — those are story-tier invariants).
- **ADR-052** — behavioural-tests default; `packages/itil/skills/manage-story-map/test/manage-story-map-contract.bats`.

$ARGUMENTS
