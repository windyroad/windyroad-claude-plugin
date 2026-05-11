---
name: wr-itil:capture-problem
description: Lightweight problem-capture skill for aside-invocation during foreground work — minimal duplicate-check, skeleton ticket file, single commit per capture, no inline README refresh. Defers full duplicate analysis and README refresh to /wr-itil:review-problems. Use this when the user (or agent mid-iter) wants to capture an observation quickly without disrupting current task flow. For full-intake new-problem creation, use /wr-itil:manage-problem.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Capture Problem Skill

Capture a problem ticket quickly during foreground work. Lightweight aside-invocation surface that complements the heavyweight `/wr-itil:manage-problem` flow. See `REFERENCE.md` in this directory for rationale, edge cases, contract trade-offs, and the ADR-032 foreground-lightweight-capture amendment.

This skill is the foreground-lightweight-capture variant of `/wr-itil:manage-problem`'s new-problem path per ADR-032 (P155 amendment, 2026-05-03). The deferred background-capture variant named in ADR-032's original taxonomy remains deferred per P088 settlement.

## When to invoke

- **Mid-iter sibling-finding**: agent observes a tangential ticket-worthy issue while working on a different problem and cannot afford the 10-turn `/wr-itil:manage-problem` ceremony.
- **User-initiated rapid capture**: user says "btw, this is broken too — capture it" during retros, code reviews, or correction conversations.
- **AFK orchestrator main turn captures**: orchestrator captures user-driven mid-loop observations without breaking the iter cadence.

**Use `/wr-itil:manage-problem` instead** when:
- The user wants to walk the full intake flow (priority discussion, multi-concern split, immediate WSJF placement).
- The capture is large enough that deferred-investigation placeholders are unhelpful (the description IS the full ticket body).
- The capture needs to ride alongside an immediate fix (`fix(scope): ... (closes P<NNN>)` shape — manage-problem's Step 7 transition + Step 11 commit handles this; capture-problem does not).

## Rule 6 audit (per ADR-032 + ADR-013)

This skill has **one classification-only AskUserQuestion (type-tag, taste authority per ADR-044 category 5) and zero control-flow branches keyed on the answer**. Each potentially-interactive decision is framework-mediated per ADR-044:

| Decision | Resolution |
|----------|-----------|
| Duplicate-check | Mechanical 3-keyword title-only grep; matches listed in report; capture proceeds regardless. False-positives are cheaper than false-negatives (P155 line 24). |
| Priority default | Framework-policy: `3 (Medium) — Impact 3 × Likelihood 1` flagged "deferred — re-rate at next /wr-itil:review-problems". |
| Effort default | Framework-policy: `M` flagged "deferred — re-rate at next /wr-itil:review-problems". |
| Multi-concern split | Out of scope: capture-problem creates one ticket per invocation. Multi-concern observations route to `/wr-itil:manage-problem` (its Step 4b owns the split). |
| Empty `$ARGUMENTS` | Halt-with-stderr-directive: print "capture-problem requires a description in $ARGUMENTS — invoke /wr-itil:manage-problem instead for the full intake flow" and exit. AFK orchestrators MUST NOT invoke capture-problem with empty arguments — caller-side contract. |
| Type classification (P170 / ADR-060 item 8c) | Taste authority per ADR-044 category 5. AskUserQuestion fires for `type` ∈ {`technical`, `user-business`} when no caller-side flag pre-resolved it. `--type=<value>` flag pre-resolves the answer (silent-proceed). `--no-prompt` flag defaults to `technical` (silent-proceed). Maintainer-side ONLY: this prompt is paired with JTBD-301 protection — `.github/ISSUE_TEMPLATE/problem-report.yml` (plugin-user-side intake) MUST NOT carry an equivalent type selector; triage assigns the type during `/wr-itil:manage-problem` ingestion of user-reported issues. **I2 invariant** (ADR-060 line 98): the prompt is a classification facet, not a workflow split — Steps 0-7 control-flow is identical regardless of the chosen `type_value`; only the substituted value in the Step 4 skeleton template differs. |

Per ADR-013 Rule 6 fail-safe: every decision above resolves without interactive user input in non-interactive contexts (the type-tag carve-out resolves to `technical` via `--no-prompt` or `--type=` caller-side pre-resolution). AFK orchestrators MUST pass `--no-prompt` or `--type=<value>` per JTBD-006 § Persona Constraints; AFK callers that omit both flags violate the caller-side contract. Interactive and pre-resolved AFK paths produce identical observable outputs except for the `**Type**:` field value, satisfying the I2 invariant by construction.

## Steps

### 0. README reconciliation preflight (P118)

Same as `/wr-itil:manage-problem` Step 0 — diagnose-only check. Halt-and-route on Exit 1 (committed cross-session drift); INLINE_REFRESH carve-out (P149) preserved. capture-problem itself does NOT refresh README.md (see Step 6); the preflight is purely a fail-fast on pre-existing drift.

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

### 1. Parse the description and flags from `$ARGUMENTS`

`$ARGUMENTS` may carry up to two leading flags before the free-text description (caller-side pre-resolution per ADR-044 silent-proceed shape):

| Flag | Effect on Step 1.5 |
|------|-------------------|
| `--type=technical` | Pre-resolves type to `technical`; Step 1.5 skips the AskUserQuestion. |
| `--type=user-business` | Pre-resolves type to `user-business`; Step 1.5 skips the AskUserQuestion. |
| `--no-prompt` | Pre-resolves type to `technical` (default); Step 1.5 skips the AskUserQuestion. |

Strip recognised leading flags from `$ARGUMENTS`; the remainder (after flags) is the free-text description. If both `--type=<value>` and `--no-prompt` are present, `--type=<value>` wins (more specific). Unknown leading flags halt-with-stderr-directive: print "capture-problem: unknown flag '<flag>' — recognised flags: --type=technical, --type=user-business, --no-prompt" and exit.

Empty description (post-flag-strip) halts per the Rule 6 audit above.

Derive a kebab-case title slug from the first 8-10 non-stopword tokens of the description (matching the existing `manage-problem` slug derivation pattern).

### 1.5 Type classification (taste authority per ADR-044 category 5)

Resolve `type_value` ∈ {`technical`, `user-business`} per the following framework-mediated dispatch:

1. **If `--type=<value>` was set in Step 1**: use that value; do NOT fire AskUserQuestion (silent-proceed per ADR-013 Rule 5).
2. **Else if `--no-prompt` was set in Step 1**: default `type_value = technical`; do NOT fire AskUserQuestion. JTBD-006 protection: AFK orchestrators MUST pass this flag (or `--type=<value>`).
3. **Else** (interactive context, no caller-side pre-resolution): fire AskUserQuestion with options `technical` (default) and `user-business`. Question text: *"What type of problem is this?"* Per-option descriptions:
   - `technical` — *"Bug, defect, broken behaviour, framework drift — root cause sits in code or process."*
   - `user-business` — *"Missing capability, UX gap, adopter friction, JTBD-shaped need — root cause sits in unmet user need."*

**I2 invariant guard (ADR-060 line 98)**: the resolved `type_value` is used at Step 4 ONLY as a substituted string in the skeleton template's `**Type**:` body field. Steps 2, 3, 4 (other than the `**Type**:` substitution), 5, 6, 7 execute identically regardless of `type_value`. The skill carries NO control-flow branch keyed on `type` — that would convert classification into a workflow split and violate I2. Pure-bash supporting-script enforcement of this invariant lives in `packages/itil/scripts/test/i2-no-type-branching.bats`; the SKILL.md surface coverage gap is named at P176 (descendant of P012 master harness).

**JTBD-301 scope guard**: this prompt fires on the maintainer-side `/wr-itil:capture-problem` skill only. The plugin-user-side intake (`.github/ISSUE_TEMPLATE/problem-report.yml`) MUST NOT carry an equivalent type selector — plugin-user persona constraint is "no pre-classification". Triage assigns `type` during `/wr-itil:manage-problem` ingestion of user-reported issues, not at user-report time.

### 2. Minimal-grep duplicate check (3-keyword title-only)

Extract up to **3 distinct kebab-cased non-stopword keywords** from the description. Grep the **filenames** of `docs/problems/*.md` AND `docs/problems/<state>/*.md` (NOT bodies — title-only is the conservative threshold per architect verdict on Q1; dual-tolerant per RFC-002 migration window):

```bash
match_count=$(ls docs/problems/*.md docs/problems/*/*.md 2>/dev/null \
              | grep -ciE 'kw1|kw2|kw3' || true)
```

The **3-keyword cap** is a hard-coded constant. Do NOT make it env-overridable — the conservative threshold rationale (P155 line 24) is structural to the design, not a tunable knob.

**Title-only**: file bodies are intentionally NOT scanned. Body-content matches would either (a) over-prompt (capture-problem has no AskUserQuestion to surface them) or (b) get silently swallowed. Title-only matches preserve the conservative-threshold contract.

If matches are found: list them in the final report. **Do NOT halt or branch.** Capture proceeds. The user can resolve duplicates at the next `/wr-itil:review-problems` invocation (or invoke `/wr-itil:manage-problem` directly if the duplicate-check shape needs a structured branch).

**After the grep completes**, write the per-session create-gate marker so the `PreToolUse:Write` hook (P119) permits the subsequent Write of the new `.open.md` file:

```bash
source packages/itil/hooks/lib/session-id.sh
source packages/itil/hooks/lib/create-gate.sh
sid=$(get_current_session_id) && mark_step2_complete "$sid"
```

The marker is shared between `manage-problem` and `capture-problem` per ADR-032 amendment — same `/tmp/manage-problem-grep-${SESSION_ID}` path, idempotent across cross-skill ordering.

### 3. Compute the next ID

Same P056-safe local_max + origin_max formula as `/wr-itil:manage-problem` Step 3:

```bash
# Dual-tolerant ticket enumeration (RFC-002 migration window). Both
# halves of the OR contribute to next-ID compute — flat-layout 104 +
# per-state 204 BOTH appear in `local_max` so the next-ID compute
# never re-allocates an already-taken ID. Architect finding 2 (RFC-002
# T2) — capture-problem's next-ID surface is a separate ADR-031
# contract from generic enumeration; missing the per-state half
# regresses ID allocation. The `git ls-tree -r` recursive flag
# extends the same coverage to the origin tree.
local_max=$(ls docs/problems/*.md docs/problems/*/*.md 2>/dev/null | sed 's|.*/||' | grep -oE '^[0-9]+' | sort -n | tail -1)
origin_max=$(git ls-tree -r --name-only origin/main docs/problems/ 2>/dev/null | sed 's|.*/||' | grep -oE '^[0-9]+' | sort -n | tail -1)
next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

Log the renumber decision in the operation report if origin and local diverged.

### 4. Skeleton-fill the ticket

**File path**: `docs/problems/<NNN>-<kebab-title>.open.md`

**Template** (deferred-placeholder pattern — flag every section the capture didn't fill):

```markdown
# Problem <NNN>: <Title>

**Status**: Open
**Reported**: <YYYY-MM-DD>
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: <type_value>

## Description

<full description from $ARGUMENTS, with leading recognised flags stripped>

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause
- [ ] Create reproduction test

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: (none)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)
```

The deferred-placeholder pattern is load-bearing — `/wr-itil:review-problems` keys off the literal string `(deferred — re-rate at next /wr-itil:review-problems)` to surface captured tickets for re-rating.

### 5. Write the file

Single `Write` to `docs/problems/<NNN>-<kebab-title>.open.md`. The P119 PreToolUse hook permits the Write because Step 2 set the marker.

### 6. Commit per ADR-014 — single commit, no README refresh

**Stage list**: ONLY the new ticket file. **Do NOT** stage `docs/problems/README.md`. The deferred-README-refresh contract is the load-bearing distinction from `/wr-itil:manage-problem` — capture-time speed depends on skipping the regenerate-and-stage cycle.

```bash
git add docs/problems/<NNN>-<kebab-title>.open.md
```

Satisfy the commit gate per ADR-014 — same two-path pattern as manage-problem Step 11:

- **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
- **Fallback**: invoke `/wr-risk-scorer:assess-release` via the Skill tool when the subagent type is unavailable in the current tool surface.

Commit message:

```
docs(problems): capture P<NNN> <title>
```

The `capture` verb in the message is the audit signal that this ticket landed via the lightweight aside path (vs. `open` for manage-problem's full intake).

### 7. Report

After the commit, report:

- The new ticket file path and ID.
- The list of duplicate matches found (if any). If matches found, name them and remind the user to merge at next `/wr-itil:review-problems` if appropriate.
- Trailing pointer: `Run /wr-itil:review-problems next to fold P<NNN> into the WSJF rankings, re-rate the deferred placeholders, and refresh docs/problems/README.md.`

The trailing pointer is **not optional** — it is the user-visible signal that the README is transiently stale and how to reconcile it. Drift here re-opens the deferred-README-refresh contract gap.

## Composition with manage-problem

| Concern | manage-problem | capture-problem |
|---------|----------------|-----------------|
| Duplicate-check | Wide-net grep + AskUserQuestion branch on matches | 3-keyword title-only grep, list-only (no branch) |
| Multi-concern split | Step 4b AskUserQuestion | Out of scope (one ticket per invocation) |
| Skeleton-fill | Full-intake; AskUserQuestion for missing fields | Deferred-placeholder pattern + one classification-only AskUserQuestion (type-tag) |
| Type-tag prompt | Step 4-equivalent AskUserQuestion fires alongside other intake fields | Step 1.5 classification-only AskUserQuestion; `--type=` and `--no-prompt` flags pre-resolve for non-interactive callers; I2 invariant: no control-flow branch keyed on type |
| AskUserQuestion authority | Multiple branches (deviation-approval / direction-setting / taste / mechanical) | Exactly one classification-only fire (taste, ADR-044 cat. 5); zero control-flow branches |
| README refresh | P094 inline (regenerate + stage in same commit) | Deferred to next `/wr-itil:review-problems` |
| Status transitions | Step 7 owns Open → Known Error → Verifying → Closed | Out of scope (creation only) |
| Commit grain | One commit per intake (or per split-concern set) | One commit per capture |
| Use case | Full-intake new problem; user wants to walk the flow | Aside-invocation; capture-and-continue |

The two skills share the `/tmp/manage-problem-grep-${SESSION_ID}` create-gate marker per P119 — calling either skill's Step 2 grep + mark sequence permits new ticket Writes for the rest of the session, regardless of which skill landed first.

## Related

- **P155** (`docs/problems/155-ship-capture-problem-skill.open.md`) — driver ticket.
- **P014** (`docs/problems/014-aside-invocation-for-governance-skills.open.md`) — parent / master tracker.
- **P078** — capture-on-correction OFFER pattern; depends on capture-problem shipping.
- **P119** — manage-problem create-gate hook; capture-problem composes with the same marker.
- **P170** (`docs/problems/170-...open.md`) — RFC framework driver; Slice 4 B7.T3 / item 8c authored the type-classification prompt at Step 1.5.
- **P176** — agent-side I2 (no type-branching) coverage gap on the SKILL.md surface (this file's surface); descendant of P012 master harness ticket. The Step 1.5 I2 invariant guard is enforced by audit-trailed prose here per ADR-052 § Surface 2 escape-hatch contract; behavioural enforcement awaits the master harness.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — foreground-lightweight-capture variant amendment.
- **ADR-038** — progressive-disclosure pattern (SKILL.md + REFERENCE.md split).
- **ADR-044** — decision-delegation contract; type classification is taste authority per category 5; `--no-prompt` / `--type=<value>` are policy-authorised silent-proceed shapes per category 4.
- **ADR-049** — bin/ on PATH; capture-problem reuses the existing `wr-itil-reconcile-readme` shim.
- **ADR-052** — behavioural-tests-default for skill testing; SKILL.md I2 surface coverage gap is named, not silent (P176 + ADR-052 § Surface 2).
- **ADR-060** (`docs/decisions/060-...accepted.md`) — Phase 1 item 8c authored Step 1.5 here; I2 invariant (line 98) governs the no-control-flow-branch contract; line 132 names the maintainer-side-only / JTBD-301-protection scope; line 160 (Confirmation criterion 4) gates the type-prompt placement.
- **JTBD-301** (`docs/jtbd/plugin-user/JTBD-301-...md`) — plugin-user no-pre-classification persona constraint; protected by the Step 1.5 maintainer-side scope guard.
- `packages/itil/skills/manage-problem/SKILL.md` — heavyweight intake counterpart.
- `packages/itil/skills/review-problems/SKILL.md` — re-rates the deferred placeholders + refreshes README.md.
- `packages/itil/scripts/test/i2-no-type-branching.bats` — pure-bash supporting-script enforcement of the I2 invariant; this SKILL.md change does not affect any pure-bash script and so does not change the bats outcome (still green).

$ARGUMENTS
