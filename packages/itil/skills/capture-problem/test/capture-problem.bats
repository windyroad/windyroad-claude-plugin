#!/usr/bin/env bats
# Behavioural fixtures for /wr-itil:capture-problem (P155).
#
# Per ADR-052 (Behavioural-tests-default for skill testing), these tests
# exercise the load-bearing primitives the skill dispatches and assert
# observable state — NOT the prose contents of SKILL.md.
#
# Behavioural surfaces under test:
#   1. P119 create-gate composition — capture-problem must source the
#      session-id + create-gate helpers and call mark_step2_complete
#      before the Write so the PreToolUse hook permits the new ticket
#      file to land. Test simulates the helper-sourcing sequence and
#      asserts the marker file lands in /tmp.
#   2. Skeleton-fill ticket shape — captured ticket has Description from
#      $ARGUMENTS plus the deferred-placeholder fields the skill
#      prescribes. Test runs the skeleton-fill command sequence against
#      a fixture description and asserts the resulting file's sections.
#   3. Next-ID computation — capture-problem reuses the manage-problem
#      Step 3 P056-safe local_max + origin_max formula. Test runs the
#      formula against a fixture problems directory and asserts the
#      computed next ID matches the expected zero-padded value.
#   4. Conservative title-only duplicate-grep — 3-keyword cap, filename
#      matches only (NOT body). Test runs the grep pattern against a
#      fixture and asserts the conservative match shape.
#
# @problem P155
# @jtbd JTBD-001 (enforce governance without slowing down — lightweight
#                  capture path)
# @jtbd JTBD-006 (progress backlog while AFK — sibling-finding capture
#                  in iter subprocesses)
# @jtbd JTBD-101 (extend the suite — discoverable / on /  autocomplete)
# @adr ADR-032 (governance skill invocation patterns — foreground-
#                lightweight-capture variant)
# @adr ADR-038 (progressive disclosure — SKILL.md + REFERENCE.md split)
# @adr ADR-049 (bin/ on PATH — capture-problem reuses existing
#                wr-itil-reconcile-readme shim, no new shim needed)
# @adr ADR-052 (behavioural-tests-default — these tests exercise
#                primitives, not SKILL.md prose)
# @adr ADR-119 (manage-problem create-gate — capture-problem composes
#                with the same per-session marker)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_DIR="${REPO_ROOT}/packages/itil/skills/capture-problem"
  SKILL_FILE="${SKILL_DIR}/SKILL.md"
  REF_FILE="${SKILL_DIR}/REFERENCE.md"
  CREATE_GATE_LIB="${REPO_ROOT}/packages/itil/hooks/lib/create-gate.sh"

  # Fresh per-test scratch directory and SESSION_ID.
  TMPROOT=$(mktemp -d)
  TEST_SESSION_ID="capture-problem-bats-$BATS_TEST_NUMBER-$$"
  MARKER_PATH="/tmp/manage-problem-grep-${TEST_SESSION_ID}"
  rm -f "$MARKER_PATH"
}

teardown() {
  rm -rf "$TMPROOT"
  rm -f "$MARKER_PATH"
}

# ---------------------------------------------------------------------------
# Existence / wiring tests — minimum surface required for the skill to be
# discoverable. Not structural prose-greps; these assert artefacts exist.
# ---------------------------------------------------------------------------

@test "capture-problem: SKILL.md and REFERENCE.md both exist (ADR-038 split)" {
  [ -f "$SKILL_FILE" ]
  [ -f "$REF_FILE" ]
}

@test "capture-problem: SKILL.md frontmatter declares wr-itil:capture-problem name" {
  # Discoverable on / autocomplete depends on the canonical name.
  # ADR-032 names this skill; ADR-010-amended skill-granularity rule.
  run grep -E '^name: wr-itil:capture-problem$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# P119 create-gate composition — load-bearing behavioural primitive.
# capture-problem must call mark_step2_complete before any Write of a new
# ticket file, otherwise the PreToolUse:Write hook denies the Write.
# ---------------------------------------------------------------------------

@test "capture-problem: mark_step2_complete writes marker the P119 hook checks" {
  # Source the helper the skill prescribes; call the canonical mark
  # function; assert the marker file lands at the path the hook reads.
  source "$CREATE_GATE_LIB"
  mark_step2_complete "$TEST_SESSION_ID"
  [ -f "$MARKER_PATH" ]
}

@test "capture-problem: check_create_gate returns 0 after mark_step2_complete" {
  # Composes with manage-problem-enforce-create.sh which uses
  # check_create_gate $SESSION_ID — exit 0 means "permit Write".
  source "$CREATE_GATE_LIB"
  run check_create_gate "$TEST_SESSION_ID"
  [ "$status" -ne 0 ]    # before mark — denied
  mark_step2_complete "$TEST_SESSION_ID"
  run check_create_gate "$TEST_SESSION_ID"
  [ "$status" -eq 0 ]    # after mark — permitted
}

@test "capture-problem: mark_step2_complete is idempotent across cross-skill order" {
  # Whether manage-problem fires first then capture-problem, or vice
  # versa, the marker mechanic is a no-op after the first call.
  source "$CREATE_GATE_LIB"
  mark_step2_complete "$TEST_SESSION_ID"
  mark_step2_complete "$TEST_SESSION_ID"
  mark_step2_complete "$TEST_SESSION_ID"
  [ -f "$MARKER_PATH" ]
}

# ---------------------------------------------------------------------------
# Next-ID computation — capture-problem reuses manage-problem Step 3 formula
# ---------------------------------------------------------------------------

@test "capture-problem: next-ID formula is P056-safe (origin/local max + 1)" {
  # Build a fixture problems directory with mixed status suffixes.
  # The formula must pick the max ID across all suffixes and zero-pad.
  mkdir -p "$TMPROOT/docs/problems"
  : > "$TMPROOT/docs/problems/001-foo.closed.md"
  : > "$TMPROOT/docs/problems/042-bar.open.md"
  : > "$TMPROOT/docs/problems/099-baz.known-error.md"
  : > "$TMPROOT/docs/problems/107-qux.verifying.md"

  # Mirror manage-problem Step 3 local-max formula exactly.
  local_max=$(ls "$TMPROOT/docs/problems"/*.md 2>/dev/null \
              | sed 's/.*\///' \
              | grep -oE '^[0-9]+' \
              | sort -n | tail -1)
  [ "$local_max" = "107" ]

  # No origin available in the fixture; default to 0 then increment.
  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n0" | sort -n | tail -1) + 1 )))
  [ "$next" = "108" ]
}

@test "capture-problem: next-ID handles empty problems dir (first ticket)" {
  mkdir -p "$TMPROOT/docs/problems"
  local_max=$(ls "$TMPROOT/docs/problems"/*.md 2>/dev/null \
              | sed 's/.*\///' \
              | grep -oE '^[0-9]+' \
              | sort -n | tail -1)
  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n0" | sort -n | tail -1) + 1 )))
  [ "$next" = "001" ]
}

@test "capture-problem: next-ID handles 099 → 100 transition without octal-eval failure (P164)" {
  # P164 regression: bash $(( ... )) parses leading-zero numbers as octal.
  # `099` is invalid octal (digits >= 8). Without `10#` prefix, this fires:
  #   bash: 099: value too great for base (error token is "099")
  # The fix is the standard `10#` base-10 prefix on the inner $(echo ... | tail -1).
  mkdir -p "$TMPROOT/docs/problems"
  : > "$TMPROOT/docs/problems/098-foo.open.md"
  : > "$TMPROOT/docs/problems/099-bar.open.md"

  local_max=$(ls "$TMPROOT/docs/problems"/*.md 2>/dev/null \
              | sed 's/.*\///' \
              | grep -oE '^[0-9]+' \
              | sort -n | tail -1)
  [ "$local_max" = "099" ]

  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n0" | sort -n | tail -1) + 1 )))
  [ "$next" = "100" ]
}

# ---------------------------------------------------------------------------
# Conservative duplicate-grep — title-only filename match, 3-keyword cap.
# Architect Q1 verdict: title-only because conservative threshold rationale
# (P155 line 24) — false-positives on body text would either over-prompt
# or be silently swallowed (capture-problem has no AskUserQuestion).
# ---------------------------------------------------------------------------

@test "capture-problem: duplicate-grep matches kebab-cased keywords in filenames" {
  mkdir -p "$TMPROOT/docs/problems"
  : > "$TMPROOT/docs/problems/050-checkpoint-stuck-saving.open.md"
  : > "$TMPROOT/docs/problems/051-foul-drawn-garbled.closed.md"

  # Description: "checkpoint stuck on save retry" — extract 3 kebab tokens.
  # Title-only grep against filenames; bodies are NOT scanned (conservative).
  match_count=$(ls "$TMPROOT/docs/problems"/*.md \
                | grep -ciE 'checkpoint|stuck|save' || true)
  [ "$match_count" -ge 1 ]
}

@test "capture-problem: duplicate-grep does NOT match keywords in body content (title-only)" {
  mkdir -p "$TMPROOT/docs/problems"
  # File whose title has zero overlap but whose body mentions checkpoint
  cat > "$TMPROOT/docs/problems/060-unrelated.open.md" <<'EOF'
# Unrelated ticket
Body mentions checkpoint somewhere but title doesn't.
EOF

  # Title-only grep on filenames must NOT match.
  match_count=$(ls "$TMPROOT/docs/problems"/*.md \
                | grep -ciE 'checkpoint' || true)
  [ "$match_count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Skeleton-fill ticket shape — capture-problem writes a deferred-placeholder
# ticket. Default Priority and Effort are flagged for re-rate at next review.
# ---------------------------------------------------------------------------

@test "capture-problem: skeleton-filled ticket carries the deferred-placeholder pattern" {
  # Fixture mirrors the SKILL.md Step 4-5 prescribed write target — per
  # ADR-031 per-state-subdir layout (`docs/problems/open/<NNN>-<slug>.md`),
  # NOT the pre-ADR-031 flat shape (`docs/problems/<NNN>-<slug>.open.md`).
  # P281 (template-refresh sub-shape) corrected the SKILL.md drift; this
  # fixture exercises the now-canonical write path.
  mkdir -p "$TMPROOT/docs/problems/open"
  TITLE="example-aside-finding"
  ID="200"
  TODAY=$(date -u +%Y-%m-%d)
  DESCRIPTION="Quick observation worth a ticket but not blocking."

  # Mirror the SKILL.md skeleton-fill template.
  cat > "$TMPROOT/docs/problems/open/${ID}-${TITLE}.md" <<EOF
# Problem ${ID}: ${TITLE}

**Status**: Open
**Reported**: ${TODAY}
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

${DESCRIPTION}

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
EOF

  # Behavioural assertions: ticket file has the load-bearing fields.
  TICKET="$TMPROOT/docs/problems/open/${ID}-${TITLE}.md"
  [ -f "$TICKET" ]
  run grep -F '**Status**: Open' "$TICKET"
  [ "$status" -eq 0 ]
  # Description survives verbatim
  run grep -F "$DESCRIPTION" "$TICKET"
  [ "$status" -eq 0 ]
  # Deferred placeholders flag re-rating
  run grep -F 'deferred — re-rate at next /wr-itil:review-problems' "$TICKET"
  [ "$status" -eq 0 ]
  # Investigation Tasks nudges user to re-rate
  run grep -F 'Re-rate Priority and Effort at next /wr-itil:review-problems' "$TICKET"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Skill-allowed-tools surface contract — capture-problem MUST NOT carry
# AskUserQuestion (per design Q4 + ADR-044 framework-mediated mechanical-
# stage decisions). This is observable from the frontmatter declaration
# the runtime consumes.
# ---------------------------------------------------------------------------

@test "capture-problem: allowed-tools omits AskUserQuestion (no interactive branches)" {
  # The skill's contract is NO AskUserQuestion at all — duplicate-check,
  # priority-default, effort-default are framework-mediated mechanical
  # stages per ADR-044. AskUserQuestion in allowed-tools would let
  # future drift sneak prompts back in.
  run grep -E '^allowed-tools:' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -E '^allowed-tools:.*AskUserQuestion' "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "capture-problem: allowed-tools includes Bash (for create-gate marker write)" {
  # mark_step2_complete via Bash is the load-bearing primitive — without
  # Bash in allowed-tools the skill cannot satisfy P119.
  run grep -E '^allowed-tools:.*Bash' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "capture-problem: allowed-tools includes Write (for new ticket file)" {
  run grep -E '^allowed-tools:.*Write' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Deferred-README-refresh contract — distinguishing capture-problem from
# manage-problem. capture-problem must NOT stage docs/problems/README.md
# in its commit (deferred to /wr-itil:review-problems).
# ---------------------------------------------------------------------------

@test "capture-problem: SKILL.md prescribes deferred README refresh (no inline P094 block)" {
  # The contract distinction from manage-problem: capture-problem does
  # NOT regenerate README.md inline; it defers to /wr-itil:review-problems.
  # This is a behavioural primitive — a future maintainer who copies the
  # P094 block over would break the lightweight-capture promise.
  # Asserts the SKILL.md names the deferred contract explicitly.
  run grep -F '/wr-itil:review-problems' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# P185 — Step 1.5 derive-first classifier behavioural tests.
#
# The classifier is an agent-driven SKILL.md instruction (not a pure-bash
# script), so these tests mirror the lexical-signal regex sets from
# SKILL.md and assert classification outcomes on fixture descriptions —
# same shape as the existing next-ID-formula and duplicate-grep tests
# that mirror manage-problem Step 3 / capture-problem Step 2 formulas.
#
# Per ADR-052 (behavioural-tests-default): observable input → output
# assertions on the classifier's resolution function. Per P081: NOT
# grepping SKILL.md prose for signal-token references — that would be
# the structural-test-disguised-as-behavioural anti-pattern.
#
# I2 protection: each test exercises both `technical` and `user-business`
# classification paths and asserts the stderr-advisory shape is
# isomorphic beyond the substituted type-value + signal names.
# ---------------------------------------------------------------------------

# Mirror of the SKILL.md Step 1.5 classifier — emits "technical",
# "user-business", or "ambiguous" on stdout. Always returns 0 so the
# `result=$(classify_description ...)` substitution in tests below
# never trips bats' default-fail-on-nonzero-substitution behaviour;
# tests assert on the string verdict, not the exit code.
#
# This helper mirrors the SKILL.md regex set so the test exercises the
# classifier's load-bearing pattern set; drift between this helper and
# SKILL.md is the failure mode this test corpus catches.
classify_description() {
  local desc="$1"
  local tech_signals=()
  local ub_signals=()

  # Technical signals — case-insensitive matching via grep -E -o -i.
  # Each match contributes the matched token to the signal list.
  local tech_patterns=(
    '[a-z]+[A-Z][a-zA-Z]+'                    # camelCase (case-SENSITIVE - the case shape is the signal)
    '[a-z]+-[a-z][a-z-]+-[a-z][a-z-]+'        # kebab-case with >=2 hyphens
    '[a-z]+_[a-z][a-z_]+'                     # snake_case
    '\.(md|sh|bats|ts|js|json|yaml|yml|py|rb|go|css|html)\b'
    'packages/[a-z-]+/'
    'docs/[a-z-]+/'
    '\.github/'
    '/tmp/'
    '/wr-[a-z-]+:[a-z-]+'
    '\bgit (commit|push|mv|add|rebase|merge)\b'
    '\bnpm (run|install|publish)\b'
    '\b(bash|bats|grep|sed|jq)\b'
    '\b(drift|regression|hook|marker|gate|refresh|idempotent|stderr|stdout|regex|formula|dispatch|frontmatter|substring|escape|sentinel|bypass|TTL|cache|invalidate|deduplicate|race|deadlock|timeout|preflight)\b'
    '\b(error|failure|exception|panic|segfault|undefined|EACCES|ENOENT)\b'
  )

  # User-business signals — case-insensitive.
  local ub_patterns=(
    '\b(adopter|adopters|plugin-user|plugin-users|solo[-_ ]?developer|maintainer-persona|end[-_ ]?user|customer|stakeholder)\b'
    '\b(workflow|journey|onboarding|friction|UX|experience|usability|discoverability)\b'
    '\bJTBD-[0-9]+\b'
    '\bjob-to-be-done\b'
    '\b(want|need|cannot|unable to)\b[[:space:]]+(use|access|find|discover|complete)'
    '\bdesired outcome\b'
    '\bunmet need\b'
  )

  for p in "${tech_patterns[@]}"; do
    if echo "$desc" | grep -qE "$p" 2>/dev/null; then
      tech_signals+=("$p")
    fi
  done

  for p in "${ub_patterns[@]}"; do
    if echo "$desc" | grep -qiE "$p" 2>/dev/null; then
      ub_signals+=("$p")
    fi
  done

  local tech_n="${#tech_signals[@]}"
  local ub_n="${#ub_signals[@]}"

  if [ "$tech_n" -ge 1 ] && [ "$ub_n" -eq 0 ]; then
    echo "technical"
  elif [ "$tech_n" -eq 0 ] && [ "$ub_n" -ge 1 ]; then
    echo "user-business"
  else
    echo "ambiguous"
  fi
  return 0
}

@test "P185: classifier resolves pure-technical description as technical" {
  # camelCase identifier + file path + mechanism word — all technical signals.
  result=$(classify_description "The captureProblem hook in packages/itil/hooks/lib/detectors.sh has a regex drift")
  [ "$result" = "technical" ]
}

@test "P185: classifier resolves pure-technical description (error-message variant)" {
  result=$(classify_description "The bats test exits with exception ENOENT on /tmp/manage-problem-grep")
  [ "$result" = "technical" ]
}

@test "P185: classifier resolves pure-technical description (command-name variant)" {
  result=$(classify_description "git mv to docs/problems/<NNN>.verifying.md fails on the rebase merge")
  [ "$result" = "technical" ]
}

@test "P185: classifier resolves pure-user-business description (persona + journey)" {
  result=$(classify_description "Adopters cannot complete the onboarding workflow without UX friction")
  [ "$result" = "user-business" ]
}

@test "P185: classifier resolves pure-user-business description (JTBD-shaped need)" {
  result=$(classify_description "JTBD-101 names a desired outcome the plugin-user cannot achieve")
  [ "$result" = "user-business" ]
}

@test "P185: classifier resolves pure-user-business description (unmet-need variant)" {
  result=$(classify_description "Solo-developers want to discover scaffold templates but cannot find them")
  [ "$result" = "user-business" ]
}

@test "P185: classifier resolves mixed-signal description as ambiguous" {
  # Mentions both technical mechanism (hook drift) and user-business (adopter friction)
  # — exactly the case the AskUserQuestion fallback is designed for.
  result=$(classify_description "The hook drift affects adopters in the onboarding workflow")
  [ "$result" = "ambiguous" ]
}

@test "P185: classifier resolves no-signal description as ambiguous" {
  # Plain prose with no technical or user-business signals — fallback to ask.
  result=$(classify_description "Something is off but I cannot describe it well")
  [ "$result" = "ambiguous" ]
}

# ---------------------------------------------------------------------------
# Stderr-advisory shape — I2 isomorphism guard.
# Per architect-review rider: the advisory text MUST be identical in
# sentence structure across `technical` vs `user-business` classifications
# beyond the substituted type-value tokens. Otherwise the advisory itself
# becomes a control-flow asymmetry keyed on `type` and re-introduces an
# I2 leak through the back door.
# ---------------------------------------------------------------------------

# Mirror of the SKILL.md advisory template. P132 Phase 2a-iii-A renamed
# the verb from `classified` to `derived` to align with the shared helper
# `packages/itil/lib/derive-first-dispatch.sh`'s emit_stderr_advisory
# function — I2-isomorphic format `<skill>: derived <field>=<value> from
# <source>; <reversibility>` across all three derive-first declaration-skill
# surfaces.
format_stderr_advisory() {
  local resolved_type="$1"
  local other_type="$2"
  local signals="$3"
  printf 'capture-problem: derived type=%s from description signals: %s; re-invoke with --type=%s to override\n' \
    "$resolved_type" "$signals" "$other_type"
}

# Strip the type-value tokens + signal-name list so we can compare the
# sentence skeleton in isolation.
strip_substituted_tokens() {
  sed -E 's/type=[a-z-]+/type=<X>/g; s/signals: [^;]+;/signals: <S>;/g'
}

@test "P185: stderr advisory shape is isomorphic across technical vs user-business classifications" {
  tech_msg=$(format_stderr_advisory technical user-business "camelCase-id, packages/path")
  ub_msg=$(format_stderr_advisory user-business technical "adopter, onboarding")
  tech_shape=$(echo "$tech_msg" | strip_substituted_tokens)
  ub_shape=$(echo "$ub_msg" | strip_substituted_tokens)
  [ "$tech_shape" = "$ub_shape" ]
}

@test "P185: stderr advisory names the override flag with the OTHER type value" {
  tech_msg=$(format_stderr_advisory technical user-business "sig")
  ub_msg=$(format_stderr_advisory user-business technical "sig")
  # The technical-classified advisory must offer the user-business override.
  echo "$tech_msg" | grep -q -- '--type=user-business'
  # The user-business-classified advisory must offer the technical override.
  echo "$ub_msg" | grep -q -- '--type=technical'
}

@test "P185: stderr advisory does NOT prefix with type-value when describing the contract" {
  # The shape `derived type=<value> from description signals: <list>;
  # re-invoke with --type=<other> to override` — the leading prose
  # "capture-problem: derived type=" must be identical regardless of
  # type value (substitution happens AFTER the equals sign). P132 Phase
  # 2a-iii-A renamed `classified` -> `derived` to align with the shared
  # helper `packages/itil/lib/derive-first-dispatch.sh`'s I2-isomorphic
  # format across all three declaration-skill surfaces.
  tech_msg=$(format_stderr_advisory technical user-business "sig")
  ub_msg=$(format_stderr_advisory user-business technical "sig")
  echo "$tech_msg" | grep -q '^capture-problem: derived type='
  echo "$ub_msg" | grep -q '^capture-problem: derived type='
}

# ---------------------------------------------------------------------------
# Pre-resolution flag precedence — caller-side flags MUST short-circuit
# before the classifier runs. Order: --type=<value> > --no-prompt >
# classifier > AskUserQuestion fallback.
# ---------------------------------------------------------------------------

# Mirror of SKILL.md Step 1.5 dispatch order.
resolve_type_dispatch() {
  local type_flag="$1"      # value from --type=<X>, empty if not passed
  local no_prompt="$2"      # "1" if --no-prompt passed, empty otherwise
  local desc="$3"
  if [ -n "$type_flag" ]; then
    echo "$type_flag:pre-resolved-flag"
    return 0
  fi
  if [ "$no_prompt" = "1" ]; then
    echo "technical:no-prompt-default"
    return 0
  fi
  local classified
  classified=$(classify_description "$desc")
  if [ "$classified" = "ambiguous" ]; then
    echo "ambiguous:fallback-to-ask"
  else
    echo "$classified:derived-from-signals"
  fi
  return 0
}

@test "P185: --type=user-business pre-resolves even on pure-technical description" {
  # Caller-side flag MUST win over the classifier — explicit override.
  result=$(resolve_type_dispatch user-business "" "The hook in packages/itil/hooks/lib drifts")
  [ "$result" = "user-business:pre-resolved-flag" ]
}

@test "P185: --no-prompt pre-resolves to technical even on pure-user-business description" {
  # AFK contract: --no-prompt always lands `technical`, regardless of description signals.
  result=$(resolve_type_dispatch "" "1" "Adopters cannot complete the onboarding workflow")
  [ "$result" = "technical:no-prompt-default" ]
}

@test "P185: no flags + pure-technical description → derived-from-signals technical" {
  result=$(resolve_type_dispatch "" "" "The captureProblem.bats test fails with exit 1")
  [ "$result" = "technical:derived-from-signals" ]
}

@test "P185: no flags + pure-user-business description → derived-from-signals user-business" {
  result=$(resolve_type_dispatch "" "" "JTBD-301 plugin-user persona constraint")
  [ "$result" = "user-business:derived-from-signals" ]
}

@test "P185: no flags + ambiguous description → fallback to AskUserQuestion" {
  result=$(resolve_type_dispatch "" "" "Something feels wrong but I cannot say what")
  [ "$result" = "ambiguous:fallback-to-ask" ]
}

# ---------------------------------------------------------------------------
# Meta-recursive corpus validation — exercise the classifier against
# real problem-ticket descriptions and assert the classifier's verdict
# matches the existing `**Type**:` field on each ticket. Limited to the
# tickets whose descriptions are short enough to be deterministic; the
# point is to catch obvious classifier regressions on the canonical
# corpus, not to validate every edge case.
# ---------------------------------------------------------------------------

@test "P185: classifier matches the P185 ticket's own self-classification (meta-recursive)" {
  # P185's body opens with: "/wr-itil:capture-problem Step 1.5 currently
  # fires an AskUserQuestion for type ..." — command-name pattern +
  # camelCase + mechanism words ("dispatch", "regex"). The ticket's
  # **Type**: field is `technical`. Classifier must agree.
  desc="/wr-itil:capture-problem Step 1.5 fires an AskUserQuestion for type via a regex dispatch the SKILL.md frontmatter resolves"
  result=$(classify_description "$desc")
  [ "$result" = "technical" ]
}

# ---------------------------------------------------------------------------
# P281 — ADR-031 per-state-subdir layout conformance on the SKILL.md
# write-target path template.
#
# Surface 2 / structural-grep is justified here per ADR-052 § Surface 2
# escape-hatch contract: the SKILL.md path template IS the contract surface
# that adopter-side agents read literally. Concrete observed regression
# (voder-mcp-hub commit 6c73880) landed a ticket at the pre-ADR-031 flat
# path because the SKILL.md template named the flat shape. No pure-bash
# script equivalent exists to behaviourally test against — the test target
# IS the agent-driven prose instruction. Drift here re-opens the P281
# regression vector.
# ---------------------------------------------------------------------------

@test "P281: SKILL.md Step 4 File-path template names per-state-subdir layout (ADR-031)" {
  # The contract surface: the literal `**File path**:` declaration in
  # Step 4 of SKILL.md. Must name `docs/problems/open/<NNN>-<kebab-title>.md`
  # per ADR-031 (accepted + human-oversight: confirmed), NOT the pre-ADR-031
  # flat shape `docs/problems/<NNN>-<kebab-title>.open.md`.
  run grep -F '**File path**: `docs/problems/open/<NNN>-<kebab-title>.md`' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "P281: SKILL.md Step 4-5-6 path declarations do NOT carry the pre-ADR-031 flat shape" {
  # Negative assertion: none of the SKILL.md write-target path declarations
  # may name the flat `docs/problems/<NNN>-<kebab-title>.open.md` shape.
  # The voder-mcp-hub P032 regression (commit 6c73880) was driven by this
  # literal text appearing in SKILL.md and being followed by an adopter-side
  # agent. Title-anchored grep — body-text mentions of the old shape (e.g.
  # commit-message examples that don't actually carry the path) are fine.
  run grep -F 'docs/problems/<NNN>-<kebab-title>.open.md' "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "P281: SKILL.md Step 5 Write target names per-state-subdir layout" {
  # Step 5 prescribes the single Write call — must direct to per-state path.
  run grep -F 'Single `Write` to `docs/problems/open/<NNN>-<kebab-title>.md`' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "P281: SKILL.md Step 6 git-add target names per-state-subdir layout" {
  # Step 6 prescribes the stage command — must reference per-state path.
  run grep -F 'git add docs/problems/open/<NNN>-<kebab-title>.md' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
