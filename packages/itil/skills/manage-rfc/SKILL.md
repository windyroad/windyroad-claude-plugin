---
name: wr-itil:manage-rfc
description: Heavyweight RFC intake + lifecycle management following the ADR-060 Problem-RFC-Story framework. Creates new RFCs (delegates to /wr-itil:capture-rfc for the lightweight path), updates existing RFCs, transitions through proposed → accepted → in-progress → verifying → closed lifecycle, runs WSJF re-rank reviews, and refreshes docs/rfcs/README.md per the P062 / P094 contract pattern.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task
---

# Manage RFC Skill

Create, update, or transition RFC tickets following the Problem-RFC-Story framework introduced by ADR-060 (accepted 2026-05-05). This skill is the heavyweight counterpart to `/wr-itil:capture-rfc` — it owns the full intake flow, lifecycle transitions, batch review, and README refresh.

**Related JTBDs**: JTBD-008 (primary — Decompose a Fix Into Coordinated Changes; this skill governs the lifecycle of decomposed work), JTBD-001 (extended scope — change-set-level governance), JTBD-101 (atomic-fix-adopter — every fix goes through an RFC per ADR-071; the RFC skills are invoked deliberately, not auto-fired, because RFC scope is direction-setting per ADR-073 — NOT because atomic fixes skip ceremony).

## RFC Lifecycle

| Status | File suffix | Meaning | Entry criteria |
|--------|-----------|---------|----------------|
| **Proposed** | `.proposed.md` | RFC captured, scope not yet ratified | Driving problem(s) traced; capture-rfc complete |
| **Accepted** | `.accepted.md` | Scope ratified, ready to start work | Architect+JTBD reviews passed; tasks decomposed; commits-to-be-authored named |
| **In-Progress** | `.in-progress.md` | Work underway, commits landing | First commit with `Refs: RFC-<NNN>` trailer authored |
| **Verifying** | `.verifying.md` | Work shipped, awaiting verification | All tasks complete; release marker present in `## Verification` |
| **Closed** | `.closed.md` | Verified; RFC complete | User confirms verification; driving problem(s) Closed or trace-bounded-escape applies |

Each transition is a `git mv` + Edit + restage + README refresh + commit per ADR-014.

## I1 enforcement at lifecycle transitions

Per ADR-060 § Decision Outcome line 97 + § Confirmation criteria 1+2:

| Transition | I1 enforcement |
|------------|---------------|
| capture-time (`/wr-itil:capture-rfc`) | **Hard-block** on missing/malformed/unresolved problem-trace. Deny logged to `logs/rfc-capture-denials.jsonl`. |
| `proposed → accepted` | Hard-block if any `problems:` entry is no longer resolvable (deleted ticket file). Architect+JTBD re-review gate fires here. |
| `accepted → in-progress` | **Hard-block** (irreversible state per ADR-060 line 97) if any traced problem is missing or orphan (Closed/Parked allowed only via `Refs: RFC-<NNN>` retro-pattern; bounded-escape carve-out applies to retrospective RFCs only — see capture-rfc Step 2 rationale). |
| `in-progress → verifying` | **Hard-block** (irreversible state) — same rules as `→ in-progress`. |
| `verifying → closed` | **Advisory-with-escalation**: if driving problem is Closed/Parked AND no still-open trace exists, emit warning naming the trace history; proceed if user confirms (or AFK fallback per ADR-013 Rule 6). This is the bounded escape per ADR-060 line 97 — closing an RFC whose driving problem was already closed is the legitimate retrospective-completion path. |

## WSJF Prioritisation (RFC-level Phase 1)

Per ADR-060 § Decisions Resolved: WSJF placement is **RFC-level for Phase 1**. Story-level WSJF is structurally impossible without story-mapping infrastructure (Phase 2 deferred).

**WSJF = (Severity × Status Multiplier) / Effort**

- Severity = inherited from highest-severity traced problem (max across the `problems:` list).
- Status Multiplier:

  | Status | Multiplier |
  |--------|-----------|
  | Accepted | 2.0 |
  | In-Progress | 1.5 |
  | Proposed | 1.0 |
  | Verifying | 0 (excluded — user-side) |
  | Closed | 0 (excluded — done) |

- Effort = S / M / L / XL same divisors as problem WSJF (S=1, M=2, L=4, XL=8). Marginal effort per RFC; transitive effort propagation deferred to Phase 2 when multi-RFC dependencies surface.

## Steps

### 0. Preflight (Phase 1 cross-directory)

Same Phase 1 sequencing note as capture-rfc Step 0: `wr-itil-reconcile-readme docs/problems` is the Phase 1 preflight (Slice 3 ships `wr-itil-reconcile-rfcs`; once it lands, this preflight calls both).

```bash
wr-itil-reconcile-readme docs/problems > /tmp/wr-itil-drift-$$.txt
reconcile_exit=$?
if [ "$reconcile_exit" -eq 1 ]; then
  wr-itil-classify-readme-drift /tmp/wr-itil-drift-$$.txt docs/problems
  classify_exit=$?
  rm -f /tmp/wr-itil-drift-$$.txt
fi
```

### 1. Parse arguments

The argument shape determines the operation:

- **Empty** → halt with stderr directive: "manage-rfc requires an argument: `<RFC-NNN>` for update, `<RFC-NNN> <status>` for transition, `review` for batch re-rank, `list` for display. To create a new RFC use /wr-itil:capture-rfc directly."
- **`RFC-<NNN>` bare** → update flow (Step 6).
- **`RFC-<NNN> <status>`** where `<status>` ∈ `{accepted, in-progress, verifying, close}` → transition (Step 7).
- **`review`** → batch re-rank (Step 9).
- **`list`** → display (Step 8).
- **Anything else** → halt with stderr directive directing the user to capture-rfc for new RFCs.

The lightweight + heavyweight split per ADR-032 + ADR-010 amended Skill Granularity rule means manage-rfc does NOT host new-RFC creation inline. Capture-rfc owns the intake; manage-rfc owns lifecycle.

### 6. Update flow (bare `RFC-<NNN>`)

Find the file matching the RFC ID:

```bash
ls docs/rfcs/RFC-<NNN>-*.md 2>/dev/null
```

Apply the update — typical edits:
- Filling `## Scope` after architect+JTBD review.
- Decomposing `## Tasks` into ordered work-items.
- Adding `## Related` entries.
- Updating `decision-makers` or `adrs` frontmatter when ADRs are referenced mid-RFC execution.

**Do NOT add a "Considered Options / Alternatives Rejected" section to the RFC body.** Per ADR-070 (RFCs hold no independent decisions), every contested choice among ≥ 2 viable options is recorded as an ADR (inheriting the ADR-064 confirm gate + ADR-066 oversight marker) and referenced in the RFC's `adrs:` frontmatter — never re-argued in the RFC body. An RFC carries only scope, decomposition (sequencing/breakdown of already-decided work), and traces. The ADR-052 behavioural lint hard-fails any RFC body that contains a rejected-alternatives block without a matching `adrs:` reference.

#### README refresh on conditional update (P094 mirror)

If the update changed any ranking-bearing field (Status, Severity-via-problems, Effort, WSJF), regenerate `docs/rfcs/README.md` in-place reflecting the new ranking and stage it in the same commit. If the edit touched only `## Summary`, `## Scope`, `## Tasks`, `## Related`, or other non-ranking sections, skip the refresh.

**Mechanism** mirrors P094 in `manage-problem` Step 6 — render not re-rank; trust other RFC files' stored WSJF; consume only the post-edit RFC's WSJF for the ranking table.

### 7. Status transitions

Each transition is a `git mv` + Edit + `git add` (P057 staging trap) + README refresh + commit.

**Pre-flight checks before each transition**:

| Transition | Checks |
|------------|--------|
| `proposed → accepted` | All `problems:` entries resolve. Architect re-review PASS. JTBD re-review PASS. `## Scope` populated (not "deferred"). `## Tasks` decomposed (≥ 1 task; not just deferred placeholder). |
| `accepted → in-progress` | First commit referencing `Refs: RFC-<NNN>` exists OR is being authored in this same commit. I1 hard-block on missing/orphan trace. |
| `in-progress → verifying` | All `## Tasks` checked. `## Verification` section drafted (release marker, user-side check, trace closure path). I1 hard-block on missing/orphan trace. |
| `verifying → closed` | User explicitly confirms (or AFK Rule 6 fallback for evidence-based close per ADR-022 / ADR-044 framework-resolved silent dispatch). I1 advisory-with-escalation if driving problems Closed/Parked. |

If any pre-flight fails: report which checks failed; do NOT proceed; offer `AskUserQuestion` for direction-setting decisions (e.g., "scope still says deferred — populate now or park the transition?") only when the resolution is genuinely user-direction territory per ADR-044.

#### Transition mechanics

```bash
git mv docs/rfcs/RFC-<NNN>-<slug>.<old-status>.md docs/rfcs/RFC-<NNN>-<slug>.<new-status>.md
# ... use the Edit tool to update Status field + add transition-specific sections (e.g. ## Verification on `→ verifying`) ...
git add docs/rfcs/RFC-<NNN>-<slug>.<new-status>.md
```

**P057 staging trap rule**: re-stage explicitly after the Edit tool runs. `git mv` alone stages only the rename, not subsequent content edits.

#### README refresh on every transition (P062 mirror)

After renaming + Editing + `git add`-ing the transitioned RFC file, regenerate `docs/rfcs/README.md` in-place reflecting the new filename set and the transitioned RFC's new Status. Stage the refreshed README with the same commit.

Update the "Last reviewed" line on `docs/rfcs/README.md` per the **inline P134 rotation mechanism** below. The mechanism is inlined here at the execution site (not deferred via cross-reference to `manage-problem` SKILL.md Step 5) so a single-pass agent reading this Step does not silently skip the archive step. **Skipping the BEFORE-rewrite archive step destroys the displaced fragment and re-opens P331** (origin failure mode: iter-7 + iter-8 of 2026-05-30's AFK work-problems session silently skipped the equivalent rotation on `docs/problems/README.md` in 2 of 9 transition-bearing iters). The mechanism MUST execute IN ORDER:

1. **Read** line 3 of `docs/rfcs/README.md`: `awk 'NR==3' docs/rfcs/README.md` (`head -3 | tail -1` or `sed -n '3p'` are acceptable equivalents).
2. **Append-if-non-empty (BEFORE step 3, not after)** — if line 3 is non-empty AND not a same-session same-verb near-duplicate of the new fragment, append the existing line 3 verbatim to `docs/rfcs/README-history.md` (created on first rotation) under a `## YYYY-MM-DD` heading. Run this BEFORE the Edit-tool rewrite in step 3 — Edit's replace pattern destroys the displaced content otherwise.
3. **Rewrite** line 3 of `docs/rfcs/README.md` with the new fragment of form `> Last reviewed: YYYY-MM-DD **<event>** — <one-line summary>` (e.g. `RFC-<NNN> <status> — <one-line summary>`). Soft cap ≤ 1024 bytes per fragment; hard ceiling 5120 bytes per ADR-040 Tier 3 envelope.
4. **Stage both** — `git add docs/rfcs/README.md docs/rfcs/README-history.md` so the same single commit per ADR-014 captures both files.

Canonical rationale anchor: `manage-problem` SKILL.md Step 5 § Last-reviewed line discipline (P134). The discipline applies identically across `docs/problems/README.md`, `docs/rfcs/README.md`, and `docs/stories/README.md` (only the target index path differs). The cross-reference is preserved for the "why"; the "what" is inlined above for execution-time legibility per P331.

#### Reverse trace on driving problem(s) (skill-side primary surface)

Per ADR-060 Phase 1 item 10 + Confirmation criterion 3 + architect Q1 verdict (skill-side primary, hook-side advisory for arbitrary commits): every transition refreshes the `## RFCs` section on each driving problem ticket inline in the same commit per ADR-014 single-commit grain.

For each `P<NNN>` in the transitioned RFC's frontmatter `problems:` list:

```bash
for pid_token in $(awk '/^problems:/{gsub(/[][]/,"");gsub(/,/,"\n");for(i=2;i<=NF;i++)print $i;exit}' "$rfc_file"); do
  pid_num="${pid_token#P}"
  # Dual-tolerant ticket discovery — RFC-002 migration window covers
  # BOTH flat (`docs/problems/<NNN>-<title>.<state>.md`) AND per-state
  # subdir (`docs/problems/<state>/<NNN>-<title>.md`) layouts.
  problem_file=$(ls docs/problems/${pid_num}-*.md docs/problems/*/${pid_num}-*.md 2>/dev/null | head -1)
  [ -z "$problem_file" ] && continue
  wr-itil-update-problem-rfcs-section "$problem_file" docs/rfcs
  git add "$problem_file"
done
```

The helper (`packages/itil/scripts/update-problem-rfcs-section.sh`) is idempotent and applies lazy-empty discipline (zero traced RFCs → section absent — a structural rendering rule, not a ceremony exemption; a problem traces ≥ 1 RFC once it reaches fix-time per ADR-071 / I13). After the transition, the helper:
- Updates the row's `Status` column to the new lifecycle status.
- Removes the row when this transition de-traces a problem (frontmatter `problems:` edit removed the entry).
- No-op when the table is already current (idempotent contract).

The trailer hook (`itil-rfc-trailer-advisory.sh`) sits on top of this skill-side contract as a drift-detection backstop for ARBITRARY commits (e.g. `feat(...)` commits with `Refs: RFC-<NNN>` trailers authored outside the RFC skills) — it never auto-fixes; it advises.

#### Forward trace — `## Stories` body section (Phase 2)

Per ADR-060 line 270 + line 296: every transition that touches the RFC body refreshes the RFC's own `## Stories` body section from its frontmatter `stories:` array. The forward-trace surface renders the ordered execution sequence as inline links to the story files, lazy-empty when `stories: []` (an RFC not decomposed into stories). The helper is the Slice 2b sibling `update-rfc-references-section.sh`:

```bash
wr-itil-update-rfc-references-section "$rfc_file" "Stories"
```

Idempotent + lazy-empty per the Slice 2a/2b contract. Run after the rename + frontmatter edit so the section reflects the post-transition `stories:` shape. Stage the RFC file (already staged for the lifecycle transition; the helper modifies the same file in-place).

This composes with the existing `## Story Maps` refresh that the same helper handles via `update-rfc-references-section.sh "$rfc_file" "Story Maps"` — when the RFC traces story-maps via the `story-maps:` frontmatter field (Phase 2+).

### 8. List flow (`list`)

Read all `.proposed.md`, `.accepted.md`, `.in-progress.md` files in `docs/rfcs/`. Extract ID, title, status, traced problems. Sort by Status priority (Accepted > In-Progress > Proposed) then by `Reported` ASC. Display as a markdown table.

### 9. Review flow (`review`)

Batch re-rank all RFCs and refresh `docs/rfcs/README.md`.

**Step 9a**: Read `RISK-POLICY.md` for current Severity bands.

**Step 9b**: For each RFC in `proposed`/`accepted`/`in-progress` status:
1. Read the RFC file + each traced problem file.
2. Severity = `max(Severity(problem) for problem in problems)` (highest-severity trace dominates).
3. Re-estimate Effort against current `## Scope` + `## Tasks` decomposition.
4. WSJF = (Severity × Status Multiplier) / Effort divisor.
5. Update WSJF/Effort lines in the RFC file if changed.

**Step 9c**: Present a WSJF-ranked table (open + accepted + in-progress only). Verifying RFCs go in a Verification Queue section sorted by Released date ASC (canonical VQ sort direction per P150). Closed RFCs go in a Closed section (cosmetic, no ranking).

**Step 9d**: For each `.verifying.md` RFC, collect in-session evidence per ADR-044 framework-resolved silent dispatch (mirrors `manage-problem` Step 9d). Concrete + unambiguous citation → close on evidence via the transition path. Ambiguous/absent → leave as Verifying.

**Step 9e**: Update changed files; refresh `docs/rfcs/README.md`; refresh the `## RFCs` reverse-trace section on every problem ticket whose traced RFCs changed status or title in this batch (per ADR-060 Phase 1 item 10 + Confirmation criterion 3 — skill-side primary):

```bash
# Aggregate the union of P<NNN> across all RFCs touched in this review.
for problem_file in $(printf '%s\n' "${touched_problem_files[@]}" | sort -u); do
  wr-itil-update-problem-rfcs-section "$problem_file" docs/rfcs
  git add "$problem_file"
done
```

The helper is idempotent — a problem ticket whose `## RFCs` table is already current emits no diff, and `git add` of an unchanged file is a no-op. Any drift gets fixed in this commit per ADR-014 single-commit grain. Commit per ADR-014:

```
docs(rfcs): review — re-rank RFC priorities
```

### 11. Report + commit

After any operation, report the file path created/modified, the RFC ID, current status, and any quality-check warnings.

Commit conventions per operation:

| Operation | Commit message |
|-----------|---------------|
| Update (no transition) | `docs(rfcs): update RFC-<NNN> — <change summary>` |
| `proposed → accepted` | `docs(rfcs): RFC-<NNN> accepted — <one-line scope summary>` |
| `accepted → in-progress` | usually folded into the first `feat(...)` / `fix(...)` / `chore(...)` commit that authors the RFC's first task — rename rides with that commit and trailer is `Refs: RFC-<NNN>` |
| `in-progress → verifying` | usually folded into the final task commit — rename + `## Verification` edit ride with the shipping commit |
| `verifying → closed` | `docs(rfcs): close RFC-<NNN> <title>` |
| Review/re-rank | `docs(rfcs): review — re-rank RFC priorities` |

All commit messages on RFC-bearing commits carry the `Refs: RFC-<NNN>` trailer (ADR-060 finding 8 + Phase 1 item 12).

Satisfy the commit gate per ADR-014 — primary path delegates to `wr-risk-scorer:pipeline` subagent; fallback invokes `/wr-risk-scorer:assess-release` skill.

### 12. Auto-release (skip in AFK orchestrator)

Same conditional drain as `manage-problem` Step 12: if not in an AFK orchestrator AND `.changeset/` is non-empty AND push/release within appetite, run `npm run push:watch` then `npm run release:watch`. Held-changeset window per ADR-042 / P162 governs which changesets graduate; RFC-shaped held changesets graduate atomically per ADR-060 architect finding 12.

## Held-changeset window scope (Phase 1)

Phase 1 of the RFC framework (Slices 2-5 per `docs/plans/170-rfc-framework-story-map.md`) ships under a held-changeset window. ADR-042 auto-apply is paused until RFC-001 (P168 retro) reaches `closed` status. Counterfactual risk assessment per P162 governs graduation: delay-risk vs release-risk. The full chain graduates atomically — the entire RFC-001 commit chain ships or nothing does.

## Composition with capture-rfc

| Concern | manage-rfc (this skill) | capture-rfc (sibling) |
|---------|-------------------------|----------------------|
| New RFC creation | Out of scope; redirect to capture-rfc | Owns the lightweight path |
| Lifecycle transitions | Owns proposed → accepted → in-progress → verifying → closed | Out of scope |
| WSJF re-rank | Step 9 review owns batch re-rank | Out of scope |
| README refresh | P094 / P062 inline (regenerate + stage in same commit) | Deferred (capture-time speed) |
| Commit grain | One commit per intake / per transition / per review | One commit per capture |
| AskUserQuestion authority | direction-setting (transition-trigger ambiguity), deviation-approval (scope expansion mid-RFC), silent-mechanical (status renames, README refresh) | direction-setting (problem-trace), taste (title), silent-mechanical (everything else) |

The two skills share the `/tmp/wr-itil-rfc-capture-grep-${SESSION_ID}` create-gate marker (sibling to `/tmp/manage-problem-grep-${SESSION_ID}`).

## Related

- **ADR-060** — Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology.
- **P170** — driver problem ticket.
- **`docs/plans/170-rfc-framework-story-map.md`** — Slice 2 task B5.T4 lands this skill.
- **JTBD-008** (primary), JTBD-001 (extended scope), JTBD-101 (atomic-fix-adopter — every fix via RFC per ADR-071).
- **`docs/rfcs/README.md`** — lifecycle index + frontmatter shape (Slice 2 B5.T1 + B5.T2 — `adc53c8`).
- **`packages/itil/skills/capture-rfc/SKILL.md`** — sibling lightweight capture skill.
- **`packages/itil/skills/manage-problem/SKILL.md`** — heavyweight counterpart at the problem tier; structural template for this skill.
- **ADR-014** — single-commit governance grain.
- **ADR-022** — lifecycle suffix-based (RFC mirrors).
- **ADR-032** — lightweight + heavyweight split.
- **ADR-038** — progressive disclosure; future REFERENCE.md split deferred per ADR-054.
- **ADR-042** — held-changeset auto-apply; window discipline.
- **ADR-044** — decision delegation contract; authority classes.
- **ADR-049** — `wr-itil-reconcile-rfcs` shim grammar (Slice 3).
- **ADR-051** — load-bearing-from-the-start; I1 hard-block on day one.
- **ADR-052** — behavioural-tests default; bats coverage in Slice 2 B5.T5.
- **P057** — staging trap rule (re-stage after Edit on every transition).
- **P062** — README refresh on transition.
- **P094** — README refresh on conditional update.
- **P118** — README reconciliation contract.
- **P132** + inverse-P078 — mechanical-stage carve-outs prevent over-asking.
- **P134** — Last-reviewed line discipline (single fragment + history archive).
- **P138** — tie-break ladder consistency.
- **P150** — Verification Queue sort direction.
- **P162** — held-changeset graduation criteria.
