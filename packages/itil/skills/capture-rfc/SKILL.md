---
name: wr-itil:capture-rfc
description: Lightweight RFC-capture skill for aside-invocation during foreground work — mandatory problem-trace per ADR-060 I1 invariant, skeleton RFC file, single commit per capture, no inline README refresh. Defers full duplicate analysis and README refresh to /wr-itil:manage-rfc. Use this when the user (or agent) wants to capture an RFC quickly with a clear problem trace. For full lifecycle management, use /wr-itil:manage-rfc.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Capture RFC Skill

Capture a Request for Change (RFC) ticket quickly during foreground work. Lightweight aside-invocation surface that complements the heavyweight `/wr-itil:manage-rfc` flow. Mirrors `/wr-itil:capture-problem` shape per ADR-032 lightweight + heavyweight skill split.

This skill is one half of the capture-then-manage RFC framework introduced by ADR-060 (Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology, accepted 2026-05-05). The other half is `/wr-itil:manage-rfc` (heavyweight intake + lifecycle management).

**Related JTBDs**: JTBD-008 (primary — Decompose a Fix Into Coordinated Changes; this skill IS the capture-time decomposition surface), JTBD-001 (extended scope — change-set-level governance), JTBD-101 (atomic-fix-adopter friction guard — capture-rfc remains opt-in, never auto-fires on atomic captures).

## When to invoke

- **Multi-commit fix at the start of work**: agent / user observes that a problem fix decomposes into multiple coordinated changes (a refactor across packages, a phased migration, a framework evolution). Capture an RFC scoping the work *before* the first commit lands so each phase competes for WSJF attention as a first-class entity (per JTBD-008).
- **Retrospective migration**: lifting an existing multi-commit problem into the RFC framework (e.g. RFC-001 retro on P168 in Slice 4 of `docs/plans/170-rfc-framework-story-map.md`). The bounded-escape carve-out at Step 2 permits Closed/Verifying/Parked problem traces for this case.
- **Ad-hoc planned change**: user names work that doesn't yet have a problem ticket but clearly serves one. The I1 invariant requires the problem ticket to exist FIRST — this skill refuses without a `--problem` trace, redirecting the user to `/wr-itil:capture-problem` to open the problem first, then back to capture-rfc.

**Use `/wr-itil:manage-rfc` instead** when:
- The work is moving an existing RFC through its lifecycle (proposed → accepted → in-progress → verifying → closed).
- The user wants to walk a full intake flow with structured re-rank prompts and scope-expansion deviation-approval.
- Multi-RFC coordination decisions need to be captured (manage-rfc handles meta-RFC and cross-RFC ADR creation; capture-rfc creates one RFC per invocation).

## Argument grammar

**Positional**: `<problem-trace> <description>` where `<problem-trace>` is `P<NNN>` or `P<NNN>,P<NNN>,...` (no spaces inside the trace; multiple problems comma-separated).

```
/wr-itil:capture-rfc P168 Pipeline consume-catalog and bootstrap-from-reports — multi-commit retrofit
/wr-itil:capture-rfc P038,P064 Voice-and-tone gates on external comms — coordinated rollout across changeset/PR/release-notes
```

**ADR-060 § Phase 1 item 2 phrasing footnote**: ADR-060 names "mandatory `--problem P<NNN>` flag" verbatim. This skill uses the **positional** form (no `--problem` prefix) to match the lightweight aside-invocation grammar of `capture-problem` (per ADR-032) and because Claude Code skill arguments don't carry a proper CLI flag parser. The hard-block intent (ADR-060 § Confirmation criterion 1: "without a problem trace") is preserved verbatim — only the surface syntax differs. The `--problem` phrasing in ADR-060 reads as exemplar, not contract.

## Rule 6 audit (per ADR-032 + ADR-013 + ADR-060)

This skill has **one direction-setting AskUserQuestion** (problem-trace, when arguments are non-empty but contain no parseable trace) and **one optional taste AskUserQuestion** (title/scope summary, silent-default if unavailable). Every other potentially-interactive decision is framework-mediated per ADR-044:

| Decision | Resolution | Authority class |
|----------|-----------|-----------------|
| Problem trace presence | I1 hard-block — refuse on missing trace; emit deny log + halt-with-stderr-directive | direction-setting (the user/caller MUST supply; framework cannot guess) |
| Problem trace validation | Mechanical: each `P<NNN>` must exist in `docs/problems/`. Open/Known Error/Verifying = pass; Closed/Parked = advisory-warn but proceed (bounded-escape carve-out — see Step 2 rationale) | silent-mechanical |
| RFC ID allocation | Mechanical: `max(local, origin) + 1`, three-digit padded | silent-mechanical |
| Title kebab-slug | Mechanical: first 8-10 non-stopword tokens of description | silent-mechanical |
| Title prose / scope summary refinement | Optional `AskUserQuestion`; silent-default to derived form when unavailable | taste |
| File write / frontmatter | Mechanical: shape per `docs/rfcs/README.md` § RFC body structure | silent-mechanical |
| Single commit | Mechanical: `docs(rfcs): capture RFC-<NNN> <title>` | silent-mechanical |
| Empty arguments | Halt-with-stderr-directive: print "capture-rfc requires `<problem-trace> <description>` — invoke /wr-itil:manage-rfc instead for the full intake flow" and exit. AFK orchestrators MUST NOT invoke capture-rfc with empty arguments. | n/a |

Per ADR-013 Rule 6 fail-safe + ADR-044 + P132 + inverse-P078: every silent-mechanical branch above resolves without user input, so AFK and interactive contexts behave identically modulo the optional taste prompt.

## Steps

### 0. Preflight (Phase 1 cross-directory)

**Phase 1 sequencing note**: this skill's preflight uses `wr-itil-reconcile-readme docs/problems` (the existing problems-README reconciliation contract per P118) because the sibling `wr-itil-reconcile-rfcs` script lands in Slice 3 task B5.T6. RFC trace integrity depends on the problems README being clean — every RFC traces to ≥ 1 problem (I1), so an out-of-date problems README directly threatens the trace validation in Step 2. Once Slice 3 ships `wr-itil-reconcile-rfcs docs/rfcs`, swap this preflight to call BOTH (the cross-tier integrity check holds at both surfaces).

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

The arguments must begin with a problem-trace token (`P<NNN>` or comma-separated `P<NNN>,P<NNN>,...`). The remainder is the description.

```bash
# Tokenise: first token = problem-trace; rest = description
problem_trace="$1"; shift
description="$*"
```

If `$problem_trace` does not match `^P[0-9]{3}(,P[0-9]{3})*$` (regex), this is an I1 violation — go to Step 2's deny path. If `$description` is empty, halt with the empty-arguments directive from the Rule 6 audit table above.

Derive a kebab-case title slug from the first 8-10 non-stopword tokens of `$description` (matching `capture-problem` slug derivation).

### 2. Validate problem trace + I1 hard-block enforcement

For each `P<NNN>` in the trace list:

```bash
# Check existence in any lifecycle status (dual-tolerant — RFC-002
# migration window covers BOTH flat `docs/problems/<NNN>-<title>.<state>.md`
# AND per-state subdir `docs/problems/<state>/<NNN>-<title>.md` layouts).
trace_files=$(ls docs/problems/<NNN>-*.md docs/problems/*/<NNN>-*.md 2>/dev/null)
```

**I1 hard-block (per ADR-060 § Confirmation criterion 1)**:

- **Trace token absent OR malformed**: emit deny log entry + halt with stderr directive:
  ```bash
  mkdir -p logs
  printf '{"timestamp":"%s","session_id":"%s","reason":"%s","args":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(get_current_session_id 2>/dev/null || echo unknown)" \
    "<missing|malformed|unresolved>-trace" \
    "$(printf '%s' "$ARGUMENTS" | jq -Rs .)" \
    >> logs/rfc-capture-denials.jsonl
  echo "/wr-itil:capture-rfc requires a leading problem-trace argument (P<NNN> or P<NNN>,P<NNN>...). Open the driving problem via /wr-itil:capture-problem first, then re-invoke capture-rfc with the trace." >&2
  exit 1
  ```
  The deny log feeds the trace-violation-rate reassessment criterion in ADR-060 § Reassessment Criteria (>20% denial rate triggers ADR-060 reassessment).

- **Each `P<NNN>` must resolve to a file in `docs/problems/`**. If any does not, emit deny log entry with `reason: unresolved-trace` + the unresolved IDs, halt, exit 1.

**Bounded-escape carve-out for Closed/Verifying/Parked traces**:

For each resolved trace file, classify by suffix:
- `.open.md`, `.known-error.md` → pass silently.
- `.verifying.md` → pass with advisory note in the report ("trace P<NNN> is Verification Pending — RFC may close before driving problem closes").
- `.closed.md`, `.parked.md` → pass with advisory-warn in the report ("trace P<NNN> is <Closed|Parked> — capture proceeds for retrospective/historical RFC; bounded-escape carve-out per ADR-060 § Confirmation criterion 5 + Phase 1 item 9").

**Why advisory and not hard-block at capture-time**: the bounded-escape contract in ADR-060 § Confirmation criterion 2 scopes I1 hard-block to `accepted → in-progress` and `→ verifying` lifecycle transitions; advisory-with-escalation only fires at `→ closed` transition. Capture-time tolerance for Closed/Parked traces is **load-bearing for the Phase 1 dogfood pass**: RFC-001 retro on P168 (P168 is `.verifying.md`) is structurally impossible without it. This is NOT a relaxation of I1; it is the bounded-escape window the ADR carved out at the right lifecycle phase. See ADR-060 § Confirmation criterion 5 (no semantic loss) + Phase 1 item 9 (retro migration as dogfood pass).

### 3. Compute next RFC ID

Same `max(local, origin) + 1` formula as `capture-problem` Step 3, scanning `docs/rfcs/RFC-*.md` instead:

```bash
local_max=$(ls docs/rfcs/RFC-*.md 2>/dev/null | sed 's|.*/RFC-||;s|-.*||' | grep -oE '^[0-9]+' | sort -n | tail -1)
origin_max=$(git ls-tree --name-only origin/main docs/rfcs/ 2>/dev/null | sed 's|^docs/rfcs/RFC-||;s|-.*||' | grep -oE '^[0-9]+' | sort -n | tail -1)
next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

Log the renumber decision in the operation report if origin and local diverged.

### 4. Optional taste prompt for title / scope summary

If interactive (AskUserQuestion available) AND the description is short enough that the derived title slug may not capture intent, fire one `AskUserQuestion` with `header: "RFC title"` offering: (a) the derived kebab-slug as default, (b) "edit". This is **taste** authority class per ADR-044 — silent-default to (a) when AskUserQuestion is unavailable or the description already reads as a clean title.

### 5. Write the RFC file

**File path**: `docs/rfcs/RFC-<NNN>-<kebab-title>.proposed.md`

**Template** (mirrors `docs/rfcs/README.md` § RFC body structure):

```markdown
---
status: proposed
rfc-id: <kebab-slug>
reported: <YYYY-MM-DD>
decision-makers: [<git config user.name>]
problems: [P<NNN>, P<NNN>, ...]
adrs: []
jtbd: []
---

# RFC-<NNN>: <Title>

**Status**: proposed
**Reported**: <YYYY-MM-DD>
**Problems**: <P<NNN> [, P<NNN>, ...]>
**ADRs**: (none)
**JTBD**: (none)

## Summary

<description from arguments>

## Driving problem trace

<for each P<NNN>: one-line summary linking the RFC scope to the problem's symptom or RCA finding>

## Scope

(deferred — populate at /wr-itil:manage-rfc accepted transition)

## Tasks

- [ ] (deferred — populate at /wr-itil:manage-rfc accepted transition)

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12; lands in Slice 3 task B5.T9)

## Related

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)
```

The deferred-section pattern matches `capture-problem`'s placeholder approach — the captured RFC is intentionally minimal; full scope and task decomposition land at the manage-rfc accepted-transition step.

### 6. Single commit — `## RFCs` reverse-trace refresh; no rfcs README refresh

**Stage list**: the new RFC file PLUS each driving problem ticket file whose `## RFCs` section needs the reverse-trace row added (per ADR-060 Phase 1 item 10 + Confirmation criterion 3 — auto-maintained reverse trace; architect Q1 verdict skill-side primary). **Do NOT** stage `docs/rfcs/README.md`. The deferred-rfcs-README-refresh contract is the load-bearing capture-time speed differentiator from `/wr-itil:manage-rfc` (mirrors `capture-problem` deferred-`docs/problems/README.md` contract). The next `/wr-itil:manage-rfc review` invocation OR `wr-itil-reconcile-rfcs` refreshes the rfcs README.

The reverse-trace refresh on driving problem tickets, however, IS in-commit per ADR-014 single-commit grain — the cross-tier `## RFCs` table on a problem ticket must stay current the moment a new RFC traces it. Otherwise the trailer hook (`itil-rfc-trailer-advisory.sh`) would fire on every capture commit and the reverse-trace would lag by one manage-rfc invocation.

For each problem ID in `$problem_trace`, invoke the helper before commit:

```bash
for pid_token in $(echo "$problem_trace" | tr ',' ' '); do
  pid_num="${pid_token#P}"
  # Dual-tolerant ticket discovery (RFC-002 migration window).
  problem_file=$(ls docs/problems/${pid_num}-*.md docs/problems/*/${pid_num}-*.md 2>/dev/null | head -1)
  [ -z "$problem_file" ] && continue
  bash "$(wr-itil-script-path 2>/dev/null || echo packages/itil/scripts)/update-problem-rfcs-section.sh" "$problem_file" docs/rfcs
  git add "$problem_file"
done
```

The helper (`packages/itil/scripts/update-problem-rfcs-section.sh`) is idempotent: running over a current section is a no-op. Lazy-empty discipline applies (zero traced RFCs → section absent) — capture-rfc invocations always have ≥ 1 trace at this step, so this surface always emits a populated section. The `git add` is conditional on the helper actually modifying the file — `cmp -s` no-op-on-current is the helper's idempotency contract; `git add` of an unchanged file is also a no-op.

Stage the new RFC file:

```bash
git add docs/rfcs/RFC-<NNN>-<slug>.proposed.md
```

Satisfy the commit gate per ADR-014:

- **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
- **Fallback**: invoke `/wr-risk-scorer:assess-release` via the Skill tool when the subagent type is unavailable.

Commit message:

```
docs(rfcs): capture RFC-<NNN> <title>

Refs: RFC-<NNN>
```

The `capture` verb mirrors `capture-problem`'s audit signal (lightweight aside path vs. heavyweight `manage-rfc` intake). The `Refs: RFC-<NNN>` trailer is the commit-message RFC trailer convention per ADR-060 finding 8 + Phase 1 item 12 (the trailer-recognition hook lands in Slice 3 task B5.T9).

### 7. Report

After the commit, report:

- The new RFC file path and ID.
- The traced problems with their lifecycle states (Open / Known Error / Verifying / Closed / Parked).
- Any advisory warnings (Verifying, Closed, Parked traces).
- Trailing pointer: `Run /wr-itil:manage-rfc <RFC-<NNN>> next to populate Scope / Tasks and advance to accepted; refresh docs/rfcs/README.md.`

The trailing pointer is **not optional** — it is the user-visible signal that the RFC is intentionally skeleton-only and how to advance it.

## Composition with manage-rfc

| Concern | manage-rfc | capture-rfc |
|---------|------------|-------------|
| Problem-trace I1 enforcement | Hard-block at lifecycle transitions to irreversible states; advisory at `→ closed` | Hard-block at capture-time; deny logged to `logs/rfc-capture-denials.jsonl` |
| Multi-RFC / meta-RFC coordination | Step 9 review supports cross-RFC re-rank + meta-RFC ADR creation | Out of scope: capture-rfc creates one RFC per invocation |
| Skeleton-fill | Full-intake; AskUserQuestion for missing fields; deviation-approval on scope expansion | Deferred-placeholder pattern; one optional taste prompt only |
| README refresh | P094 / P062 inline (regenerate + stage in same commit) | Deferred to `/wr-itil:manage-rfc review` or `wr-itil-reconcile-rfcs` (Slice 3) |
| Status transitions | Step 7 owns proposed → accepted → in-progress → verifying → closed | Out of scope (creation only) |
| Commit grain | One commit per intake / per transition | One commit per capture |
| Use case | Full lifecycle management | Aside-invocation; capture-and-continue |

The two skills share the `/tmp/wr-itil-rfc-capture-grep-${SESSION_ID}` create-gate marker (sibling to `/tmp/manage-problem-grep-${SESSION_ID}`; sibling-marker option per architect verdict on capture-rfc sub-decision (a) — preserves audit-trail per-surface granularity).

## Related

- **ADR-060** — Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology. Driving accepted ADR.
- **P170** — `docs/problems/170-...open.md` — driver problem ticket.
- **`docs/plans/170-rfc-framework-story-map.md`** — Slice 2 task B5.T3 lands this skill.
- **JTBD-008** — Decompose a Fix Into Coordinated Changes. Primary persona-anchor.
- **JTBD-001** (extended scope) — change-set-level governance composition.
- **JTBD-101** (atomic-fix-adopter friction guard) — capture-rfc remains opt-in aside-invocation.
- **`docs/rfcs/README.md`** — RFC tier lifecycle index + frontmatter shape spec (Slice 2 tasks B5.T1 + B5.T2 — committed `adc53c8`).
- **ADR-014** — governance skills commit their own work. Single-commit grain per capture.
- **ADR-022** — problem lifecycle conventions; RFC lifecycle mirrors.
- **ADR-032** — governance-skill aside-invocation pattern. Lightweight + heavyweight split.
- **ADR-038** — progressive disclosure. SKILL.md (this file) + future REFERENCE.md split (deferred per ADR-054 — REFERENCE.md lands when SKILL.md size pressure surfaces empirically).
- **ADR-044** — decision delegation contract. Authority classes named in the Rule 6 audit table above.
- **ADR-049** — plugin-bundled scripts via `bin/` on `$PATH`. `wr-itil-reconcile-rfcs` shim follows this grammar (Slice 3 B5.T7).
- **ADR-051** — load-bearing-from-the-start. I1 hard-block ships behaviourally on day one, not deferred.
- **ADR-052** — behavioural-tests default. Bats coverage in Slice 2 task B5.T5 (no structural grep on SKILL.md content per P081).
- **P057** — staging trap rule (re-stage after Edit) — applies to capture-rfc only when an Edit follows the Write (rare; lifecycle-transition territory belongs to manage-rfc).
- **P078** capture-on-correction — capture-rfc may be the correct response to a strong-signal user correction that names multi-commit work; orchestrators should offer capture-rfc as one option in the capture menu.
- **P119** — create-gate marker. Hook generalisation per architect verdict on sub-decision (a) — `manage-problem-enforce-create.sh` widens to also accept `docs/rfcs/RFC-*.proposed.md` Writes, with case-branched deny messages naming the right skill (capture-rfc vs capture-problem).
- **P132** + inverse-P078 — mechanical-stage carve-outs prevent over-asking; named in the Rule 6 audit table.
