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

This skill has **at most one classification-only AskUserQuestion (type-tag, ambiguous-signal fallback only) and zero control-flow branches keyed on the answer**. Each potentially-interactive decision is framework-mediated per ADR-044:

| Decision | Resolution |
|----------|-----------|
| Duplicate-check | Mechanical 3-keyword title-only grep; matches listed in report; capture proceeds regardless. False-positives are cheaper than false-negatives (P155 line 24). |
| Priority default | Framework-policy: `3 (Medium) — Impact 3 × Likelihood 1` flagged "deferred — re-rate at next /wr-itil:review-problems". |
| Effort default | Framework-policy: `M` flagged "deferred — re-rate at next /wr-itil:review-problems". |
| Multi-concern split | Out of scope: capture-problem creates one ticket per invocation. Multi-concern observations route to `/wr-itil:manage-problem` (its Step 4b owns the split). |
| Empty `$ARGUMENTS` | Halt-with-stderr-directive: print "capture-problem requires a description in $ARGUMENTS — invoke /wr-itil:manage-problem instead for the full intake flow" and exit. AFK orchestrators MUST NOT invoke capture-problem with empty arguments — caller-side contract. |
| Type classification (P170 / ADR-060 item 8c; P185 derive-first refactor) | **Derive-first; silent-framework per ADR-044 category 4 on unambiguous-signal descriptions; taste fallback per category 5 on ambiguous descriptions only.** Step 1.5 runs a lexical-signal classifier against the description text. Unambiguous one-sided signal → classify silently + emit stderr advisory. Mixed or zero signals → AskUserQuestion. `--type=<value>` pre-resolves silently (highest priority). `--no-prompt` defaults to `technical` silently (AFK contract). Maintainer-side ONLY: this dispatch is paired with JTBD-301 protection — `.github/ISSUE_TEMPLATE/problem-report.yml` (plugin-user-side intake) MUST NOT carry an equivalent type selector; triage assigns the type during `/wr-itil:manage-problem` ingestion of user-reported issues. **The classifier is also NOT invoked from `/wr-itil:manage-problem`'s ingestion-of-plugin-user-reports path** — plugin-user descriptions do not carry the same authorial intent as maintainer-internal captures, so triage stays user-judgement per JTBD-301. **I2 invariant** (ADR-060 line 98): the prompt is a classification facet, not a workflow split — Steps 0-7 control-flow is identical regardless of the chosen `type_value`; only the substituted value in the Step 4 skeleton template differs. The stderr advisory text shape is also I2-isomorphic: identical sentence structure across `technical` vs `user-business` classifications beyond the substituted values + signal names. |

Per ADR-013 Rule 6 fail-safe: every decision above resolves without interactive user input in non-interactive contexts (the type-tag carve-out resolves to `technical` via `--no-prompt` or `--type=` caller-side pre-resolution, or via the derive-first classifier on unambiguous descriptions). AFK orchestrators MUST pass `--no-prompt` or `--type=<value>` per JTBD-006 § Persona Constraints; AFK callers that omit both flags violate the caller-side contract. Interactive (pre-resolved, derive-classified, or ambiguous-fallback) and pre-resolved AFK paths produce identical observable outputs except for the `**Type**:` field value, satisfying the I2 invariant by construction.

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
| `--type=technical` | Pre-resolves type to `technical`; Step 1.5 skips the classifier and the AskUserQuestion. |
| `--type=user-business` | Pre-resolves type to `user-business`; Step 1.5 skips the classifier and the AskUserQuestion. |
| `--no-prompt` | Pre-resolves type to `technical` (default); Step 1.5 skips the classifier and the AskUserQuestion. |
| `--jtbd=JTBD-NNN[,JTBD-NNN...]` | Pre-resolves the JTBD-trace value (Phase 4 P3.1 + I12 invariant per ADR-060 § Phase 3 + Phase 4 in-scope amendment 2026-05-13). Step 1.5b skips the JTBD-trace lexical dispatch and the I12 hard-block. Comma-separated list of JTBD IDs (no spaces). |
| `--persona=<value>` | Pre-resolves the persona value (Phase 4 P4.2). Step 1.5b skips persona derivation. Value MUST be one of: `solo-developer`, `tech-lead`, `plugin-developer`, `plugin-user`. |

Strip recognised leading flags from `$ARGUMENTS`; the remainder (after flags) is the free-text description. If both `--type=<value>` and `--no-prompt` are present, `--type=<value>` wins (more specific). Unknown leading flags halt-with-stderr-directive: print "capture-problem: unknown flag '<flag>' — recognised flags: --type=technical, --type=user-business, --no-prompt, --jtbd=JTBD-NNN, --persona=<value>" and exit.

Empty description (post-flag-strip) halts per the Rule 6 audit above.

Derive a kebab-case title slug from the first 8-10 non-stopword tokens of the description (matching the existing `manage-problem` slug derivation pattern).

### 1.5 Type classification (derive-first; silent-framework per ADR-044 category 4; taste fallback per category 5 on ambiguity)

**Shared dispatch helper**: this surface invokes `packages/itil/lib/derive-first-dispatch.sh` for the canonical lexical-classifier mechanism + I2-isomorphic stderr advisory format. The helper is sourced by `/wr-itil:capture-problem`, `/wr-itil:manage-incident`, and `/wr-itil:manage-problem`; drift in the advisory shape re-opens P132. Surface-specific signal definitions (technical-vs-user-business regex lists) stay inline below — the helper owns the mechanism, not the per-surface signals (architect verdict 2026-05-15 P132 Phase 2a-iii-A: "Helper must preserve per-surface signal definitions; only the dispatch mechanism is shared").

Resolve `type_value` ∈ {`technical`, `user-business`} per the following framework-mediated dispatch. **The dispatch order is load-bearing** — pre-resolution flags short-circuit BEFORE the classifier runs, and the AskUserQuestion fires ONLY on genuinely-ambiguous descriptions.

1. **If `--type=<value>` was set in Step 1**: use that value; do NOT run the classifier; do NOT fire AskUserQuestion (silent-proceed per ADR-013 Rule 5).
2. **Else if `--no-prompt` was set in Step 1**: default `type_value = technical`; do NOT run the classifier; do NOT fire AskUserQuestion. JTBD-006 protection: AFK orchestrators MUST pass this flag (or `--type=<value>`).
3. **Else** (interactive context, no caller-side pre-resolution): run the **lexical-signal classifier** against the description text:

   **Technical signals** (regex; matched against the post-flag-strip description, case-insensitive unless noted):
   - Code identifiers: `[a-z]+[A-Z][a-zA-Z]+` (camelCase), `[a-z]+-[a-z][a-z-]+` (kebab-case identifiers with ≥2 hyphens), `[a-z]+_[a-z][a-z_]+` (snake_case).
   - File paths: `\.(md|sh|bats|ts|js|json|yaml|yml|py|rb|go|css|html)\b`, `packages/[a-z-]+/`, `docs/[a-z-]+/`, `\.github/`, `\.claude/`, `/tmp/`.
   - Command-name patterns: `/wr-[a-z-]+:[a-z-]+\b`, `\bgit (commit|push|mv|add|rebase|merge)\b`, `\bnpm (run|install|publish)\b`, `\bbash\b`, `\bbats\b`, `\bgrep\b`, `\bsed\b`, `\bjq\b`.
   - Mechanism words: `\b(drift|regression|hook|marker|gate|refresh|idempotent|exit code|stderr|stdout|regex|formula|dispatch|frontmatter|substring|escape|sentinel|bypass|TTL|cache|invalidate|deduplicate|race|deadlock|timeout|preflight)\b`.
   - Error-message patterns: `\b(error|failure|exception|panic|stack trace|segfault|null pointer|undefined|not found|permission denied|EACCES|ENOENT|exit \d+)\b`.

   **User-business signals** (regex; same casing):
   - Persona names: `\b(adopter|adopters|plugin-user|plugin-users|solo[-_ ]?developer|maintainer-persona|end[-_ ]?user|customer|stakeholder)\b`.
   - Journey words: `\b(workflow|journey|onboarding|friction|UX|experience|usability|discoverability|cognitive load|attention|interrupt|context-switch)\b`.
   - JTBD-shaped need words: `\bJTBD-\d+\b`, `\bjob-to-be-done\b`, `\b(want|need|can't|cannot|blocked from|unable to|hard to|painful to)\b\s+(use|access|find|discover|complete)`, `\bdesired outcome\b`, `\bunmet need\b`.

   **Decision rule**:

   - **Unambiguous technical** (≥1 technical signal AND 0 user-business signals): set `type_value = technical`; emit stderr advisory and proceed. Do NOT fire AskUserQuestion.
   - **Unambiguous user-business** (0 technical signals AND ≥1 user-business signal): set `type_value = user-business`; emit stderr advisory and proceed. Do NOT fire AskUserQuestion.
   - **Ambiguous** (≥1 signal each side, OR 0 signals on both sides): fire AskUserQuestion with options `technical` (default) and `user-business`. Question text: *"What type of problem is this?"* Per-option descriptions:
     - `technical` — *"Bug, defect, broken behaviour, framework drift — root cause sits in code or process."*
     - `user-business` — *"Missing capability, UX gap, adopter friction, JTBD-shaped need — root cause sits in unmet user need."*

   **Stderr advisory contract** (silent-classification path only): emit a SINGLE line to stderr (NOT stdout, NOT in the ticket body) via the shared helper's `emit_stderr_advisory` function in `packages/itil/lib/derive-first-dispatch.sh`. The canonical format produced by the helper:

   ```
   capture-problem: derived type=<value> from description signals: <signal1>, <signal2>[, ...]; re-invoke with --type=<other-value> to override
   ```

   The advisory text shape is I2-isomorphic — same sentence structure (`<skill>: derived <field>=<value> from <source>; <reversibility>`) across all three derive-first declaration-skill surfaces. The helper is the single source-of-truth for this format; drift here re-opens P132. Embedding the advisory in stdout would risk machine-readers parsing it as a ticket-body line; embedding it in the ticket body would violate ADR-060's frontmatter / body-bullet schema. Stderr is the correct channel — visible to interactive maintainers in the terminal; invisible to ticket consumers; loggable by AFK orchestrators that capture subprocess stderr.

**I2 invariant guard (ADR-060 line 98)**: the resolved `type_value` is used at Step 4 ONLY as a substituted string in the skeleton template's `**Type**:` body field. Steps 2, 3, 4 (other than the `**Type**:` substitution), 5, 6, 7 execute identically regardless of `type_value`. The skill carries NO control-flow branch keyed on `type` — that would convert classification into a workflow split and violate I2. The lexical-signal classifier is UPSTREAM of the value's substitution (it resolves WHICH value to substitute, not WHICH workflow to execute); the substitution and all downstream steps remain uniform. Pure-bash supporting-script enforcement of this invariant lives in `packages/itil/scripts/test/i2-no-type-branching.bats`; the SKILL.md surface coverage gap is named at P176 (descendant of P012 master harness).

**JTBD-301 scope guard**: this dispatch fires on the maintainer-side `/wr-itil:capture-problem` skill only. The plugin-user-side intake (`.github/ISSUE_TEMPLATE/problem-report.yml`) MUST NOT carry an equivalent type selector — plugin-user persona constraint is "no pre-classification". Triage assigns `type` during `/wr-itil:manage-problem` ingestion of user-reported issues, not at user-report time. **The lexical-signal classifier is ALSO NOT invoked from `/wr-itil:manage-problem`'s ingestion-of-plugin-user-reports path** — plugin-user descriptions do not carry the same authorial intent as maintainer-internal captures (a plugin-user describing their friction in maintainer-vocabulary terms would mis-classify); triage stays user-judgement, not lexical-classifier inference.

### 1.5b JTBD-trace + persona dispatch (Phase 3 P3.1 + Phase 4 P4.2 + I12 invariant)

Per ADR-060 § Phase 3 + Phase 4 in-scope amendment (2026-05-13). Fires ONLY when `type_value` resolved to `user-business` (whether via `--type=user-business` flag, `--no-prompt` default override is impossible since `--no-prompt` defaults to `technical`, the classifier silent-resolve to `user-business`, or the ambiguous-fallback AskUserQuestion). For `type_value = technical`, Steps 1.5b and the I12 hard-block do NOT fire (technical problems may carry empty `jtbd:` array; persona is optional). The whole dispatch keys on **nullable-field-conditional** shape per ADR-060 line 536 — NEVER on `type` value as a control-flow branch (preserves I2 invariant; the type co-incidence is upstream input, not control-flow key).

**Resolve `jtbd_trace_value`** (an ORDERED list of JTBD IDs, possibly empty) via the following dispatch:

1. **If `--jtbd=JTBD-NNN[,JTBD-NNN...]` was set in Step 1**: parse comma-separated list; assign to `jtbd_trace_value`; do NOT run the lexical detector; do NOT fire AskUserQuestion (silent-proceed per ADR-013 Rule 5).
2. **Else** run the **lexical JTBD-trace detector** against the description: `grep -oE '\bJTBD-[0-9]+\b' | sort -u`. If matches found, set `jtbd_trace_value` to the matched IDs (de-duplicated, sorted ascending) and emit stderr advisory: `capture-problem: derived jtbd-trace=<id-list> from description JTBD-NNN citations; re-invoke with --jtbd= to override`. Do NOT fire AskUserQuestion.
3. **Else (no flag, no lexical detection, type=user-business)**: **I12 hard-block** per ADR-060 Confirmation criterion 10. Halt-with-stderr-directive: print `capture-problem: I12 invariant — type: user-business requires ≥1 JTBD trace. Re-invoke with --jtbd=JTBD-NNN, OR edit the description to cite a JTBD-NNN ID, OR re-classify as technical via --type=technical.` and exit. This branch is the load-bearing enforcement of the new I12 invariant — JTBD-as-source-of-truth for persona-anchored unmet need; user-business problems MUST cite ≥1 JTBD.

**Resolve `persona_value`** (a scalar enum value OR empty) via the following dispatch:

1. **If `--persona=<value>` was set in Step 1**: validate `<value>` ∈ `{solo-developer, tech-lead, plugin-developer, plugin-user}`; halt with directive if invalid; otherwise assign and proceed silently.
2. **Else if `jtbd_trace_value` is non-empty**: derive persona from cited JTBDs' frontmatter. Read each cited `docs/jtbd/<persona>/JTBD-<NNN>-*.md` file; extract its `persona:` (and optionally `secondary-persona:`) frontmatter values; if all cited JTBDs agree on a single persona, set `persona_value` to that persona silently and emit stderr advisory: `capture-problem: derived persona=<value> from cited JTBD <id> frontmatter`. If cited JTBDs disagree, fire AskUserQuestion with the union-of-derived-personas as options.
3. **Else if `type_value = user-business`**: AskUserQuestion fires with the closed enum as options. Per ADR-060 P4.2: `solo-developer | tech-lead | plugin-developer | plugin-user`. Question text: *"What persona does this user-business problem serve?"*
4. **Else (`type_value = technical`)**: leave `persona_value` empty. `persona:` frontmatter is OPTIONAL on technical problems.

**I12 hard-block escape hatch (none)**: there is no `BYPASS_I12=1` env override at the SKILL surface. The block is a load-bearing schema constraint per ADR-060 Confirmation criterion 10; if a maintainer captures a user-business problem without yet knowing the JTBD trace, they must EITHER capture as `--type=technical` and re-classify during `/wr-itil:manage-problem` ingestion (when the JTBD becomes clear), OR fast-capture a placeholder JTBD via `/wr-itil:capture-jtbd` (when it ships under Phase 4 follow-on) and reference it.

**JTBD-301 scope preservation**: this dispatch ALSO fires on the maintainer-side `/wr-itil:capture-problem` only. Plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` MUST NOT prompt for JTBD trace or persona — preserves the JTBD-301 firewall per ADR-060 P4.3 maintainer-side / plugin-user-side asymmetry clarifier. Triage during `/wr-itil:manage-problem` ingestion assigns both fields from the reporter's symptom signals (per the JTBD-301 maintainer-side-complement extension landed 2026-05-13).

**Phase 3 P3.1 nullable-field-conditional shape**: the JTBD-trace prompt + I12 hard-block fire on `jtbd_trace_value` nullability (absent vs present), NOT on the `type` field's value. The composite gate (`type == user-business AND jtbd_trace_value == empty`) treats `type` as upstream-determined co-incident input — exactly the carve-out permitted by ADR-060 line 536. Steps 2-7 below execute identically regardless of `type_value`, `jtbd_trace_value`, or `persona_value`; only the values substituted into the Step 4 skeleton template differ. This preserves I2 control-flow uniformity AND extends the I2 behavioural test (per ADR-060 Confirmation criterion 11) to assert no control-flow branch on `persona:` field presence.

### 2. Minimal-grep duplicate check (3-keyword title-only)

Extract up to **3 distinct kebab-cased non-stopword keywords** from the description. Grep the **filenames** of `docs/problems/*.md` AND `docs/problems/<state>/*.md` (NOT bodies — title-only is the conservative threshold per architect verdict on Q1; dual-tolerant per RFC-002 migration window):

```bash
match_count=$(ls docs/problems/*.md docs/problems/*/*.md 2>/dev/null \
              | grep -ciE 'kw1|kw2|kw3' || true)
```

The **3-keyword cap** is a hard-coded constant. Do NOT make it env-overridable — the conservative threshold rationale (P155 line 24) is structural to the design, not a tunable knob.

**Title-only**: file bodies are intentionally NOT scanned. Body-content matches would either (a) over-prompt (capture-problem has no AskUserQuestion to surface them) or (b) get silently swallowed. Title-only matches preserve the conservative-threshold contract.

If matches are found: list them in the final report. **Do NOT halt or branch.** Capture proceeds. The user can resolve duplicates at the next `/wr-itil:review-problems` invocation (or invoke `/wr-itil:manage-problem` directly if the duplicate-check shape needs a structured branch).

**After the grep completes**, write the per-session create-gate marker so the `PreToolUse:Write` hook (P119) permits the subsequent Write of the new `.open.md` file. Per **P260 / ADR-050 Option C**, write it under EVERY recent candidate session SID (not just one) so a concurrent orchestrator+subprocess race cannot land the marker under the wrong UUID:

```bash
source packages/itil/hooks/lib/session-id.sh
source packages/itil/hooks/lib/create-gate.sh
get_candidate_session_ids | mark_step2_complete_candidates
```

The marker is shared between `manage-problem` and `capture-problem` per ADR-032 amendment — same `/tmp/manage-problem-grep-${SESSION_ID}` path, idempotent across cross-skill ordering. `get_candidate_session_ids` enumerates the `get_current_session_id` pick (P124) plus every recent `/tmp/<system>-announced-<UUID>` UUID within a 24h mtime window, and `mark_step2_complete_candidates` writes the marker under each — so whichever SID the hook reads from the Write's stdin, a matching marker exists. This closes the P260 create-gate race that fires when the orchestrator main turn captures a ticket while a backgrounded iter subprocess holds the per-machine runtime-sid marker (last-writer-wins). The candidate set is bounded to recent same-machine markers — not a global fail-open (the P119 audit invariant holds: each marker still records that THIS session ran the duplicate-check grep). See `/wr-itil:manage-problem` Step 2 substep 7 for the full mechanism.

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

Single `Write` to `docs/problems/<NNN>-<kebab-title>.open.md`. The P119 PreToolUse hook permits the Write because Step 2 set the marker.

### 6. Commit per ADR-014 — single commit, no README refresh

**Stage list**: ONLY the new ticket file. **Do NOT** stage `docs/problems/README.md`. The deferred-README-refresh contract is the load-bearing distinction from `/wr-itil:manage-problem` — capture-time speed depends on skipping the regenerate-and-stage cycle.

```bash
git add docs/problems/<NNN>-<kebab-title>.open.md
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
| Skeleton-fill | Full-intake; AskUserQuestion for missing fields | Deferred-placeholder pattern + derive-first type classification (AskUserQuestion fires only on ambiguous descriptions) |
| Type-tag prompt | Step 4-equivalent AskUserQuestion fires alongside other intake fields | Step 1.5 derive-first dispatch — lexical-signal classifier silently resolves unambiguous descriptions (with stderr advisory); ambiguous descriptions fall back to classification-only AskUserQuestion. `--type=` and `--no-prompt` flags pre-resolve for non-interactive callers. I2 invariant: no control-flow branch keyed on type |
| AskUserQuestion authority | Multiple branches (deviation-approval / direction-setting / taste / mechanical) | Zero unconditional AskUserQuestion fires; ambiguous-signal fallback only (silent-framework per ADR-044 cat. 4 on unambiguous; taste per cat. 5 on ambiguous); zero control-flow branches |
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
- **P262** — the P165 README-refresh-discipline hook conflicted with this skill's deferred-README-refresh contract (Step 6 "do NOT stage README" was denied by the hook on every capture commit). Resolved by the `RISK_BYPASS: capture-deferred-readme` allow-list token (Step 6 trailer above); clears the README-refresh gate only, not the risk-score gate.
- **P265** — the RISK_BYPASS-trailer allow-list mechanism in `readme-refresh-detect.sh` that P262's `capture-deferred-readme` token registers into.
- **P170** (`docs/problems/170-...open.md`) — RFC framework driver; Slice 4 B7.T3 / item 8c authored the type-classification prompt at Step 1.5.
- **P176** — agent-side I2 (no type-branching) coverage gap on the SKILL.md surface (this file's surface); descendant of P012 master harness ticket. The Step 1.5 I2 invariant guard is enforced by audit-trailed prose here per ADR-052 § Surface 2 escape-hatch contract; behavioural enforcement awaits the master harness.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — foreground-lightweight-capture variant amendment.
- **ADR-038** — progressive-disclosure pattern (SKILL.md + REFERENCE.md split).
- **ADR-044** — decision-delegation contract; type classification is **derive-first**: silent-framework per category 4 on unambiguous-signal descriptions (the classifier IS the framework resolving the answer from observable evidence per ADR-026 grounding); taste per category 5 fallback on genuinely-ambiguous descriptions only. `--no-prompt` / `--type=<value>` are policy-authorised silent-proceed shapes per category 4 (caller-side pre-resolution). P185 re-classified Step 1.5's taxonomy position from "cat 5 unconditional ask" to "cat 4 derive-first with cat 5 fallback".
- **P185** — `/wr-itil:capture-problem` asks a classification question it can answer itself from the description's observable evidence — inverse-P078 / P132 trap at a SKILL contract surface. The Step 1.5 derive-first refactor (lexical-signal classifier + stderr advisory) ships this fix.
- **ADR-049** — bin/ on PATH; capture-problem reuses the existing `wr-itil-reconcile-readme` shim.
- **ADR-052** — behavioural-tests-default for skill testing; SKILL.md I2 surface coverage gap is named, not silent (P176 + ADR-052 § Surface 2).
- **ADR-060** (`docs/decisions/060-...accepted.md`) — Phase 1 item 8c authored Step 1.5 here; I2 invariant (line 98) governs the no-control-flow-branch contract; line 132 names the maintainer-side-only / JTBD-301-protection scope; line 160 (Confirmation criterion 4) gates the type-prompt placement.
- **JTBD-301** (`docs/jtbd/plugin-user/JTBD-301-...md`) — plugin-user no-pre-classification persona constraint; protected by the Step 1.5 maintainer-side scope guard.
- `packages/itil/skills/manage-problem/SKILL.md` — heavyweight intake counterpart.
- `packages/itil/skills/review-problems/SKILL.md` — re-rates the deferred placeholders + refreshes README.md.
- `packages/itil/scripts/test/i2-no-type-branching.bats` — pure-bash supporting-script enforcement of the I2 invariant; this SKILL.md change does not affect any pure-bash script and so does not change the bats outcome (still green).

$ARGUMENTS
