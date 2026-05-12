---
name: wr-itil:capture-story
description: Lightweight story-capture skill for aside-invocation during foreground work — mandatory leading problem-trace AND JTBD-trace per ADR-060 I6 + I9 invariants, optional `--rfc` and `--story-map` flag args (I7 + I8 enforce at `accepted` transition not at capture), skeleton story file at `docs/stories/draft/STORY-NNN-<slug>.md`, single commit per capture, no inline README refresh. Defers full INVEST shape + acceptance transition to /wr-itil:manage-story. Use when the user (or agent) wants to capture a story quickly with clear problem + JTBD anchoring. For full lifecycle management, use /wr-itil:manage-story.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Capture Story Skill

Capture an INVEST-shaped story ticket quickly during foreground work. Lightweight aside-invocation surface that complements the heavyweight `/wr-itil:manage-story` flow. Mirrors `/wr-itil:capture-rfc` shape per ADR-032 lightweight + heavyweight skill split, extended for the story tier's stricter trace-mandate (both problem AND JTBD at capture; RFC AND story-map deferred to accepted).

This skill is one half of the capture-then-manage story framework introduced by ADR-060 (Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology, accepted 2026-05-05; Phase 2 amendment 2026-05-12 introducing the story tier). The other half is `/wr-itil:manage-story` (heavyweight intake + INVEST-gated lifecycle management).

**Related JTBDs**: JTBD-008 (primary — Decompose a Fix Into Coordinated Changes; story is the INVEST-shaped sub-workstream entity JTBD-008 line 20 names), JTBD-001 (extended scope — story-level governance via INVEST gates at acceptance + auto-transition on RFC-closes + acceptance-criteria all-ticked), JTBD-101 (atomic-fix-adopter friction guard — capture-story remains opt-in; atomic-RFC fallback per ADR-060 line 262 means atomic adopters never invoke capture-story).

## When to invoke

- **Slicing an RFC into INVEST-shaped sub-workstreams**: agent / user has captured an RFC and is now decomposing its scope into the ordered `stories:` array per ADR-060's working-the-problem flow (line 300-320). Each slice on a story-map's backbone → ribs → slices grid becomes one story.
- **Capturing a story before its placement on a story-map**: per ADR-060 line 291, RFC + story-map traces are optional at capture; I7 / I8 enforce only at the `draft → accepted` transition. Draft stories may exist with NO `rfcs:` and NO `story-maps:` until the design firms up.
- **Retrospective bootstrap migration** (Slice 15 of P170 Phase 2): extracting existing slices from `docs/plans/170-rfc-framework-story-map.md` into individual story files. The bounded-escape carve-out for I7 / I8 enforce-at-accepted permits the retrospective sequence (capture draft, design fills in `rfcs:` + `story-maps:`, manage-story <NNN> accepted gate fires).
- **Forward dogfood capture**: a new story for in-flight work, captured at the start of implementation, runs to `done` via `Refs: STORY-NNN` trailer detection + acceptance-criteria all-ticked.

**Use `/wr-itil:manage-story` instead** when:
- The work is advancing an existing story through its lifecycle (draft → accepted → in-progress → done).
- The user wants the full INVEST intake flow with structured value-statement + acceptance-criteria + effort-estimation prompts.
- The story needs the I10 INVEST shape behavioural test to fire at accepted.

## Argument grammar

**Positional (both mandatory)**: `<problem-trace> <jtbd-trace> <description>` where:
- `<problem-trace>` is `P<NNN>` or comma-separated `P<NNN>,P<NNN>,...` (no spaces inside the trace; multiple problems comma-separated).
- `<jtbd-trace>` is `JTBD-<NNN>` or comma-separated `JTBD-<NNN>,JTBD-<NNN>,...`.

**Optional flags** (any order, before or after positional args):
- `--rfc RFC-<NNN>[,RFC-<NNN>,...]` — RFC(s) this story will be referenced by once design firms up.
- `--story-map STORY-MAP-<NNN>[,STORY-MAP-<NNN>,...]` — story-map(s) this story will be placed on once design firms up.

```
/wr-itil:capture-story P170 JTBD-008 Build /wr-itil:capture-story-map skill scaffold
/wr-itil:capture-story P170 JTBD-008,JTBD-001 --rfc RFC-002 Ship hook exemption globs across 4 enforce-edit hooks
/wr-itil:capture-story P170 JTBD-008 --story-map STORY-MAP-001 --rfc RFC-002 Extract Slice 5 T7 shared-migration-routine into STORY-NNN
```

**ADR-060 § Skills line 291 phrasing footnote**: ADR-060 names "Mandatory: ≥1 problem trace, ≥1 JTBD trace" verbatim. This skill uses the **positional** form (no `--problem` / `--jtbd` prefix on the mandatory pair) to match the lightweight aside-invocation grammar of `capture-rfc` (per ADR-032) and because Claude Code skill arguments don't carry a proper CLI flag parser. The optional `--rfc` / `--story-map` flags exist BECAUSE they are optional — fully positional would require sentinel values for absent traces. The hard-block intent (ADR-060 § Confirmation criterion implied by I6 + I9 — capture fails without both mandatory traces) is preserved verbatim — only the surface syntax differs.

## Rule 6 audit (per ADR-032 + ADR-013 + ADR-060)

This skill has **two direction-setting AskUserQuestion fires** (problem-trace AND JTBD-trace, when arguments are non-empty but malformed) and **one optional taste AskUserQuestion** (title/scope summary, silent-default if unavailable). Every other potentially-interactive decision is framework-mediated per ADR-044:

| Decision | Resolution | Authority class |
|----------|-----------|-----------------|
| Problem trace presence | I6 hard-block — refuse on missing trace; emit deny log + halt-with-stderr-directive | direction-setting |
| Problem trace validation | Mechanical: each `P<NNN>` must exist in `docs/problems/`. Open / Known Error / Verifying = pass; Closed / Parked = advisory-warn but proceed (bounded-escape carve-out — see Step 2) | silent-mechanical |
| JTBD trace presence | I9 hard-block — refuse on missing JTBD trace; emit deny log + halt-with-stderr-directive | direction-setting |
| JTBD trace validation | Mechanical: each `JTBD-<NNN>` must resolve to a file under `docs/jtbd/<persona>/JTBD-<NNN>-*.md` (any lifecycle status) | silent-mechanical |
| Optional `--rfc` trace validation | Mechanical: each provided `RFC-<NNN>` must resolve to a file under `docs/rfcs/`; advisory-warn on `proposed` / `verifying` lifecycle states; missing entirely = hard-block on the provided arg (the absence-from-args case is the "optional" path — the malformed-arg case is not) | silent-mechanical |
| Optional `--story-map` trace validation | Same mechanical pattern against `docs/story-maps/*/STORY-MAP-*.html` (HTML data-attribute existence check); advisory-warn on `draft` / `in-progress` story-maps | silent-mechanical |
| STORY ID allocation | Mechanical: `max(local, origin) + 1`, three-digit padded; enumerates `docs/stories/*/STORY-*.md` + `git ls-tree origin/main docs/stories/`. ADR-019 collision-guard inline per Slice 3 design review architect approval (finding 3 option a — inline-only path) | silent-mechanical |
| Title kebab-slug | Mechanical: first 8-10 non-stopword tokens of description | silent-mechanical |
| Title prose / scope summary refinement | Optional `AskUserQuestion`; silent-default to derived form when unavailable | taste |
| File write / frontmatter | Mechanical: shape per `docs/stories/README.md` § Frontmatter shape + ADR-060 lines 220-228 | silent-mechanical |
| Single commit | Mechanical: `feat(itil): capture STORY-<NNN> <title>` + `Refs: STORY-<NNN>` trailer | silent-mechanical |
| Empty arguments | Halt-with-stderr-directive: print "capture-story requires `<problem-trace> <jtbd-trace> <description>` — invoke /wr-itil:manage-story instead for the full intake flow" and exit. AFK orchestrators MUST NOT invoke capture-story with empty arguments. | n/a |

Per ADR-013 Rule 6 fail-safe + ADR-044 + P132 + inverse-P078: every silent-mechanical branch above resolves without user input, so AFK and interactive contexts behave identically modulo the optional taste prompt.

## Steps

### 0. Preflight (Phase 2 cross-directory)

This skill's preflight uses `wr-itil-reconcile-readme docs/problems` (the existing problems-README reconciliation contract per P118). Sibling reconcile-stories + reconcile-story-maps scripts land in Slice 5 + Slice 9 of P170 Phase 2 — once those ship, swap this preflight to call all three reconciliations (cross-tier integrity holds at all three surfaces).

```bash
wr-itil-reconcile-readme docs/problems > /tmp/wr-itil-drift-$$.txt
reconcile_exit=$?
if [ "$reconcile_exit" -eq 1 ]; then
  wr-itil-classify-readme-drift /tmp/wr-itil-drift-$$.txt docs/problems
  classify_exit=$?
  rm -f /tmp/wr-itil-drift-$$.txt
  # classify_exit 0 (INLINE_REFRESH): proceed (no inline refresh in this skill).
  # classify_exit 1 (HALT_ROUTE_RECONCILE): halt; invoke /wr-itil:reconcile-readme.
  # classify_exit 2 (parse error): conservative halt-and-route.
fi
```

### 1. Parse arguments

Tokenise the argument string. Optional flags (`--rfc <ids>`, `--story-map <ids>`) may appear in any position. The remaining positional tokens are `<problem-trace> <jtbd-trace> <description>` in that order.

```bash
# Pseudo:
rfc_trace=""
story_map_trace=""
positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    --rfc) rfc_trace="$2"; shift 2 ;;
    --story-map) story_map_trace="$2"; shift 2 ;;
    *) positional+=("$1"); shift ;;
  esac
done
problem_trace="${positional[0]}"
jtbd_trace="${positional[1]}"
description="${positional[*]:2}"
```

If `$problem_trace` does not match `^P[0-9]{3}(,P[0-9]{3})*$` (regex), this is an I6 violation — go to Step 2's deny path. If `$jtbd_trace` does not match `^JTBD-[0-9]{3}(,JTBD-[0-9]{3})*$`, this is an I9 violation. If `$description` is empty, halt with the empty-arguments directive from the Rule 6 audit table.

Derive a kebab-case title slug from the first 8-10 non-stopword tokens of `$description` (matching `capture-rfc` slug derivation).

### 2. Validate problem trace + I6 hard-block enforcement

For each `P<NNN>` in the trace list:

```bash
# Dual-tolerant ticket discovery (RFC-002 migration window):
# BOTH flat `docs/problems/<NNN>-<title>.<state>.md` AND per-state
# subdir `docs/problems/<state>/<NNN>-<title>.md` layouts.
trace_files=$(ls docs/problems/<NNN>-*.md docs/problems/*/<NNN>-*.md 2>/dev/null)
```

**I6 hard-block (per ADR-060 line 248)**:

- **Trace token absent OR malformed**: emit deny log entry + halt with stderr directive:
  ```bash
  mkdir -p logs
  printf '{"timestamp":"%s","session_id":"%s","reason":"%s","args":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(get_current_session_id 2>/dev/null || echo unknown)" \
    "<missing|malformed|unresolved>-trace" \
    "$(printf '%s' "$ARGUMENTS" | jq -Rs .)" \
    >> logs/story-capture-denials.jsonl
  echo "/wr-itil:capture-story requires a leading problem-trace argument (P<NNN> or P<NNN>,P<NNN>...). Open the driving problem via /wr-itil:capture-problem first, then re-invoke capture-story with the trace." >&2
  exit 1
  ```
  The deny log feeds the trace-violation-rate reassessment criterion (sibling to RFC's `logs/rfc-capture-denials.jsonl`).

- **Each `P<NNN>` must resolve to a file in `docs/problems/`**. If any does not, emit deny log entry with `reason: unresolved-trace` + the unresolved IDs, halt, exit 1.

**Bounded-escape carve-out for Closed/Verifying/Parked traces**: classify by suffix or path; `.open.md` / `.known-error.md` (or `open/` / `known-error/` subdirs) pass silently; `.verifying.md` (or `verifying/` subdir) passes with advisory note; `.closed.md` (or `closed/` subdir) and `.parked.md` (or `parked/` subdir) pass with advisory-warn (story may be a retrospective extraction).

### 2.5. Validate JTBD trace + I9 hard-block enforcement

For each `JTBD-<NNN>` in the JTBD trace list:

```bash
jtbd_file=$(ls docs/jtbd/*/JTBD-<NNN>-*.md 2>/dev/null | head -1)
[ -z "$jtbd_file" ] && unresolved_jtbds+=("JTBD-<NNN>")
```

**I9 hard-block (per ADR-060 line 251)**:

- **JTBD trace token absent OR malformed**: emit deny log entry + halt with directive: `/wr-itil:capture-story requires a JTBD trace argument (JTBD-<NNN> or JTBD-<NNN>,JTBD-<NNN>...). Author the driving JTBD via /wr-jtbd:update-guide first, then re-invoke capture-story.`
- **Each `JTBD-<NNN>` must resolve to a file in `docs/jtbd/`**. If any does not, emit deny log with `reason: unresolved-jtbd-trace`, halt, exit 1.

JTBD lifecycle states (`.proposed.md` / `.accepted.md` / `.archived.md`) all pass silently — a story may anchor on a proposed JTBD per the dogfood pattern (Phase 2 itself is being captured against proposed JTBDs).

### 2.6. Validate optional `--rfc` and `--story-map` traces

If `$rfc_trace` is non-empty, for each `RFC-<NNN>`:

```bash
rfc_file=$(ls docs/rfcs/RFC-<NNN>-*.md 2>/dev/null | head -1)
[ -z "$rfc_file" ] && unresolved_rfcs+=("RFC-<NNN>")
```

- Token absent: skip (the "optional" path).
- Token present but malformed (`--rfc RFC-99`, etc.) OR resolves to no file: hard-block. Emit deny log with `reason: unresolved-rfc-trace`. The optional-vs-malformed distinction is load-bearing — absence is permitted, malformed input is not.

Same shape for `--story-map`. Story-maps are HTML; existence check uses `ls docs/story-maps/*/STORY-MAP-<NNN>-*.html 2>/dev/null`.

Lifecycle classification on resolved files: advisory-warn on `proposed` / `draft` / `in-progress` states (the design isn't firm yet — captured story will reference work that may itself drift); pass silently on `accepted` / `closed` / `verifying` states.

### 3. Compute next STORY ID

Inline `max(local, origin) + 1` formula (per Slice 3 design review architect finding 3 option a — inline-only path; no separate `check-id-collision.sh` script per capture-rfc / capture-problem precedent):

```bash
local_max=$(ls docs/stories/*/STORY-*.md 2>/dev/null | sed 's|.*/STORY-||;s|-.*||' | grep -oE '^[0-9]+' | sort -n | tail -1)
origin_max=$(git ls-tree -r --name-only origin/main docs/stories/ 2>/dev/null | sed 's|.*/STORY-||;s|-.*||' | grep -oE '^[0-9]+' | sort -n | tail -1)
next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

Log the renumber decision in the operation report if origin and local diverged. The `git ls-tree -r` recursive flag enumerates the per-state subdir layout — `docs/stories/draft/`, `docs/stories/accepted/`, etc.

### 4. Optional taste prompt for title / scope summary

If interactive (AskUserQuestion available) AND the description is short enough that the derived title slug may not capture intent, fire one `AskUserQuestion` with `header: "Story title"` offering: (a) the derived kebab-slug as default, (b) "edit". This is **taste** authority per ADR-044 — silent-default to (a) when AskUserQuestion is unavailable.

### 5. Write the story file

**File path**: `docs/stories/draft/STORY-<NNN>-<kebab-title>.md`

**Template** (mirrors `docs/stories/README.md` § Story frontmatter + body structure):

```markdown
---
status: draft
story-id: <kebab-slug>
reported: <YYYY-MM-DD>
decision-makers: [<git config user.name>]
problems: [P<NNN>, P<NNN>, ...]
jtbd: [JTBD-<NNN>, JTBD-<NNN>, ...]
rfcs: [<RFC-<NNN>, ...> or empty]
story-maps: [<STORY-MAP-<NNN>, ...> or empty]
estimated-effort: deferred
---

# STORY-<NNN>: <Title>

**Status**: draft
**Reported**: <YYYY-MM-DD>
**Problems**: <P<NNN> [, P<NNN>, ...]>
**JTBD**: <JTBD-<NNN> [, ...]>
**RFCs**: <RFC-<NNN> [, ...]> or (none — populate at accepted transition per I7)
**Story Maps**: <STORY-MAP-<NNN> [, ...]> or (none — populate at accepted transition per I8)
**Estimated effort**: deferred (populate at accepted transition per I10 INVEST Estimable)

## User value (required, INVEST Valuable)

(populate at /wr-itil:manage-story accepted transition — one-paragraph user-facing value statement)

## Acceptance criteria (accepted-gate, INVEST Testable)

- [ ] (populate at /wr-itil:manage-story accepted transition — observable behavioural criteria)

## Driving problem trace (required — I6 invariant)

<description from arguments — one-line summary linking the story scope to the problem's symptom or RCA finding for each driving problem>

## JTBD trace (required — I9 invariant)

<one-line summary linking each JTBD-<NNN> to the persona-job's desired outcome that this story serves>

## Implementation notes (optional)

(deferred — populate at /wr-itil:manage-story accepted transition or during implementation)

## Dependencies

- **Blocks**: (none — populate at /wr-itil:manage-story if applicable)
- **Blocked by**: (none — populate at /wr-itil:manage-story; Phase 2 I-invariant prohibits Blocked-by references to unaccepted stories at acceptance time per INVEST Independent)

## Related

(captured via /wr-itil:capture-story; expand at next /wr-itil:manage-story invocation)
```

The deferred-section pattern matches `capture-rfc`'s placeholder approach — the captured story is intentionally minimal; full INVEST shape lands at the manage-story accepted-transition step.

### 6. Single commit — `## Stories` reverse-trace refresh; no stories README refresh

**Stage list**: the new story file PLUS each driving problem ticket file (refresh `## Stories` reverse-trace section) PLUS each driving JTBD file (refresh `## Stories` reverse-trace section) PLUS each driving RFC file IF `--rfc` was provided (refresh `## Stories` reverse-trace section). **Do NOT** stage `docs/stories/README.md` (deferred). **Do NOT** stage any story-map HTML files — story-maps are spatially-authored HTML; new stories must be placed on the relevant map manually via `/wr-itil:manage-story-map` (when that skill lands per Slice 4 of P170 Phase 2). Capture-story emits an advisory stderr line naming the unplaced-on-map state.

The reverse-trace refresh on driving artefacts IS in-commit per ADR-014 single-commit grain — the cross-tier `## Stories` table on a problem / JTBD / RFC must stay current the moment a new story traces it. The same justification as capture-rfc's inline `## RFCs` refresh applies.

For each problem ID in `$problem_trace`:

```bash
for pid_token in $(echo "$problem_trace" | tr ',' ' '); do
  pid_num="${pid_token#P}"
  # Dual-tolerant ticket discovery (RFC-002 migration window).
  problem_file=$(ls docs/problems/${pid_num}-*.md docs/problems/*/${pid_num}-*.md 2>/dev/null | head -1)
  [ -z "$problem_file" ] && continue
  bash "$(wr-itil-script-path 2>/dev/null || echo packages/itil/scripts)/update-problem-references-section.sh" "$problem_file" "Stories"
  git add "$problem_file"
done
```

Same shape for each JTBD in `$jtbd_trace`:

```bash
for jid_token in $(echo "$jtbd_trace" | tr ',' ' '); do
  jid_num="${jid_token#JTBD-}"
  jtbd_file=$(ls docs/jtbd/*/JTBD-${jid_num}-*.md 2>/dev/null | head -1)
  [ -z "$jtbd_file" ] && continue
  bash "$(wr-itil-script-path 2>/dev/null || echo packages/itil/scripts)/update-jtbd-references-section.sh" "$jtbd_file" "Stories"
  git add "$jtbd_file"
done
```

Same shape for each RFC in `$rfc_trace` (only if non-empty):

```bash
for rid_token in $(echo "$rfc_trace" | tr ',' ' '); do
  [ -z "$rid_token" ] && continue
  rfc_file=$(ls docs/rfcs/${rid_token}-*.md 2>/dev/null | head -1)
  [ -z "$rfc_file" ] && continue
  bash "$(wr-itil-script-path 2>/dev/null || echo packages/itil/scripts)/update-rfc-references-section.sh" "$rfc_file" "Stories"
  git add "$rfc_file"
done
```

The helpers (`update-problem-references-section.sh`, `update-jtbd-references-section.sh`, `update-rfc-references-section.sh`) all support `"Stories"` as a section-name token per Slice 2a/2b verified lookup tables. Each helper is idempotent: a no-op section is a no-op stage.

Stage the new story file:

```bash
git add docs/stories/draft/STORY-<NNN>-<slug>.md
```

Satisfy the commit gate per ADR-014:

- **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
- **Fallback**: invoke `/wr-risk-scorer:assess-release` via the Skill tool when the subagent type is unavailable.

Commit message:

```
feat(itil): capture STORY-<NNN> <title>

Refs: STORY-<NNN>
```

The `capture` verb mirrors `capture-rfc`'s audit signal (lightweight aside path vs. heavyweight `manage-story` intake). The single `Refs: STORY-<NNN>` trailer is the universal story-trailer vocabulary per ADR-060 line 307 + amendment 2026-05-10 nitpick N2 — capture commits and implementation commits both use `Refs:`; the manage-story skill's `draft → in-progress` auto-transition trigger discriminates by "is this the capture commit (subject starts with `capture`) or a subsequent commit" rather than by trailer verb.

### 7. Report

After the commit, report:

- The new story file path and ID.
- The traced problems with their lifecycle states.
- The traced JTBDs with their lifecycle states.
- Any traced RFCs / story-maps if provided, with lifecycle-state advisory warnings.
- Any unplaced-on-story-map advisory (always emit when `--story-map STORY-MAP-<NNN>` was provided — the HTML placement is manual per architect finding 2 on Slice 7).
- Trailing pointer: `Run /wr-itil:manage-story <STORY-<NNN>> next to populate User value + Acceptance criteria + Estimated effort, then advance draft → accepted; refresh docs/stories/README.md.`

The trailing pointer is **not optional** — it is the user-visible signal that the story is intentionally skeleton-only and how to advance it.

## Composition with manage-story

| Concern | manage-story | capture-story |
|---------|--------------|---------------|
| Problem-trace I6 enforcement | Re-validated at every lifecycle transition | Hard-block at capture-time; deny logged to `logs/story-capture-denials.jsonl` |
| JTBD-trace I9 enforcement | Re-validated at every lifecycle transition | Hard-block at capture-time |
| RFC-trace I7 enforcement | Hard-block at `accepted` transition (allows draft stories to exist before RFC reference firms up) | Advisory-warn at capture-time if `--rfc` provided and resolves to draft/proposed lifecycle |
| Story-map-trace I8 enforcement | Hard-block at `accepted` transition | Same advisory-warn pattern at capture-time |
| INVEST shape (I10) | Behavioural checks at `accepted` transition | Out of scope: capture produces a skeleton with deferred-placeholder sections |
| Skeleton-fill | Full-intake; AskUserQuestion for User value + Acceptance criteria + Estimated effort | Deferred-placeholder pattern; one optional taste prompt only |
| Status transitions | Step 7 owns draft → accepted → in-progress → done | Out of scope (creation only) |
| `## Stories` README refresh | P094 / P062 inline (regenerate + stage in same commit) | Deferred to `/wr-itil:manage-story review` or `wr-itil-reconcile-stories` (Slice 9) |
| Commit grain | One commit per intake / per transition | One commit per capture |
| Use case | Full lifecycle management | Aside-invocation; capture-and-continue |

The two skills share the `/tmp/wr-itil-story-capture-grep-${SESSION_ID}` create-gate marker (sibling to the capture-rfc marker per architect verdict on capture-rfc sub-decision (a)).

## Related

- **ADR-060** — Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology + Phase 2 amendment 2026-05-12 (story tier).
- **ADR-060 lines 220-228** — Story frontmatter shape spec.
- **ADR-060 lines 248-253** — I6-I11 story-tier invariants.
- **ADR-060 line 291** — capture-story description (this skill's source-of-truth contract).
- **ADR-060 line 307 + amendment 2026-05-10 nitpick N2** — single-trailer vocabulary (`Refs: STORY-<NNN>`).
- **P170** — driver problem ticket.
- **JTBD-008** — Decompose a Fix Into Coordinated Changes. Primary persona-anchor.
- **JTBD-001** (extended scope) — change-set-level governance composition.
- **JTBD-101** (atomic-fix-adopter friction guard) — capture-story remains opt-in aside-invocation; atomic-RFC fallback per ADR-060 line 262.
- **`docs/stories/README.md`** — story tier lifecycle index + frontmatter/body shape spec (P170 Phase 2 Slice 1 — committed `8562bbc`).
- **ADR-010** — amended skill-granularity: capture-story + manage-story are two skills, not one.
- **ADR-014** — single-commit grain per capture. Commit-message convention.
- **ADR-022** — problem lifecycle conventions; story lifecycle mirrors (draft / accepted / in-progress / done / archived).
- **ADR-032** — governance-skill aside-invocation pattern. Lightweight + heavyweight split.
- **ADR-038** — progressive disclosure. SKILL.md (this file) + future REFERENCE.md split deferred per ADR-054.
- **ADR-044** — decision delegation contract. Authority classes named in the Rule 6 audit table.
- **ADR-049** — plugin-bundled scripts via `bin/` on `$PATH`. `wr-itil-reconcile-stories` shim follows this grammar (Slice 9).
- **ADR-051** — load-bearing-from-the-start. I6 + I9 hard-block ship behaviourally on day one.
- **ADR-052** — behavioural-tests default. Bats coverage at `packages/itil/skills/capture-story/test/capture-story-behavioural.bats` (this slice).
- **ADR-060 Phase 2 Slice 2a/2b reverse-trace helpers** — `update-problem-references-section.sh`, `update-jtbd-references-section.sh`, `update-rfc-references-section.sh` all support `"Stories"` section-name token (verified lookup-table entries).
- **Capture-rfc precedent** — `packages/itil/skills/capture-rfc/SKILL.md` — sibling skill at the RFC tier; structurally near-identical surface.
- **P078** capture-on-correction — capture-story may be the correct response to a strong-signal user correction that names a single INVEST-shaped sub-workstream within an existing RFC.
- **P132 + inverse-P078** — mechanical-stage carve-outs prevent over-asking; named in the Rule 6 audit table.

## Phase-out-of-order note

This skill ships BEFORE `/wr-itil:capture-story-map` (Slice 3 of P170 Phase 2) due to the voice-tone-hook-on-HTML blocker documented at P170 line 297. Building capture-story first is structurally permitted per ADR-060 line 291 (story-map traces optional at capture; I8 enforce only at accepted transition). When Slices 3-6 eventually ship the story-map skills, `manage-story <NNN> accepted` will validate the I8 invariant against the then-existing story-map corpus. The deviation from ADR-060's recommended commit-grain order (line 449-454 — sub-slice 3 story-map skills then sub-slice 4 story skills) is auditable here and in this commit's Slice 7 commit message.
