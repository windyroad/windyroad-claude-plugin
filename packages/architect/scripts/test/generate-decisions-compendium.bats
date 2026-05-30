#!/usr/bin/env bats

# ADR-077: generate-decisions-compendium.sh emits a derived `README.md` index
# of every ADR's chosen option, confirmation criteria, and relationships.
# Behavioural — exercises the script against fixture trees and against the
# live committed state, asserts on its exit codes and stdout/file output.
#
# Confirmation item (g): CI drift-detection bats — defence-in-depth in case
# the `architect-compendium-refresh-discipline.sh` PreToolUse hook fails
# open or is bypassed.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="$REPO_ROOT/packages/architect/scripts/generate-decisions-compendium.sh"
  DIR="$(mktemp -d)"
  mkdir -p "$DIR/docs/decisions"
}

teardown() {
  rm -rf "$DIR"
}

# mk_adr <filename> <status> <title> [extra-frontmatter-lines...]
# Writes a minimal MADR-shaped ADR with frontmatter + title + the three
# sections the generator extracts: Decision Outcome, Confirmation, Related.
mk_adr() {
  local name="$1" status="$2" title="$3"
  shift 3
  {
    echo "---"
    echo "status: \"$status\""
    echo "date: 2026-05-30"
    for line in "$@"; do echo "$line"; done
    echo "---"
    echo ""
    echo "# $title"
    echo ""
    echo "## Decision Outcome"
    echo ""
    echo "Chosen option: **\"$title implementation\"**, because reasons."
    echo ""
    echo "## Confirmation"
    echo ""
    echo "- [ ] (a) First confirmation item for $title."
    echo "- [ ] (b) Second confirmation item for $title."
    echo ""
    echo "## Related"
    echo ""
    echo "- Relates to [ADR-001](001-foo.proposed.md)"
  } > "$DIR/docs/decisions/$name"
}

# --- ADR-077 (g) drift-detection contract on the live committed state -------

@test "committed compendium matches generator output (CI drift gate)" {
  # This is the load-bearing assertion from ADR-077 (g): the committed
  # docs/decisions/README.md MUST match what the generator produces from
  # the current docs/decisions/<NNN>-*.md bodies. If this fails in CI, the
  # safety-net hook either failed open or was bypassed.
  cd "$REPO_ROOT"
  run bash "$SCRIPT" --check docs/decisions
  [ "$status" -eq 0 ]
}

# --- Idempotency (ADR-077 (b) re-asserted) ----------------------------------

@test "generator is idempotent — two runs produce byte-identical output" {
  mk_adr "010-alpha.proposed.md" "proposed" "Alpha"
  mk_adr "011-beta.accepted.md" "accepted" "Beta"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  cp "$DIR/docs/decisions/README.md" "$DIR/first.md"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  run cmp -s "$DIR/first.md" "$DIR/docs/decisions/README.md"
  [ "$status" -eq 0 ]
}

# --- Drift detection on fixture (mutated ADR body) --------------------------

@test "--check exits 1 when an ADR body is mutated after generation" {
  mk_adr "010-alpha.proposed.md" "proposed" "Alpha"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  # Mutate the Decision Outcome — committed compendium now stale.
  sed -i.bak 's/Alpha implementation/Alpha REVISED outcome/' \
    "$DIR/docs/decisions/010-alpha.proposed.md"
  rm "$DIR/docs/decisions/010-alpha.proposed.md.bak"
  run bash "$SCRIPT" --check "$DIR/docs/decisions"
  [ "$status" -eq 1 ]
  # The stderr advice should name the regen command for mechanical recovery.
  [[ "$output" == *"wr-architect-generate-decisions-compendium"* ]]
}

@test "--check exits 1 when compendium is missing entirely" {
  mk_adr "010-alpha.proposed.md" "proposed" "Alpha"
  run bash "$SCRIPT" --check "$DIR/docs/decisions"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING"* || "$output" == *"missing"* || "$output" == *"does not exist"* ]]
}

@test "--check exits 0 on a freshly-generated set (in sync)" {
  mk_adr "010-alpha.proposed.md" "proposed" "Alpha"
  mk_adr "011-beta.accepted.md" "accepted" "Beta"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  run bash "$SCRIPT" --check "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
}

# --- Section split (ADR-077 amendment 2026-05-30 two-section format) --------

@test "compendium splits in-force (proposed+accepted) from historical (superseded+rejected+deprecated)" {
  mk_adr "010-alpha.proposed.md"    "proposed"   "Alpha In-Force"
  mk_adr "011-beta.accepted.md"     "accepted"   "Beta In-Force"
  mk_adr "012-gamma.superseded.md"  "superseded" "Gamma Historical"
  mk_adr "013-delta.rejected.md"    "rejected"   "Delta Historical"
  mk_adr "014-eps.deprecated.md"    "deprecated" "Eps Historical"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  local out="$DIR/docs/decisions/README.md"
  grep -q '^## In-force decisions$' "$out"
  grep -q '^## Historical decisions$' "$out"
  # In-force section appears before historical section.
  local in_force_line historical_line
  in_force_line=$(grep -n '^## In-force decisions$' "$out" | cut -d: -f1)
  historical_line=$(grep -n '^## Historical decisions$' "$out" | cut -d: -f1)
  [ "$in_force_line" -lt "$historical_line" ]
  # Header tally reflects the partition.
  grep -q '^\*\*Total ADRs:\*\* 5 (2 in-force, 3 historical)$' "$out"
}

@test "compendium omits historical section when there are no historical ADRs" {
  mk_adr "010-alpha.proposed.md" "proposed" "Alpha"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  local out="$DIR/docs/decisions/README.md"
  grep -q '^## In-force decisions$' "$out"
  ! grep -q '^## Historical decisions$' "$out"
  grep -q '^\*\*Total ADRs:\*\* 1 (1 in-force, 0 historical)$' "$out"
}

# --- Output deterministic (no timestamp / no date in header) ----------------

@test "header carries no timestamp or date — output stays idempotent across days" {
  mk_adr "010-alpha.proposed.md" "proposed" "Alpha"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  local out="$DIR/docs/decisions/README.md"
  # The README.md never embeds a YYYY-MM-DD or HH:MM stamp at the top —
  # idempotency would break otherwise (drift bats would flag day-by-day
  # churn instead of substance drift).
  ! head -10 "$out" | grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}'
  ! head -10 "$out" | grep -qE '[0-9]{2}:[0-9]{2}'
}

# --- Per-ADR entry shape ----------------------------------------------------

@test "each ADR emits ID + Title + Status + Chosen + Confirmation + Related" {
  mk_adr "042-test.accepted.md" "accepted" "Test Entry"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  local out="$DIR/docs/decisions/README.md"
  grep -q '^### ADR-042 — Test Entry$' "$out"
  grep -q '^\*\*Status:\*\* accepted' "$out"
  grep -q '^\*\*Chosen:\*\* Chosen option: ' "$out"
  grep -q '^\*\*Confirmation:\*\* ' "$out"
  # Related extraction collapses to ADR-NNN ID list.
  grep -q '^\*\*Related:\*\* ADR-001$' "$out"
}

# --- Error handling ---------------------------------------------------------

@test "missing decisions dir exits 2 with a clear error" {
  run bash "$SCRIPT" "$DIR/docs/nonexistent"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* || "$output" == *"does not exist"* ]]
}

@test "README.md is excluded from the ADR set (never recurses into itself)" {
  # If README.md were treated as an ADR, the compendium would grow on every
  # run — idempotency would break catastrophically.
  mk_adr "010-alpha.proposed.md" "proposed" "Alpha"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  cp "$DIR/docs/decisions/README.md" "$DIR/first.md"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  run cmp -s "$DIR/first.md" "$DIR/docs/decisions/README.md"
  [ "$status" -eq 0 ]
  # The "Total ADRs:" tally must still be 1, not 2.
  grep -q '^\*\*Total ADRs:\*\* 1 ' "$DIR/docs/decisions/README.md"
}

# --- Oversight marker projection (ADR-077 (i) authoritative-state) ----------

@test "human-oversight: confirmed surfaces as an Oversight badge" {
  mk_adr "010-conf.proposed.md" "proposed" "Confirmed Entry" \
    "human-oversight: confirmed" \
    "oversight-date: 2026-05-30"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  grep -q '^\*\*Status:\*\* proposed | \*\*Oversight:\*\* confirmed' \
    "$DIR/docs/decisions/README.md"
}

@test "rejected-pending-supersede surfaces with the supersede ticket in the badge (P316 amendment)" {
  mk_adr "010-rej.proposed.md" "proposed" "Rejected Entry" \
    "human-oversight: rejected-pending-supersede" \
    "supersede-ticket: P297"
  bash "$SCRIPT" "$DIR/docs/decisions" >/dev/null 2>&1
  grep -q 'Oversight:\*\* rejected-pending-supersede (P297)' \
    "$DIR/docs/decisions/README.md"
}
