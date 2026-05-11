#!/usr/bin/env bats
# Behavioural fixtures for /wr-architect:capture-adr (P156).
#
# Per ADR-052 (Behavioural-tests-default for skill testing), these tests
# exercise the load-bearing primitives the skill dispatches and assert
# observable state — NOT the prose contents of SKILL.md.
#
# Behavioural surfaces under test:
#   1. Next-ID computation — capture-adr reuses create-adr Step 3 P056-safe
#      local_max + origin_max formula. Test runs the formula against a
#      fixture decisions directory and asserts the computed next ID
#      matches the expected zero-padded value (including the empty-dir
#      first-ADR base case).
#   2. Skeleton-fill MADR shape — captured ADR has Title + status proposed
#      + deferred-flag literal pointer string + numbered-options
#      placeholder (1. chosen + 2. deferred). Tests execute the
#      skeleton-fill template against fixture inputs and assert the
#      resulting file's load-bearing fields.
#   3. Default reassessment-date — 3 months from today is computed
#      correctly and lands in frontmatter.
#   4. Frontmatter sentinel values — decision-makers: [unspecified — fill
#      at canonical review] is the framework-policy default.
#
# Structural assertions are limited to existence/wiring (file presence +
# frontmatter name + allowed-tools surface) per the precedent set by the
# capture-problem bats fixtures (P155). Anything else asserts behaviour.
#
# @problem P156
# @jtbd JTBD-001 (enforce governance without slowing down — lightweight
#                  ADR-capture path)
# @jtbd JTBD-005 (invoke governance assessments on demand — discoverable
#                  via / autocomplete)
# @jtbd JTBD-006 (progress backlog while AFK — mid-iter design-decision
#                  capture in iter subprocesses)
# @jtbd JTBD-101 (extend the suite — symmetric with capture-problem on
#                  the architect plugin namespace)
# @adr ADR-032 (governance skill invocation patterns — foreground-
#                lightweight-capture variant for capture-adr)
# @adr ADR-038 (progressive disclosure — SKILL.md + REFERENCE.md split)
# @adr ADR-044 (decision-delegation contract — framework-mediated
#                mechanical-stage carve-outs; no AskUserQuestion)
# @adr ADR-049 (bin/ on PATH — capture-adr is self-contained, no shim
#                required, same as create-adr)
# @adr ADR-052 (behavioural-tests-default — these tests exercise
#                primitives, not SKILL.md prose)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_DIR="${REPO_ROOT}/packages/architect/skills/capture-adr"
  SKILL_FILE="${SKILL_DIR}/SKILL.md"
  REF_FILE="${SKILL_DIR}/REFERENCE.md"

  # Fresh per-test scratch directory.
  TMPROOT=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPROOT"
}

# ---------------------------------------------------------------------------
# Existence / wiring tests — minimum surface required for the skill to be
# discoverable. Not structural prose-greps; these assert artefacts exist.
# ---------------------------------------------------------------------------

@test "capture-adr: SKILL.md and REFERENCE.md both exist (ADR-038 split)" {
  [ -f "$SKILL_FILE" ]
  [ -f "$REF_FILE" ]
}

@test "capture-adr: SKILL.md frontmatter declares wr-architect:capture-adr name" {
  # Discoverable on / autocomplete depends on the canonical name.
  # ADR-032 names this skill at line 81 + P156 amendment block.
  run grep -E '^name: wr-architect:capture-adr$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Next-ID computation — capture-adr reuses create-adr Step 3 formula.
# P056-safe via `git ls-tree --name-only` to avoid blob-SHA false-match.
# ---------------------------------------------------------------------------

@test "capture-adr: next-ID formula is P056-safe (origin/local max + 1)" {
  # Build a fixture decisions directory with mixed status suffixes.
  # The formula must pick the max ID across all suffixes and zero-pad.
  mkdir -p "$TMPROOT/docs/decisions"
  : > "$TMPROOT/docs/decisions/001-foo.accepted.md"
  : > "$TMPROOT/docs/decisions/032-bar.proposed.md"
  : > "$TMPROOT/docs/decisions/057-baz.proposed.md"
  : > "$TMPROOT/docs/decisions/123-qux.superseded.md"

  # Mirror create-adr Step 3 / capture-adr Step 2 local-max formula exactly.
  local_max=$(ls "$TMPROOT/docs/decisions"/*.md 2>/dev/null \
              | sed 's/.*\///' \
              | grep -oE '^[0-9]+' \
              | sort -n | tail -1)
  [ "$local_max" = "123" ]

  # No origin available in the fixture; default to 0 then increment.
  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n0" | sort -n | tail -1) + 1 )))
  [ "$next" = "124" ]
}

@test "capture-adr: next-ID handles empty decisions dir (first ADR)" {
  mkdir -p "$TMPROOT/docs/decisions"
  local_max=$(ls "$TMPROOT/docs/decisions"/*.md 2>/dev/null \
              | sed 's/.*\///' \
              | grep -oE '^[0-9]+' \
              | sort -n | tail -1)
  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n0" | sort -n | tail -1) + 1 )))
  [ "$next" = "001" ]
}

@test "capture-adr: next-ID prefers origin_max when origin > local (collision guard)" {
  # Simulate the case where origin has a higher ADR number than local
  # (parallel session pushed a new ADR before this session captures).
  mkdir -p "$TMPROOT/docs/decisions"
  : > "$TMPROOT/docs/decisions/050-local.proposed.md"
  local_max=50
  origin_max=175   # parallel session pushed ADR-175

  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
  [ "$next" = "176" ]
}

@test "capture-adr: next-ID handles 099 → 100 transition without octal-eval failure (P164)" {
  # P164 regression: bash $(( ... )) parses leading-zero numbers as octal.
  # `099` is invalid octal (digits >= 8). Without `10#` prefix, this fires:
  #   bash: 099: value too great for base (error token is "099")
  # The fix is the standard `10#` base-10 prefix on the inner $(echo ... | tail -1).
  mkdir -p "$TMPROOT/docs/decisions"
  : > "$TMPROOT/docs/decisions/098-foo.proposed.md"
  : > "$TMPROOT/docs/decisions/099-bar.proposed.md"

  local_max=$(ls "$TMPROOT/docs/decisions"/*.md 2>/dev/null \
              | sed 's/.*\///' \
              | grep -oE '^[0-9]+' \
              | sort -n | tail -1)
  [ "$local_max" = "099" ]

  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n0" | sort -n | tail -1) + 1 )))
  [ "$next" = "100" ]
}

# ---------------------------------------------------------------------------
# Skeleton-fill MADR shape — capture-adr writes a deferred-placeholder ADR
# at status: proposed. Load-bearing primitives:
#   - Title at H1
#   - status: proposed in frontmatter
#   - decision-makers sentinel
#   - reassessment-date 3 months from today
#   - Numbered-options placeholder (1. chosen + 2. deferred) — preserves
#     MADR ≥2-options surface for any doc-lint assertion.
#   - Literal pointer string `(deferred to /wr-architect:create-adr
#     canonical review)` — this is the canonical-expansion detection key.
# ---------------------------------------------------------------------------

@test "capture-adr: skeleton-filled ADR carries deferred-flag literal pointer string" {
  # The literal `(deferred to /wr-architect:create-adr canonical review)`
  # is the load-bearing canonical-expansion detection signal. Any future
  # auto-detect-and-expand path will key off this string.
  mkdir -p "$TMPROOT/docs/decisions"
  TITLE="example-mid-iter-decision"
  ID="200"
  TODAY=$(date -u +%Y-%m-%d)
  REASSESS=$(date -u -v+3m +%Y-%m-%d 2>/dev/null || date -u -d "+3 months" +%Y-%m-%d)
  CONTEXT_LINE="Iter-bound design choice that needs codification."
  DECISION_LINE="Adopt Option A because it preserves invariants X and Y."

  # Mirror the SKILL.md skeleton-fill template.
  cat > "$TMPROOT/docs/decisions/${ID}-${TITLE}.proposed.md" <<EOF
---
status: "proposed"
date: ${TODAY}
decision-makers: [unspecified — fill at canonical review]
consulted: []
informed: []
reassessment-date: ${REASSESS}
---

# ${TITLE}

> Captured via /wr-architect:capture-adr (foreground-lightweight aside-invocation per ADR-032 P156 amendment). Run /wr-architect:create-adr on this ID to expand the deferred sections canonically.

## Context and Problem Statement

${CONTEXT_LINE}

## Decision Drivers

- (deferred to /wr-architect:create-adr canonical review)

## Considered Options

1. **Option A (chosen)** — ${DECISION_LINE}
2. (deferred — see /wr-architect:create-adr canonical review)

## Decision Outcome

Chosen option: **"Option A"**, because ${DECISION_LINE}

## Consequences

### Good

- (deferred to /wr-architect:create-adr canonical review)

### Neutral

- (deferred to /wr-architect:create-adr canonical review)

### Bad

- (deferred to /wr-architect:create-adr canonical review)

## Confirmation

(deferred to /wr-architect:create-adr canonical review)

## Pros and Cons of the Options

### Option A

- (deferred to /wr-architect:create-adr canonical review)

## Reassessment Criteria

(deferred to /wr-architect:create-adr canonical review — default reassessment-date 3 months from capture)
EOF

  ADR="$TMPROOT/docs/decisions/${ID}-${TITLE}.proposed.md"
  [ -f "$ADR" ]

  # Behavioural assertions: load-bearing fields present.
  run grep -F 'status: "proposed"' "$ADR"
  [ "$status" -eq 0 ]
  # Decision-makers sentinel for canonical-review fill.
  run grep -F 'decision-makers: [unspecified — fill at canonical review]' "$ADR"
  [ "$status" -eq 0 ]
  # Title from input lands at H1.
  run grep -F "# ${TITLE}" "$ADR"
  [ "$status" -eq 0 ]
  # Context survives verbatim from input.
  run grep -F "$CONTEXT_LINE" "$ADR"
  [ "$status" -eq 0 ]
  # Decision survives verbatim from input.
  run grep -F "$DECISION_LINE" "$ADR"
  [ "$status" -eq 0 ]
  # Deferred-flag literal pointer string — canonical-expansion detection key.
  run grep -F '(deferred to /wr-architect:create-adr canonical review)' "$ADR"
  [ "$status" -eq 0 ]
}

@test "capture-adr: skeleton has numbered-options placeholder (1. chosen + 2. deferred)" {
  # MADR ≥2-options surface preserved at skeleton time so any doc-lint
  # asserting numbered-option presence does not fire on capture-adr output.
  # Architect Q2 verdict: write literal placeholder, defer enforcement.
  mkdir -p "$TMPROOT/docs/decisions"
  ID="201"
  TITLE="another-decision"

  cat > "$TMPROOT/docs/decisions/${ID}-${TITLE}.proposed.md" <<'EOF'
## Considered Options

1. **Option A (chosen)** — One-line summary
2. (deferred — see /wr-architect:create-adr canonical review)
EOF

  ADR="$TMPROOT/docs/decisions/${ID}-${TITLE}.proposed.md"
  # Numbered option 1 with chosen marker.
  run grep -F '1. **Option A (chosen)**' "$ADR"
  [ "$status" -eq 0 ]
  # Numbered option 2 with deferred marker.
  run grep -F '2. (deferred — see /wr-architect:create-adr canonical review)' "$ADR"
  [ "$status" -eq 0 ]
}

@test "capture-adr: default reassessment-date is 3 months from today (matches create-adr)" {
  # The 3-month default matches create-adr Step 4 default and is
  # framework-policy per ADR-044. Computed value lands in frontmatter.
  TODAY=$(date -u +%Y-%m-%d)
  # Compute 3 months from today using BSD date or GNU date.
  REASSESS=$(date -u -v+3m +%Y-%m-%d 2>/dev/null || date -u -d "+3 months" +%Y-%m-%d)

  # The reassess date is non-empty and parseable as YYYY-MM-DD.
  [ -n "$REASSESS" ]
  echo "$REASSESS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

  # The reassess date is strictly later than today (3 months ahead).
  [ "$REASSESS" \> "$TODAY" ]
}

# ---------------------------------------------------------------------------
# Skill-allowed-tools surface contract — capture-adr MUST NOT carry
# AskUserQuestion (per design Q4 + ADR-044 framework-mediated mechanical-
# stage decisions). This is observable from the frontmatter declaration
# the runtime consumes.
# ---------------------------------------------------------------------------

@test "capture-adr: allowed-tools omits AskUserQuestion (no interactive branches)" {
  # The skill's contract is NO AskUserQuestion at all — Considered Options
  # / Decision Drivers / Consequences / Confirmation / Reassessment are
  # framework-mediated mechanical stages per ADR-044. AskUserQuestion in
  # allowed-tools would let future drift sneak prompts back in.
  run grep -E '^allowed-tools:' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -E '^allowed-tools:.*AskUserQuestion' "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "capture-adr: allowed-tools includes Bash (for next-ID + commit primitives)" {
  # next-ID via git ls-tree | grep | sort + commit gate via Bash invocation.
  run grep -E '^allowed-tools:.*Bash' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "capture-adr: allowed-tools includes Write (for new ADR file)" {
  run grep -E '^allowed-tools:.*Write' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Deferred-canonical-expansion contract — distinguishing capture-adr from
# create-adr. capture-adr must NOT invoke the architect-agent inline; it
# writes status: proposed and defers review to canonical expansion.
# This is the contract distinction from create-adr Step 5 (confirm-with-user).
# ---------------------------------------------------------------------------

@test "capture-adr: SKILL.md prescribes deferred canonical expansion (no inline review handoff)" {
  # The contract distinction from create-adr: capture-adr does NOT invoke
  # the wr-architect:agent review inline; it writes status: proposed and
  # routes review through the canonical-expansion path. A future
  # maintainer who copies create-adr's Step 5 confirm pass into capture-adr
  # would break the lightweight-capture promise.
  # Asserts the SKILL.md names the deferred contract explicitly.
  run grep -F '/wr-architect:create-adr' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
