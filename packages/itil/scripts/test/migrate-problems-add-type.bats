#!/usr/bin/env bats

# @problem P170 — Slice 4 B7.T2 (item 8b): bulk-migrate existing
# problem tickets to the type-tag schema with default `type: technical`.
# Script-driven, idempotent, no per-ticket judgement (per ADR-060
# § Type-tag schema migration line; architect finding 10 split).
#
# @adr ADR-060 (type-tag schema introduction; Phase 1 item 8b)
# @adr ADR-052 (behavioural bats default; observable file-state
#   assertions, not source greps per P081)
# @adr ADR-014 (single-purpose script; one mechanical migration)
#
# Contract:
#   - Input: a problems-dir containing `<NNN>-*.<status>.md` files.
#   - Diagnose mode (default): exit 0 if every ticket carries
#     `**Type**: <value>` body field; exit 1 if any ticket needs
#     migration (tickets needing migration listed on stdout, one per
#     line, ≤150 bytes per ADR-038 progressive disclosure budget).
#   - Apply mode (--apply flag): inserts `**Type**: technical` after
#     the LAST present body field marker among
#     `**Status**` / `**Reported**` / `**Priority**` / `**Effort**` /
#     `**WSJF**`. Idempotent (re-running is no-op).
#   - Tickets with no recognisable header field block are skipped with
#     a `SKIP` line on stderr (does not fail the run).
#   - Default value: `technical` per ADR-060 line 92.

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/migrate-problems-add-type.sh"
  FIXTURE_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

write_ticket() {
  local id="$1" slug="$2" status="$3" body="$4"
  local file="$FIXTURE_DIR/${id}-${slug}.${status}.md"
  printf '%s' "$body" > "$file"
  echo "$file"
}

# ── Existence + executable ──────────────────────────────────────────────────

@test "migrate-problems-add-type: script exists" {
  [ -f "$SCRIPT" ]
}

@test "migrate-problems-add-type: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── Diagnose mode (default) ──────────────────────────────────────────────────

@test "diagnose: exit 0 when every ticket already carries Type field" {
  write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**Type**: technical
EOF
)"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
}

@test "diagnose: exit 1 when at least one ticket lacks Type field" {
  write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**WSJF**: 5.0
EOF
)"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
}

@test "diagnose: lists each ticket needing migration on stdout" {
  write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**WSJF**: 5.0
EOF
)"
  write_ticket "101" "bar" "closed" "$(cat <<'EOF'
# Problem 101: Bar

**Status**: Closed
**Priority**: 6
EOF
)"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '100-foo'
  echo "$output" | grep -q '101-bar'
}

@test "diagnose: read-only — does not mutate any ticket file" {
  ticket=$(write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**WSJF**: 5.0
EOF
)")
  hash_before=$(shasum "$ticket" | cut -d' ' -f1)
  run bash "$SCRIPT" "$FIXTURE_DIR"
  hash_after=$(shasum "$ticket" | cut -d' ' -f1)
  [ "$hash_before" = "$hash_after" ]
}

# ── Apply mode (--apply) ─────────────────────────────────────────────────────

@test "apply: inserts Type: technical after WSJF line when WSJF present" {
  ticket=$(write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**WSJF**: 5.0

## Description
EOF
)")
  run bash "$SCRIPT" --apply "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  grep -q '^\*\*Type\*\*: technical$' "$ticket"
  # Type sits AFTER WSJF (highest field marker present).
  wsjf_line=$(grep -n '^\*\*WSJF\*\*:' "$ticket" | head -1 | cut -d: -f1)
  type_line=$(grep -n '^\*\*Type\*\*:' "$ticket" | head -1 | cut -d: -f1)
  [ "$type_line" -gt "$wsjf_line" ]
}

@test "apply: inserts Type after Effort when WSJF absent" {
  ticket=$(write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**Reported**: 2026-01-01
**Priority**: 6
**Effort**: M

## Description
EOF
)")
  run bash "$SCRIPT" --apply "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  effort_line=$(grep -n '^\*\*Effort\*\*:' "$ticket" | head -1 | cut -d: -f1)
  type_line=$(grep -n '^\*\*Type\*\*:' "$ticket" | head -1 | cut -d: -f1)
  [ "$type_line" -gt "$effort_line" ]
}

@test "apply: inserts Type after Priority when WSJF + Effort absent" {
  ticket=$(write_ticket "100" "foo" "closed" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Closed
**Priority**: 6

## Description
EOF
)")
  run bash "$SCRIPT" --apply "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  priority_line=$(grep -n '^\*\*Priority\*\*:' "$ticket" | head -1 | cut -d: -f1)
  type_line=$(grep -n '^\*\*Type\*\*:' "$ticket" | head -1 | cut -d: -f1)
  [ "$type_line" -gt "$priority_line" ]
}

@test "apply: idempotent — re-running with Type already present is no-op" {
  ticket=$(write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**WSJF**: 5.0

## Description
EOF
)")
  bash "$SCRIPT" --apply "$FIXTURE_DIR"
  hash1=$(shasum "$ticket" | cut -d' ' -f1)
  bash "$SCRIPT" --apply "$FIXTURE_DIR"
  hash2=$(shasum "$ticket" | cut -d' ' -f1)
  [ "$hash1" = "$hash2" ]
}

@test "apply: default value is 'technical'" {
  ticket=$(write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

**Status**: Open
**WSJF**: 5.0
EOF
)")
  bash "$SCRIPT" --apply "$FIXTURE_DIR"
  grep -q '^\*\*Type\*\*: technical$' "$ticket"
  ! grep -q '^\*\*Type\*\*: user-business$' "$ticket"
}

@test "apply: handles all five lifecycle file extensions" {
  i=100
  for state in open known-error verifying parked closed; do
    write_ticket "$i" "t-${state}" "$state" "$(cat <<EOF
# Problem $i: stub

**Status**: stub
**WSJF**: 5.0
EOF
)" > /dev/null
    i=$((i+1))
  done
  bash "$SCRIPT" --apply "$FIXTURE_DIR"
  count=$(grep -l '^\*\*Type\*\*: technical$' "$FIXTURE_DIR"/*.md | wc -l | tr -d ' ')
  [ "$count" -eq 5 ]
}

@test "apply: preserves all original content (line-count grows by exactly 1 per migrated ticket)" {
  # Use printf with explicit trailing newline to mirror real ticket-file
  # convention (POSIX text-file trailing newline). awk normalizes EOF
  # to a trailing newline; fixture must match so the +1-line invariant
  # holds.
  ticket="$FIXTURE_DIR/100-foo.open.md"
  printf '%s\n' \
    '# Problem 100: Foo' \
    '' \
    '**Status**: Open' \
    '**WSJF**: 5.0' \
    '' \
    '## Description' \
    '' \
    'Body text line.' \
    '' \
    '## Related' \
    '' \
    'stub' > "$ticket"
  before=$(wc -l < "$ticket" | tr -d ' ')
  bash "$SCRIPT" --apply "$FIXTURE_DIR"
  after=$(wc -l < "$ticket" | tr -d ' ')
  [ "$after" -eq "$((before + 1))" ]
  # Original content sentinels survive.
  grep -q '^# Problem 100: Foo$' "$ticket"
  grep -q '^## Description$' "$ticket"
  grep -q '^Body text line\.$' "$ticket"
  grep -q '^## Related$' "$ticket"
}

# ── Skip / malformed handling ────────────────────────────────────────────────

@test "apply: skips ticket with no recognisable header field block (warning to stderr)" {
  ticket=$(write_ticket "100" "foo" "open" "$(cat <<'EOF'
# Problem 100: Foo

Just a body, no field markers at all.
EOF
)")
  hash_before=$(shasum "$ticket" | cut -d' ' -f1)
  run bash "$SCRIPT" --apply "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  hash_after=$(shasum "$ticket" | cut -d' ' -f1)
  [ "$hash_before" = "$hash_after" ]
  # SKIP marker on stderr.
  echo "$output" | grep -qi 'skip'
}

# ── Default problems-dir ─────────────────────────────────────────────────────

@test "diagnose: defaults problems-dir to ./docs/problems when no arg given" {
  cd "$FIXTURE_DIR"
  mkdir -p docs/problems
  cat > docs/problems/100-foo.open.md <<'EOF'
# Problem 100: Foo

**Status**: Open
**Type**: technical
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
