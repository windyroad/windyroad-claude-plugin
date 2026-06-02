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

This skill has **at most one classification-only AskUserQuestion (persona, on JTBD-cited descriptions with disagreeing personas only) and zero control-flow branches keyed on the answer**. Each potentially-interactive decision is framework-mediated per ADR-044:

| Decision | Resolution |
|----------|-----------|
| Duplicate-check | Mechanical 3-keyword title-only grep; matches listed in report; capture proceeds regardless. False-positives are cheaper than false-negatives (P155 line 24). |
| Hang-off arbitration (P346 Phase 3) | Mechanical pre-filter (≤5 candidates by shared ADR/RFC/SKILL/file signal) + fresh-context `wr-itil:hang-off-check` subagent dispatch (ADR-032 5th invocation pattern). Verdict-acts: `HANG_OFF: P<NNN>` halts capture + routes orchestrator to amend parent; `PROCEED_NEW` continues + appends rationale to `## Related`. AFK safe-default: ambiguous → PROCEED_NEW per subagent Rule 6 contract. JTBD-301 firewall: maintainer-side only. |
| Priority default | Framework-policy: `3 (Medium) — Impact 3 × Likelihood 1` flagged "deferred — re-rate at next /wr-itil:review-problems". |
| Effort default | Framework-policy: `M` flagged "deferred — re-rate at next /wr-itil:review-problems". |
| Multi-concern split | Out of scope: capture-problem creates one ticket per invocation. Multi-concern observations route to `/wr-itil:manage-problem` (its Step 4b owns the split). |
| Empty `$ARGUMENTS` | Halt-with-stderr-directive: print "capture-problem requires a description in $ARGUMENTS — invoke /wr-itil:manage-problem instead for the full intake flow" and exit. AFK orchestrators MUST NOT invoke capture-problem with empty arguments — caller-side contract. |
| JTBD-trace derivation (P287 retained surface) | **Derive-first; silent-framework per ADR-044 category 4 on lexical citations or `--jtbd=` flag pre-resolution.** Step 1.5b runs a lexical detector (`\bJTBD-[0-9]+\b`) against the description. Any cited JTBD IDs are recorded silently. No AskUserQuestion in this dispatch — capture-time JTBD anchoring is optional; the next reviewer can refine at `/wr-itil:review-problems` or `/wr-itil:manage-problem` ingestion. |
| Persona derivation (P287 retained surface, decoupled from type) | **Derive-first; silent-framework per ADR-044 category 4 when JTBDs cited and agree.** If JTBDs were cited at Step 1.5b, persona derives from the cited JTBDs' frontmatter. Disagreement across cited JTBDs falls back to AskUserQuestion (genuine taste). Empty persona is legal — no hard-block. |

**P287 amendment 2026-06-02 — type-classification retired**: the maintainer-side type-classification dispatch (technical vs user-business) was REMOVED per twice-confirmed user direction (2026-05-25 + 2026-06-02). The redundant axis was already covered by RFC/Story persona-anchoring per ADR-060 Phase 4. JTBD-trace + persona dispatch survive as the JTBD-as-source-of-truth surface; the I12 hard-block (type-keyed JTBD-required halt) is also retired pending ADR-060 amendment substance ratification.

Per ADR-013 Rule 6 fail-safe: every decision above resolves without interactive user input in non-interactive contexts. The Persona fallback AskUserQuestion fires only on cited-JTBD-disagreement (genuine ADR-044 category 5 taste); AFK orchestrators avoid this branch by passing `--persona=<value>` or by capturing without JTBD citations.

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

| Flag | Effect on Step 1.5b |
|------|-------------------|
| `--jtbd=JTBD-NNN[,JTBD-NNN...]` | Pre-resolves the JTBD-trace value. Step 1.5b skips the JTBD-trace lexical dispatch. Comma-separated list of JTBD IDs (no spaces). |
| `--persona=<value>` | Pre-resolves the persona value. Step 1.5b skips persona derivation. Value MUST be one of: `developer`, `tech-lead`, `plugin-developer`, `plugin-user`. |

Strip recognised leading flags from `$ARGUMENTS`; the remainder (after flags) is the free-text description. Unknown leading flags halt-with-stderr-directive: print "capture-problem: unknown flag '<flag>' — recognised flags: --jtbd=JTBD-NNN, --persona=<value>" and exit.

**P287 retirement note**: `--type=technical`, `--type=user-business`, and `--no-prompt` are RETIRED (P287, 2026-06-02). The type-classification axis was removed per twice-confirmed user direction; the AFK-default flag `--no-prompt` is obsolete since the only AskUserQuestion it suppressed is gone. AFK orchestrators that previously passed `--no-prompt` should drop the flag; capture-problem is now silent-by-default.

Empty description (post-flag-strip) halts per the Rule 6 audit above.

Derive a kebab-case title slug from the first 8-10 non-stopword tokens of the description (matching the existing `manage-problem` slug derivation pattern).

### 1.5b JTBD-trace + persona dispatch (P287 — decoupled from type)

Per ADR-060 § Phase 3 + Phase 4 in-scope amendment (2026-05-13), as amended by P287 (2026-06-02 — type-classification retired). Fires UNCONDITIONALLY (no longer keyed on `type_value = user-business`; the type axis was removed). Both `jtbd_trace_value` and `persona_value` are OPTIONAL — capture-time anchoring is best-effort; the next reviewer can refine at `/wr-itil:review-problems` or `/wr-itil:manage-problem` ingestion.

**Resolve `jtbd_trace_value`** (an ORDERED list of JTBD IDs, possibly empty) via the following dispatch:

1. **If `--jtbd=JTBD-NNN[,JTBD-NNN...]` was set in Step 1**: parse comma-separated list; assign to `jtbd_trace_value`; do NOT run the lexical detector; do NOT fire AskUserQuestion (silent-proceed per ADR-013 Rule 5).
2. **Else** run the **lexical JTBD-trace detector** against the description: `grep -oE '\bJTBD-[0-9]+\b' | sort -u`. If matches found, set `jtbd_trace_value` to the matched IDs (de-duplicated, sorted ascending) and emit stderr advisory: `capture-problem: derived jtbd-trace=<id-list> from description JTBD-NNN citations; re-invoke with --jtbd= to override`. Do NOT fire AskUserQuestion.
3. **Else (no flag, no lexical detection)**: leave `jtbd_trace_value` empty. The `**JTBD**:` line is omitted from the Step 4 skeleton template. No hard-block — capture-time JTBD anchoring is optional under P287; the I12 hard-block (type-keyed JTBD-required halt) was retired alongside the type axis. ADR-060 amendment substance (whether JTBD anchoring should become a nullable-field-conditional gate keyed on some other discriminator) is queued for user re-confirmation per ADR-074.

**Resolve `persona_value`** (a scalar enum value OR empty) via the following dispatch:

1. **If `--persona=<value>` was set in Step 1**: validate `<value>` ∈ `{developer, tech-lead, plugin-developer, plugin-user}`; halt with directive if invalid; otherwise assign and proceed silently.
2. **Else if `jtbd_trace_value` is non-empty**: derive persona from cited JTBDs' frontmatter. Read each cited `docs/jtbd/<persona>/JTBD-<NNN>-*.md` file; extract its `persona:` (and optionally `secondary-persona:`) frontmatter values; if all cited JTBDs agree on a single persona, set `persona_value` to that persona silently and emit stderr advisory: `capture-problem: derived persona=<value> from cited JTBD <id> frontmatter`. If cited JTBDs disagree, fire AskUserQuestion with the union-of-derived-personas as options (genuine taste per ADR-044 category 5 — cited JTBDs have ratified-coherent contradictory persona constraints, only the user can resolve which applies to THIS problem).
3. **Else (no JTBDs cited, no `--persona=` flag)**: leave `persona_value` empty. `persona:` frontmatter is OPTIONAL — capture-time persona anchoring is best-effort.

**JTBD-301 scope preservation**: this dispatch fires on the maintainer-side `/wr-itil:capture-problem` only. Plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` MUST NOT prompt for JTBD trace or persona — preserves the JTBD-301 firewall per ADR-060 P4.3 maintainer-side / plugin-user-side asymmetry clarifier. Triage during `/wr-itil:manage-problem` ingestion assigns both fields from the reporter's symptom signals (per the JTBD-301 maintainer-side-complement extension landed 2026-05-13).

### 2. Minimal-grep duplicate check (3-keyword title-only) + hang-off-check subagent dispatch (P346 Phase 3 amendment, 2026-05-31)

**Sub-step 2a — title-only grep (pre-existing minimal duplicate check)**

Extract up to **3 distinct kebab-cased non-stopword keywords** from the description. Grep the **filenames** of `docs/problems/*.md` AND `docs/problems/<state>/*.md` (NOT bodies — title-only is the conservative threshold per architect verdict on Q1; dual-tolerant per RFC-002 migration window):

```bash
match_count=$(ls docs/problems/*.md docs/problems/*/*.md 2>/dev/null \
              | grep -ciE 'kw1|kw2|kw3' || true)
```

The **3-keyword cap** is a hard-coded constant. Do NOT make it env-overridable — the conservative threshold rationale (P155 line 24) is structural to the design, not a tunable knob.

**Title-only**: file bodies are intentionally NOT scanned. Body-content matches would either (a) over-prompt (capture-problem has no AskUserQuestion to surface them) or (b) get silently swallowed. Title-only matches preserve the conservative-threshold contract.

If matches are found: list them in the final report. **Do NOT halt or branch.** Capture proceeds. The user can resolve duplicates at the next `/wr-itil:review-problems` invocation (or invoke `/wr-itil:manage-problem` directly if the duplicate-check shape needs a structured branch).

**Sub-step 2b — hang-off-check via fresh-context subagent (P346 Phase 3; ADR-032 5th invocation pattern)**

The 3-keyword title-only grep at sub-step 2a is conservative: it catches narrow shape-overlap on titles but misses the wider class of hang-off candidates — parent tickets where the new capture's scope belongs as an Investigation Tasks expansion / Phase N section rather than as a sibling ticket. The wrongly-captured P347 sibling of P346 on 2026-05-31 is the canonical regression: the main agent (mid-iter, with rich session context) pattern-matched the existing capture flow and missed that the new spec belonged inside P346 as Phase 3.

Sub-step 2b adds a **mechanical pre-filter + fresh-context subagent dispatch** that closes this gap without re-introducing the main agent's session-context bias. The subagent runs in isolation (no parent-session context) and emits a structured verdict the SKILL acts on deterministically.

**Mechanical pre-filter** — grep `docs/problems/open/*.md` + `docs/problems/verifying/*.md` BODIES for tokens shared with the description: any `ADR-NNN` reference, `RFC-NNN` reference, `JTBD-NNN` reference, SKILL path (`/wr-<plugin>:<skill>` or `packages/<plugin>/skills/<skill>/`), file path (`packages/...`, `docs/...`, `.github/...`, `bin/...`, `scripts/...`), or named feature word the description cites. Collect candidates that share **≥1** signal.

```bash
# Extract candidate signals from the description (post-flag-strip).
adr_refs=$(echo "$description" | grep -oE 'ADR-[0-9]{3}' | sort -u)
rfc_refs=$(echo "$description" | grep -oE 'RFC-[0-9]{3}' | sort -u)
skill_refs=$(echo "$description" | grep -oE '/wr-[a-z-]+:[a-z-]+' | sort -u)
file_refs=$(echo "$description" | grep -oE '(packages|docs|\.github|bin|scripts)/[a-zA-Z0-9_./-]+' | sort -u)
signals="$adr_refs"$'\n'"$rfc_refs"$'\n'"$skill_refs"$'\n'"$file_refs"
signals=$(echo "$signals" | grep -v '^$' | sort -u)

# If no signals extractable from description, skip the dispatch entirely
# (the title-only grep at 2a is the only duplicate check this capture gets).
[ -z "$signals" ] && SKIP_HANG_OFF_CHECK=1

# Otherwise: pre-filter candidates from open/ + verifying/ that share ≥1 signal.
candidates=()
if [ -z "$SKIP_HANG_OFF_CHECK" ]; then
  for f in docs/problems/open/*.md docs/problems/verifying/*.md; do
    [ -f "$f" ] || continue
    for sig in $signals; do
      if grep -qF "$sig" "$f"; then
        candidates+=("$f")
        break
      fi
    done
  done
fi
```

**Candidate-cap short-circuit (latency-bound per ADR-032 + JTBD-001's 60s flow budget)**: if `${#candidates[@]} -gt 5`, **skip the subagent dispatch** and record the candidate list in the captured ticket's `## Related` section for review-time re-evaluation by `/wr-itil:review-problems`. Wide candidate sets blow the lightweight-capture latency budget; the safe default is "skip + defer to cluster pass."

**Empty-candidates short-circuit**: if `${#candidates[@]} -eq 0` (no shared signals), skip the dispatch and proceed to the marker step. The mechanical pre-filter found nothing to arbitrate.

**JTBD-301 firewall** — sub-step 2b fires on maintainer-side `/wr-itil:capture-problem` invocations ONLY. Plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` MUST NOT carry an equivalent dispatch (plugin-user descriptions do not carry the same authorial intent; a plugin-user describing their friction in maintainer vocabulary could plausibly trigger a wrong-parent HANG_OFF). Triage during `/wr-itil:manage-problem` ingestion stays user-judgement per JTBD-301. Mirrors the Step 1.5b JTBD-trace firewall above.

**AFK safe-default**: the hang-off-check subagent verdict is non-interactive by construction (no `AskUserQuestion`), and ambiguous-multi-parent cases collapse to `PROCEED_NEW` per the subagent's Rule 6 contract. This satisfies JTBD-006's "Decisions normally requiring my input are resolved using safe defaults" without dependency on the retired `--no-prompt` flag.

**Dispatch** — when the candidate set is non-empty and ≤5, delegate to `wr-itil:hang-off-check` via the Agent tool with a structured input payload:

```
SURFACE: capture-problem-step-2b

<new-capture>
<description verbatim, post-flag-strip>
</new-capture>

<candidates>
P<NNN1> | <title1> | <path1> | shared-signals: <signal1, signal2, ...>
P<NNN2> | <title2> | <path2> | shared-signals: <signal1, signal3, ...>
...
</candidates>
```

The subagent reads the candidate ticket bodies in full as needed (via its own Read tool), reasons about absorb-vs-proceed, and returns one of:

- `HANG_OFF: P<NNN>` with **Rationale**, **Signals matched**, **Where to absorb** sections.
- `PROCEED_NEW` with **Rationale** and **Per-candidate explanation** for each surfaced candidate.

**Act on verdict:**

- **HANG_OFF: P<NNN>**: **halt** capture-problem. Emit a structured halt directive to the calling orchestrator agent naming (a) the parent ticket file path, (b) the new scope to amend in, (c) the `Where to absorb` directive from the subagent verdict. The orchestrator agent owns the parent-ticket edit + commit per the standard ticket-edit flow (do NOT amend the parent ticket from inside capture-problem — capture-problem creates new tickets; ticket-body amendments are manage-problem's surface). Record the hang-off decision + rationale in stderr for the audit trail.

- **PROCEED_NEW**: continue to the marker step below. Capture the subagent's rationale + per-candidate explanation in a transient note (stderr) and append it to the new ticket's `## Related` section so the next reviewer sees what was considered. This is the audit-trail contract per ADR-026 grounding + JTBD-201 audit-trail completeness.

**After the grep + (optional) hang-off-check completes**, write the per-session create-gate marker so the `PreToolUse:Write` hook (P119) permits the subsequent Write of the new ticket file under `docs/problems/open/`. Per **P260 / ADR-050 Option C**, write it under EVERY recent candidate session SID (not just one) so a concurrent orchestrator+subprocess race cannot land the marker under the wrong UUID:

```bash
wr-itil-mark-create-gate
```

`wr-itil-mark-create-gate` is the ADR-049 `$PATH` shim that internalises the former inline `source packages/itil/hooks/lib/{session-id,create-gate}.sh` + `get_candidate_session_ids | mark_step2_complete_candidates`. It resolves those `hooks/lib` siblings RELATIVE TO THE SCRIPT, not cwd (P317/RFC-009) — so it works in adopter installs. NEVER `source packages/...` repo-relative from a SKILL; those paths only resolve in the source monorepo, not where the plugin is installed.

The marker is shared between `manage-problem` and `capture-problem` per ADR-032 amendment — same `/tmp/manage-problem-grep-${SESSION_ID}` path, idempotent across cross-skill ordering. Internally the command enumerates the `get_current_session_id` pick (P124) plus every recent `/tmp/<system>-announced-<UUID>` UUID within a 24h mtime window, and writes the marker under each — so whichever SID the hook reads from the Write's stdin, a matching marker exists. This closes the P260 create-gate race that fires when the orchestrator main turn captures a ticket while a backgrounded iter subprocess holds the per-machine runtime-sid marker (last-writer-wins). The candidate set is bounded to recent same-machine markers — not a global fail-open (the P119 audit invariant holds: each marker still records that THIS session ran the duplicate-check grep). See `/wr-itil:manage-problem` Step 2 substep 7 for the full mechanism.

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

**File path**: `docs/problems/open/<NNN>-<kebab-title>.md` (per ADR-031 per-state-subdir layout)

**Template** (deferred-placeholder pattern — flag every section the capture didn't fill):

```markdown
# Problem <NNN>: <Title>

**Status**: Open
**Reported**: <YYYY-MM-DD>
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**JTBD**: <jtbd_trace_value_as_comma_separated_list_OR_omit_line_when_empty>
**Persona**: <persona_value_OR_omit_line_when_empty>

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

Single `Write` to `docs/problems/open/<NNN>-<kebab-title>.md` (per ADR-031 per-state-subdir layout). The P119 PreToolUse hook permits the Write because Step 2 set the marker.

### 6. Commit per ADR-014 — single commit, no README refresh

**Stage list**: ONLY the new ticket file. **Do NOT** stage `docs/problems/README.md`. The deferred-README-refresh contract is the load-bearing distinction from `/wr-itil:manage-problem` — capture-time speed depends on skipping the regenerate-and-stage cycle.

```bash
git add docs/problems/open/<NNN>-<kebab-title>.md
```

Satisfy the commit gate per ADR-014 — same two-path pattern as manage-problem Step 11:

- **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
- **Fallback**: invoke `/wr-risk-scorer:assess-release` via the Skill tool when the subagent type is unavailable in the current tool surface.

Commit message — the body MUST carry the `RISK_BYPASS: capture-deferred-readme` trailer:

```
docs(problems): capture P<NNN> <title>

RISK_BYPASS: capture-deferred-readme
```

The `capture` verb in the message is the audit signal that this ticket landed via the lightweight aside path (vs. `open` for manage-problem's full intake).

**Why the trailer (P262)**: the P165 README-refresh-discipline hook (`packages/itil/hooks/itil-readme-refresh-discipline.sh`) treats any newly-staged ticket file as ranking-bearing and DENIES a `git commit` that does not also stage `docs/problems/README.md`. That enforcement is correct for `/wr-itil:manage-problem`'s full-intake path (P094 refresh-on-create) but conflicts with this skill's deliberate deferred-README-refresh contract. The `RISK_BYPASS: capture-deferred-readme` trailer is a registered allow-list token (P265 mechanism; registry of record is the ADR-014 commit-message bypass-token table) that clears the **README-refresh gate ONLY** — the commit is still risk-scored normally (`risk-score-commit-gate.sh` does not recognise this token). Emit the trailer via a second `-m` paragraph so the literal token appears in the `git commit` command string the PreToolUse hook inspects:

```bash
git commit -m "docs(problems): capture P<NNN> <title>" -m "RISK_BYPASS: capture-deferred-readme"
```

Do NOT drop the trailer and stage the README instead — that would silently abandon the deferred-README-refresh contract (the capture-time-speed distinction this skill exists to provide per ADR-032). The README is reconciled at the next `/wr-itil:review-problems` per Step 7's trailing pointer.

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
| Skeleton-fill | Full-intake; AskUserQuestion for missing fields | Deferred-placeholder pattern; no classification AskUserQuestion (P287 retired the type prompt) |
| Type-tag prompt | RETIRED (P287, 2026-06-02) | RETIRED (P287, 2026-06-02) — the technical/user-business axis was removed as redundant with RFC/Story persona-anchoring per ADR-060 Phase 4 |
| JTBD-trace + persona | Step 4-equivalent ingestion path | Step 1.5b derive-first dispatch — lexical citations + `--jtbd=` flag pre-resolve silently; persona derives from cited JTBDs' frontmatter; persona-disagreement AskUserQuestion is the only taste fallback |
| AskUserQuestion authority | Multiple branches (deviation-approval / direction-setting / taste / mechanical) | Zero unconditional AskUserQuestion fires; persona-disagreement fallback only (silent-framework per ADR-044 cat. 4 by default; cat. 5 taste on JTBD-persona disagreement); zero control-flow branches |
| README refresh | P094 inline (regenerate + stage in same commit) | Deferred to next `/wr-itil:review-problems` |
| Status transitions | Step 7 owns Open → Known Error → Verifying → Closed | Out of scope (creation only) |
| Commit grain | One commit per intake (or per split-concern set) | One commit per capture |
| Use case | Full-intake new problem; user wants to walk the flow | Aside-invocation; capture-and-continue |

The two skills share the `/tmp/manage-problem-grep-${SESSION_ID}` create-gate marker per P119 — calling either skill's Step 2 grep + mark sequence permits new ticket Writes for the rest of the session, regardless of which skill landed first.

## Related

- **P155** (`docs/problems/closed/155-ship-capture-problem-skill.md`) — driver ticket.
- **P014** (`docs/problems/open/014-aside-invocation-for-governance-skills.md`) — parent / master tracker.
- **P078** — capture-on-correction OFFER pattern; depends on capture-problem shipping.
- **P119** — manage-problem create-gate hook; capture-problem composes with the same marker.
- **P262** — the P165 README-refresh-discipline hook conflicted with this skill's deferred-README-refresh contract (Step 6 "do NOT stage README" was denied by the hook on every capture commit). Resolved by the `RISK_BYPASS: capture-deferred-readme` allow-list token (Step 6 trailer above); clears the README-refresh gate only, not the risk-score gate.
- **P265** — the RISK_BYPASS-trailer allow-list mechanism in `readme-refresh-detect.sh` that P262's `capture-deferred-readme` token registers into.
- **P170** (`docs/problems/known-error/170-problem-tickets-strain-as-fixes-decompose-into-multiple-coordinated-changes-need-rfc-framework.md`) — RFC framework driver; Slice 4 B7.T3 / item 8c historically authored the type-classification prompt at Step 1.5 (RETIRED by P287, 2026-06-02).
- **P176** — agent-side I2 (no type-branching) coverage gap on the SKILL.md surface. P287 retires the type axis altogether; the regression guard is preserved under `packages/itil/scripts/test/no-type-regression-guard.bats` (asserting the `**Type**:` field is GONE from skeleton templates).
- **P287** (`docs/problems/.../287-remove-technical-user-business-type-classification-from-problems-redundant-with-rfc-persona-anchoring.md`) — the user direction (twice-confirmed 2026-05-25 + 2026-06-02) that retired Step 1.5 Type classification; ADR-060 amendment substance (I12 replacement, Phase-4 rework) queued for user re-confirmation per ADR-074.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — foreground-lightweight-capture variant amendment (P155); 5th invocation pattern amendment (P346 Phase 3, 2026-05-31) codifies the hang-off-check sub-step 2b dispatch as the canonical fresh-context-subagent-as-decision-arbiter shape.
- **P346** (`docs/problems/.../346-...md`) — backlog-flow-control master ticket; Phase 3 deliverable lands the hang-off-check dispatch at sub-step 2b above.
- **RFC-013** (`docs/rfcs/RFC-013-...proposed.md`) — traces P346 Phases 1+2+3 per ADR-071 unconditional Problem→RFC trace.
- **`packages/itil/agents/hang-off-check.md`** — the fresh-context subagent invoked by sub-step 2b; reads only the structured input payload; emits HANG_OFF: P<NNN> or PROCEED_NEW with rationale + signals + absorb directive.
- **ADR-038** — progressive-disclosure pattern (SKILL.md + REFERENCE.md split).
- **ADR-044** — decision-delegation contract. Persona derivation (Step 1.5b) is **derive-first**: silent-framework per category 4 when cited JTBDs agree on persona; taste per category 5 fallback only on cited-JTBD-persona disagreement. JTBD-trace itself is purely category 4 (lexical detection or `--jtbd=` flag pre-resolution). The retired Step 1.5 Type classification was a derive-first dispatch too (RETIRED by P287, 2026-06-02).
- **P185** — `/wr-itil:capture-problem` historical: asked a classification question (type) it could answer itself; the Step 1.5 derive-first refactor (lexical-signal classifier + stderr advisory) shipped the fix in 2026-05-15. P287 then retired the entire surface in 2026-06-02 as the classification axis itself was redundant with RFC/Story persona-anchoring.
- **ADR-049** — bin/ on PATH; capture-problem reuses the existing `wr-itil-reconcile-readme` shim.
- **ADR-052** — behavioural-tests-default for skill testing; SKILL.md I2 surface coverage gap is named, not silent (P176 + ADR-052 § Surface 2).
- **ADR-060** (`docs/decisions/060-...accepted.md`) — body currently encodes the type-tag schema (Decision Outcome item 1, I2 type-uniformity, I12 hard-block, Phase-4 persona+jtbd machinery keyed on `type:user-business`). P287 retires the SKILL implementation of these clauses unilaterally per twice-confirmed user direction; the ADR body amendment substance (I12 replacement shape, Phase-4 rework) is queued for user re-confirmation per ADR-074. Until the amendment lands, ADR-060 body and SKILL implementation are intentionally inconsistent — this is the P287 trade-off the user accepted.
- **JTBD-301** (`docs/jtbd/plugin-user/JTBD-301-...md`) — plugin-user no-pre-classification persona constraint; the Step 1.5b maintainer-side scope guard preserves the firewall on the JTBD-trace + persona axis. The type-axis firewall is moot (axis retired).
- `packages/itil/skills/manage-problem/SKILL.md` — heavyweight intake counterpart.
- `packages/itil/skills/review-problems/SKILL.md` — re-rates the deferred placeholders + refreshes README.md.
- `packages/itil/scripts/test/no-type-regression-guard.bats` — pure-bash regression guard that the `**Type**:` field stays GONE from skeleton templates + ticket bodies. Replaces the historical `i2-no-type-branching.bats` (which asserted no-control-flow-branch-on-type; with the type axis retired, the branch-protection invariant is vacuous, but the field-absence regression guard preserves the audit trail per architect-review verdict 2026-06-02).

$ARGUMENTS
