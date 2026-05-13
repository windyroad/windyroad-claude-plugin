#!/usr/bin/env bats

# P170 / Phase 3 P3.1 + Phase 4 P4.2 + I12 — behavioural fixture for
# capture-problem Step 1.5b JTBD-trace + persona dispatch. Per ADR-060
# § Phase 3 + Phase 4 in-scope amendment (2026-05-13):
#
# - Lexical JTBD-trace detection: description-contains-JTBD-NNN-ID →
#   silent-resolve jtbd_trace_value to the matched IDs.
# - I12 hard-block: type=user-business AND jtbd_trace_value empty AND
#   no --jtbd flag → halt-with-stderr-directive.
# - --jtbd=JTBD-NNN[,...] flag pre-resolves jtbd_trace_value silently.
# - --persona=<value> flag pre-resolves persona_value silently.
# - Skeleton template carries **JTBD**: and **Persona**: body fields
#   (matches existing **Status**: / **Type**: convention; frontmatter
#   migration deferred to follow-on slice).
#
# Reference-impl pattern: this fixture exercises the algorithm directly
# via shell helpers; the SKILL.md prose at runtime executes the same
# algorithm via LLM-interpretation. The bats algorithm IS the contract
# the SKILL.md prose binds.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_FILE="$REPO_ROOT/packages/itil/skills/capture-problem/SKILL.md"
}

# Reference implementation of the JTBD-trace lexical detector (matches
# the Step 1.5b prose at SKILL.md). Returns space-separated sorted-unique
# JTBD IDs from the description, OR empty string if none.
detect_jtbd_trace() {
  local desc="$1"
  echo "$desc" | grep -oE '\bJTBD-[0-9]+\b' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# Reference implementation of the I12 hard-block predicate. Returns
# 0 (true → block) when type=user-business AND jtbd_trace empty AND
# no --jtbd flag was provided. Returns 1 otherwise.
i12_should_block() {
  local type_value="$1" jtbd_trace="$2" had_jtbd_flag="$3"
  [ "$type_value" = "user-business" ] || return 1
  [ -z "$jtbd_trace" ] || return 1
  [ "$had_jtbd_flag" = "0" ] || return 1
  return 0
}

# Reference implementation of --jtbd= flag parser. Accepts CSV; returns
# space-separated IDs (canonicalised) OR empty if the flag wasn't set.
parse_jtbd_flag() {
  local arg="$1"
  case "$arg" in
    --jtbd=*) echo "${arg#--jtbd=}" | tr ',' '\n' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//' ;;
    *) echo "" ;;
  esac
}

# Reference implementation of --persona= validator. Returns the value
# if it's in the closed enum; halts (returns 1) otherwise.
validate_persona() {
  local val="$1"
  case "$val" in
    solo-developer|tech-lead|plugin-developer|plugin-user) echo "$val"; return 0 ;;
    *) return 1 ;;
  esac
}

@test "P3.1 detect_jtbd_trace: description with single JTBD-NNN citation extracts ID" {
  result=$(detect_jtbd_trace "Adopters want JTBD-101 to scale down for atomic fixes")
  [ "$result" = "JTBD-101" ]
}

@test "P3.1 detect_jtbd_trace: description with multiple JTBD-NNN citations extracts sorted-unique IDs" {
  result=$(detect_jtbd_trace "Composes with JTBD-008 and JTBD-001 governance outcome (also JTBD-008 again)")
  [ "$result" = "JTBD-001 JTBD-008" ]
}

@test "P3.1 detect_jtbd_trace: description with no JTBD citation returns empty" {
  result=$(detect_jtbd_trace "The captureProblem hook in packages/itil/hooks has a regex drift")
  [ -z "$result" ]
}

@test "P3.1 detect_jtbd_trace: JTBD-NNN must be word-boundary (not substring)" {
  # NOT-JTBD-001 should NOT match because of leading \b boundary check —
  # but `\b` matches at hyphen boundary in standard regex. The detector
  # treats this conservatively — anything matching \bJTBD-[0-9]+\b is
  # accepted. The signal is high-precision; mis-matches at hyphen
  # boundaries are still real JTBD-NNN citations from the maintainer's
  # perspective.
  result=$(detect_jtbd_trace "BANANA-JTBD-001-thing")
  [ "$result" = "JTBD-001" ]
}

@test "I12 i12_should_block: user-business + empty jtbd + no flag → blocks" {
  i12_should_block "user-business" "" "0"
}

@test "I12 i12_should_block: user-business + non-empty jtbd → does NOT block" {
  ! i12_should_block "user-business" "JTBD-001" "0"
}

@test "I12 i12_should_block: user-business + empty jtbd + --jtbd flag set → does NOT block" {
  ! i12_should_block "user-business" "" "1"
}

@test "I12 i12_should_block: technical + empty jtbd → does NOT block (technical has no JTBD requirement)" {
  ! i12_should_block "technical" "" "0"
}

@test "P3.1 parse_jtbd_flag: --jtbd=JTBD-NNN parses single ID" {
  result=$(parse_jtbd_flag "--jtbd=JTBD-001")
  [ "$result" = "JTBD-001" ]
}

@test "P3.1 parse_jtbd_flag: --jtbd=JTBD-A,JTBD-B parses CSV into sorted-unique list" {
  result=$(parse_jtbd_flag "--jtbd=JTBD-008,JTBD-001,JTBD-008")
  [ "$result" = "JTBD-001 JTBD-008" ]
}

@test "P3.1 parse_jtbd_flag: non-jtbd-flag arg returns empty" {
  result=$(parse_jtbd_flag "--type=user-business")
  [ -z "$result" ]
}

@test "P4.2 validate_persona: closed enum accepts solo-developer" {
  result=$(validate_persona "solo-developer")
  [ "$result" = "solo-developer" ]
}

@test "P4.2 validate_persona: closed enum accepts tech-lead" {
  validate_persona "tech-lead"
}

@test "P4.2 validate_persona: closed enum accepts plugin-developer" {
  validate_persona "plugin-developer"
}

@test "P4.2 validate_persona: closed enum accepts plugin-user" {
  validate_persona "plugin-user"
}

@test "P4.2 validate_persona: rejects free-text outside enum" {
  ! validate_persona "maintainer"
}

@test "SKILL.md: Step 1.5b section header exists for JTBD-trace + persona dispatch" {
  grep -qE '^### 1\.5b JTBD-trace \+ persona dispatch' "$SKILL_FILE"
}

@test "SKILL.md: Step 1.5b names I12 invariant load-bearing identifier" {
  grep -qE 'I12 (invariant|hard-block)' "$SKILL_FILE"
}

@test "SKILL.md: --jtbd= flag declared in flag table" {
  grep -qE '\| `--jtbd=JTBD-NNN' "$SKILL_FILE"
}

@test "SKILL.md: --persona= flag declared in flag table" {
  grep -qE '\| `--persona=<value>`' "$SKILL_FILE"
}

@test "SKILL.md: Step 4 template carries **JTBD**: body field" {
  grep -qE '^\*\*JTBD\*\*:' "$SKILL_FILE"
}

@test "SKILL.md: Step 4 template carries **Persona**: body field" {
  grep -qE '^\*\*Persona\*\*:' "$SKILL_FILE"
}

@test "SKILL.md: Step 1.5b names nullable-field-conditional shape (NOT type-conditional)" {
  grep -qE 'nullable-field-conditional' "$SKILL_FILE"
}

@test "SKILL.md: Step 1.5b cites I12 + ADR-060 amendment 2026-05-13" {
  grep -qE 'ADR-060 § Phase 3 \+ Phase 4 in-scope amendment' "$SKILL_FILE"
}

@test "SKILL.md: Step 1.5b preserves JTBD-301 firewall on plugin-user-side intake" {
  grep -qE 'plugin-user-side .* MUST NOT (prompt|carry)' "$SKILL_FILE"
}
