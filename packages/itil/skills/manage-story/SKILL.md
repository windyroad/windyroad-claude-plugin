---
name: wr-itil:manage-story
description: Heavyweight story intake + lifecycle management following ADR-060 Phase 2. Creates and updates story tickets, transitions through draft → accepted → in-progress → done → archived lifecycle, enforces I7 + I8 trace-gate at the accepted transition, runs INVEST checks per I10 at acceptance, auto-transitions draft→in-progress on first non-capture commit and in-progress→done on all-criteria-ticked + linked RFC closes, and refreshes docs/stories/README.md per the P062 / P094 contract pattern. Companion to /wr-itil:capture-story (lightweight aside surface).
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Manage Story Skill

Heavyweight story lifecycle management. Mirrors `/wr-itil:manage-rfc` shape per ADR-032 lightweight + heavyweight skill split, extended for the story-tier's INVEST-shape acceptance gate (I10) and auto-transition triggers.

## Story Lifecycle

Per ADR-060 Phase 2 amendment 2026-05-10 lines 200-253:

| Status | Filename pattern | Meaning | Entry criteria |
|--------|-----------------|---------|----------------|
| **draft** | `docs/stories/draft/STORY-<NNN>-<slug>.md` | Captured (problem + JTBD traces present); skeleton body | I6 + I9 satisfied at capture |
| **accepted** | `docs/stories/accepted/STORY-<NNN>-<slug>.md` | INVEST shape verified; ready for implementation | I7 + I8 + I10 hard-block satisfied |
| **in-progress** | `docs/stories/in-progress/STORY-<NNN>-<slug>.md` | Implementation underway | Auto-transitioned on first non-capture commit carrying `Refs: STORY-<NNN>` |
| **done** | `docs/stories/done/STORY-<NNN>-<slug>.md` | All acceptance criteria ticked + linked RFC closed | Auto-transitioned (triggered by RFC close-fire or by manual `manage-story <NNN> done`) |
| **archived** | `docs/stories/archived/STORY-<NNN>-<slug>.md` | Closed without completion (scope shifted; superseded) | Manual transition only |

## I-invariant enforcement at lifecycle transitions

| Invariant | What it asserts | Where it fires |
|-----------|-----------------|----------------|
| **I6** trace-to-problem | Every story traces to ≥ 1 problem | Hard-block at `/wr-itil:capture-story` (also verified at every transition) |
| **I7** trace-to-RFC | Every story traces to ≥ 1 RFC | Hard-block at `manage-story <NNN> accepted` (deferred from capture per ADR-060 line 291) |
| **I8** trace-to-story-map | Every story traces to ≥ 1 story map | Hard-block at `manage-story <NNN> accepted` (deferred from capture) |
| **I9** trace-to-JTBD | Every story traces to ≥ 1 JTBD | Hard-block at `/wr-itil:capture-story` (also verified at every transition) |
| **I10** INVEST shape | At acceptance, INVEST behaviourally: ≥1 acceptance criterion (Testable); user-value statement (Valuable); no Blocked-by-unaccepted refs (Independent); `estimated-effort` field set (Estimable); S/M effort SHOULD; L/XL flagged decomposition-candidate (Small) | Hard-block at `manage-story <NNN> accepted` |
| **I11** no-WSJF-leak | Phase 2: stories MUST NOT carry a WSJF field | Behavioural test at this skill (no WSJF field added/read) |

**Bootstrap-exemption marker** (per ADR-060 line 339 + ADR-053 Bootstrapping precedent): the I7/I8/I9/I10 retrofit on bootstrap-migration stories rides a one-time exemption marker `<!-- bootstrap-exempt: STORY-MAP-001 migration per ADR-060 amendment 2026-05-10 -->` inline with the frontmatter. Non-bootstrap captures with the marker fail per the behavioural test.

## Argument grammar

```
/wr-itil:manage-story <STORY-NNN>                    # Update flow — open the story for review
/wr-itil:manage-story <STORY-NNN> accepted            # Transition draft → accepted (gates I7 + I8 + I10)
/wr-itil:manage-story <STORY-NNN> in-progress         # Manual transition (auto-fires on first non-capture commit)
/wr-itil:manage-story <STORY-NNN> done                # Transition in-progress → done (gates all-criteria-ticked + RFC closed)
/wr-itil:manage-story <STORY-NNN> archived            # Close without completion
/wr-itil:manage-story review                          # Re-rank all stories + refresh README
```

## Rule 6 audit (per ADR-032 + ADR-013 + ADR-060)

| Decision | Resolution | Authority class |
|----------|-----------|-----------------|
| Story ID resolution | Mechanical: `STORY-<NNN>` regex match against `docs/stories/*/STORY-<NNN>-*.md` | silent-mechanical |
| Lifecycle transition validation | Mechanical: state machine — draft → accepted → in-progress → done; allow draft → archived; disallow backwards | silent-mechanical |
| I7 + I8 hard-block at accepted | Mechanical: frontmatter `rfcs:` and `story-maps:` arrays MUST be non-empty AND each ID must resolve to a file in `docs/rfcs/` and `docs/story-maps/` | silent-mechanical |
| I10 INVEST shape check | Mechanical: `## User value` section non-empty; `## Acceptance criteria` has ≥ 1 `- [ ]` line; `estimated-effort` field set to S/M/L/XL; L/XL flagged as decomposition-candidate (advisory, not blocking per ADR-060 line 252 architect-amendment-2026-05-10 nitpick N3) | silent-mechanical |
| INVEST shape violation | Halt-with-stderr-directive listing the missing INVEST attributes; user re-invokes after editing the story body | n/a (halt) |
| README refresh on every transition | Mechanical: regenerate `docs/stories/README.md` Story Rankings + Done tables from FS truth; stage in same commit | silent-mechanical |
| Reverse-trace refresh on driving artefacts | Mechanical: every transition refreshes `## Stories` section on each driving problem + JTBD + RFC + story-map via the Slice 2a/2b helpers | silent-mechanical |
| Bootstrap-exemption marker | Mechanical: marker permitted only on stories whose frontmatter problem-trace includes the bootstrap-migration problem ID (P170); non-bootstrap stories with the marker fail at acceptance | silent-mechanical |

All decisions framework-mediated per ADR-044 + P132 + inverse-P078.

## Steps

### 0. Preflight

```bash
wr-itil-reconcile-readme docs/problems > /tmp/wr-itil-drift-$$.txt
wr-itil-reconcile-stories docs/stories docs/problems docs/rfcs docs/jtbd > /tmp/wr-itil-stories-drift-$$.txt
# If either reports drift, halt-and-route to the appropriate reconcile skill.
```

### 1. Parse arguments

```bash
story_id="$1"
action="${2:-update}"  # default: update flow
```

If `$story_id` is `review`, branch to Step 9 (review flow). Otherwise validate `$story_id` matches `^STORY-[0-9]{3}$` and resolve to a file under `docs/stories/<state>/STORY-<NNN>-*.md`. If unresolved, halt with stderr directive.

### 2. Read story frontmatter + body

Parse YAML frontmatter (fields: `status`, `story-id`, `reported`, `decision-makers`, `problems`, `jtbd`, `rfcs`, `story-maps`, `estimated-effort`). Read body sections (`## User value`, `## Acceptance criteria`, `## Driving problem trace`, `## JTBD trace`, `## Implementation notes`, `## Dependencies`, `## Related`).

### 3-6. (Update flow — bare `<STORY-NNN>`)

Display the current story state. Surface any open gaps:
- Missing/empty body sections.
- Frontmatter trace lists that don't resolve to files.
- Mismatched filename `<status>` subdir vs frontmatter `status:` field.

Use `AskUserQuestion` for direction-setting fields (e.g. `## User value` rewrite); silent-mechanical for housekeeping (e.g. trace ID format normalisation).

### 7. Status transitions

#### Transition mechanics

For any transition `<from> → <to>`:

1. **Verify pre-transition invariants** for `<to>`:
   - `accepted`: I7 + I8 + I10 hard-block (see § I-invariant table).
   - `in-progress`: linked RFC status is `accepted` or `in-progress` (you can't progress a story under a proposed/closed RFC).
   - `done`: ALL `- [ ]` checkboxes in `## Acceptance criteria` are ticked (i.e. zero unticked); linked RFC status is `closed` OR the RFC's other stories have closed (transitive closure check deferred to a per-RFC `manage-rfc done-gate` check in a future slice).
   - `archived`: no invariants (manual close-without-completion).

2. **`git mv` the file** to the new state subdir:
   ```bash
   git mv "docs/stories/${from_state}/STORY-${nnn}-${slug}.md" "docs/stories/${to_state}/STORY-${nnn}-${slug}.md"
   ```

3. **Edit the file** — Status field; for `accepted`, populate any deferred `## User value` / `## Acceptance criteria` / `## Implementation notes` sections via AskUserQuestion if not already filled.

4. **P057 staging-trap** — after the Edit, re-stage: `git add "docs/stories/${to_state}/STORY-${nnn}-${slug}.md"`.

#### Auto-transition triggers (ADR-060 line 292)

The auto-transition logic fires in two contexts:

- **`draft → in-progress`**: when the FIRST commit AFTER the story's capture commit lands with a `Refs: STORY-<NNN>` trailer AND a commit subject NOT prefixed with `feat(itil): capture STORY-`. Detected by a future commit-trailer-trigger hook (deferred to a hook-source slice); manual `manage-story <NNN> in-progress` invocation works in the interim.

- **`in-progress → done`**: when all `- [ ]` lines in `## Acceptance criteria` are ticked AND the linked RFC is `closed`. Detected at manage-rfc close-fire (the RFC's transition triggers a sweep of its `stories:` array; each in-progress story with all-criteria-ticked auto-transitions to `done`). Manual `manage-story <NNN> done` invocation works in the interim.

#### README refresh on every transition (P062 mirror)

After rename + Edit + re-stage, regenerate `docs/stories/README.md` Story Rankings + Done tables in-place reflecting the new filename set and the transitioned story's new Status. Stage the refreshed README with the same commit.

Update the "Last reviewed" line on `docs/stories/README.md` per the **inline P134 rotation mechanism** below. The mechanism is inlined here at the execution site (not deferred via cross-reference to `manage-problem` SKILL.md Step 5) so a single-pass agent reading this Step does not silently skip the archive step. **Skipping the BEFORE-rewrite archive step destroys the displaced fragment and re-opens P331** (origin failure mode: iter-7 + iter-8 of 2026-05-30's AFK work-problems session silently skipped the equivalent rotation on `docs/problems/README.md` in 2 of 9 transition-bearing iters). The mechanism MUST execute IN ORDER:

1. **Read** line 3 of `docs/stories/README.md`: `awk 'NR==3' docs/stories/README.md` (`head -3 | tail -1` or `sed -n '3p'` are acceptable equivalents).
2. **Append-if-non-empty (BEFORE step 3, not after)** — if line 3 is non-empty AND not a same-session same-verb near-duplicate of the new fragment, append the existing line 3 verbatim to `docs/stories/README-history.md` (created on first rotation) under a `## YYYY-MM-DD` heading. Run this BEFORE the Edit-tool rewrite in step 3 — Edit's replace pattern destroys the displaced content otherwise.
3. **Rewrite** line 3 of `docs/stories/README.md` with the new fragment of form `> Last reviewed: YYYY-MM-DD **<event>** — <one-line summary>` (e.g. `STORY-<NNN> <status> — <one-line summary>`). Soft cap ≤ 1024 bytes per fragment; hard ceiling 5120 bytes per ADR-040 Tier 3 envelope.
4. **Stage both** — `git add docs/stories/README.md docs/stories/README-history.md` so the same single commit per ADR-014 captures both files.

Canonical rationale anchor: `manage-problem` SKILL.md Step 5 § Last-reviewed line discipline (P134). The discipline applies identically across `docs/problems/README.md`, `docs/rfcs/README.md`, and `docs/stories/README.md` (only the target index path differs). The cross-reference is preserved for the "why"; the "what" is inlined above for execution-time legibility per P331.

#### Reverse trace on driving problem(s), JTBD(s), RFC(s), story-map(s) — skill-side primary surface

Per ADR-060 line 270: every transition refreshes the `## Stories` section on each driving artefact inline in the same commit per ADR-014 single-commit grain.

For each parent ID in the story's frontmatter:

```bash
# Problem parents
for pid_token in $(awk '/^problems:/{gsub(/[][]/,""); gsub(/,/," "); for(i=2;i<=NF;i++)print $i; exit}' "$story_file"); do
  pid_num="${pid_token#P}"
  problem_file=$(ls docs/problems/${pid_num}-*.md docs/problems/*/${pid_num}-*.md 2>/dev/null | head -1)
  [ -z "$problem_file" ] && continue
  wr-itil-update-problem-references-section "$problem_file" "Stories"
  git add "$problem_file"
done

# JTBD parents — sibling shape
for jid in $(awk '/^jtbd:/{gsub(/[][]/,""); gsub(/,/," "); for(i=2;i<=NF;i++)print $i; exit}' "$story_file"); do
  jtbd_file=$(ls docs/jtbd/*/${jid}-*.md 2>/dev/null | head -1)
  [ -z "$jtbd_file" ] && continue
  wr-itil-update-jtbd-references-section "$jtbd_file" "Stories"
  git add "$jtbd_file"
done

# RFC parents — sibling shape (after Slice 11 ships the Stories section helper)
for rid in $(awk '/^rfcs:/{gsub(/[][]/,""); gsub(/,/," "); for(i=2;i<=NF;i++)print $i; exit}' "$story_file"); do
  rfc_file=$(ls docs/rfcs/${rid}-*.md 2>/dev/null | head -1)
  [ -z "$rfc_file" ] && continue
  wr-itil-update-rfc-references-section "$rfc_file" "Stories"
  git add "$rfc_file"
done

# Story-map parents — manually-authored data-attribute traces per
# architect amend finding 2 on Slice 7; NO automatic refresh here. Emit
# advisory stderr noting unplaced-on-map state if frontmatter
# story-maps: is non-empty.
```

The helpers are idempotent + lazy-empty per the Slice 2a/2b/Slice 11 contract.

### 8. List flow (`list`)

Read all `docs/stories/*/STORY-*.md` files. Extract ID, title, status, traced problems / RFCs / story-maps / JTBDs. Sort by lifecycle state (accepted > in-progress > draft > done > archived) then by `Reported` ASC. Display as markdown tables grouped by state.

### 9. Review flow (`review`)

Per `/wr-itil:review-problems` precedent at the story tier:

1. For each story, re-validate I6 + I9 (re-resolve problem + JTBD trace files; flag missing).
2. For each accepted/in-progress story, re-validate I7 + I8 + I10 (re-resolve RFC + story-map trace files; re-check INVEST shape; flag drift).
3. Regenerate `docs/stories/README.md` Story Rankings + Done tables.
4. Single commit per ADR-014; commit message names the review pass + count of drift-resolutions.

### 10. Single commit per ADR-014

Stage list per transition shape:
- Renamed story file (new path)
- README.md refresh
- All driving problem + JTBD + RFC files whose `## Stories` section refreshed

Commit message format:
```
feat(itil): transition STORY-<NNN> <from> → <to> — <title>

Refs: STORY-<NNN>
```

Risk-gate per ADR-014: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool; fallback `/wr-risk-scorer:assess-release` via Skill tool.

### 11. Report

After commit, report:
- Story ID + title + new status.
- Action taken (transition kind + invariant gates that fired).
- Driving artefacts touched (problem + JTBD + RFC reverse-trace refresh paths).
- Trailing pointer: `Run /wr-itil:work-problem <P-<NNN>> to continue work on the driving problem, or /wr-itil:list-stories --rfc <RFC-<NNN>> to see the next story in the RFC's execution order.`

## Composition with capture-story

| Concern | manage-story | capture-story |
|---------|--------------|---------------|
| I6 + I9 hard-block | Re-validated at every lifecycle transition | Hard-block at capture-time |
| I7 + I8 hard-block | **Primary surface** — fires at `manage-story <NNN> accepted` | Advisory at capture if flags provided |
| I10 INVEST shape | **Primary surface** — fires at `manage-story <NNN> accepted` | Out of scope (capture produces skeleton) |
| Status transitions | Owns draft → accepted → in-progress → done → archived | Out of scope (creation only) |
| README refresh | Inline per transition (P094 mirror) | Deferred to `manage-story review` or `wr-itil-reconcile-stories` |
| Auto-transition triggers | Fires on first non-capture commit (draft→in-progress) + criteria-ticked + RFC-closed (in-progress→done) | n/a |
| Reverse-trace refresh on parents | Inline per transition | Inline per capture |
| Commit grain | One commit per transition / per intake | One commit per capture |

## Related

- **ADR-060** — Problem-RFC-Story framework + Phase 2 amendment 2026-05-10 (story tier).
- **ADR-060 lines 248-253** — I6-I11 story-tier invariants.
- **ADR-060 line 252** — I10 INVEST shape (Testable/Valuable/Independent/Estimable; Small SHOULD per architect-amendment-2026-05-10 nitpick N3).
- **ADR-060 line 292** — auto-transition triggers (draft→in-progress on first non-capture commit; in-progress→done on criteria-ticked + RFC-closed).
- **ADR-060 line 339 + ADR-053 Bootstrapping precedent** — bootstrap-exemption marker contract for STORY-MAP-001 migration retrofit.
- **P170** — driver problem ticket.
- **JTBD-008** — Decompose a Fix Into Coordinated Changes. Primary persona-anchor.
- **JTBD-001** (extended scope) — change-set-level governance composition.
- **JTBD-006** — AFK orchestrator protection (I11 no-WSJF-leak prevents story-level competition in Step 3 selection).
- **`docs/stories/README.md`** — story tier lifecycle index + frontmatter/body shape spec.
- **`/wr-itil:capture-story` SKILL.md** — companion lightweight aside surface.
- **`/wr-itil:reconcile-stories` SKILL.md** — drift detection + agent-applied edit recovery.
- **ADR-014** — single-commit grain.
- **ADR-022** — problem lifecycle conventions; story lifecycle mirrors.
- **ADR-032** — governance-skill aside-invocation pattern; lightweight + heavyweight split.
- **ADR-044** — decision delegation contract.
- **ADR-051** — load-bearing-from-the-start; I7 + I8 + I10 ship on day one.
- **ADR-052** — behavioural-tests default; `packages/itil/scripts/test/manage-story.bats` (P170 Phase 2 Slice 8).
- **ADR-060 Phase 2 Slice 2a/2b/Slice 11 reverse-trace helpers** — `update-problem-references-section.sh`, `update-jtbd-references-section.sh`, `update-rfc-references-section.sh` all support `"Stories"` section-name token.
- **manage-rfc SKILL.md** — direct precedent shape; manage-story mirrors with story-tier extensions for INVEST gate + auto-transitions.

$ARGUMENTS
