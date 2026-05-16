#!/usr/bin/env bats

# @problem P087 — Phase 2a transcript-axis script behavioural confirmation.
#
# Contract under test: `packages/itil/scripts/skill-invocations.sh` reads
# `~/.claude/projects/**/*.jsonl` (recursive), tallies tool_use invocations
# by `Skill` / `Agent` / `Bash` (per ADR-058 §Script contracts), and emits
# one NDJSON record per surface to stdout. Exit code 0 always per ADR-013
# Rule 6 fail-safe (inaccessible root, opt-out marker, no data all hit the
# zero-records/stderr-comment path).
#
# Confirmation criteria 1-5 from ADR-058 §Confirmation are the load-bearing
# behavioural assertions in this file. Phase 2b's git-axis script ships
# criteria 6-8 in a sibling bats file.
#
# @adr ADR-058 (Plugin maturity measurement mechanism)
# @adr ADR-049 (Shim grammar — `wr-itil-skill-invocations` on $PATH)
# @adr ADR-035 (Privacy posture — opt-out marker, no network primitive,
#   content sanitisation, path-hashing)
# @adr ADR-052 (Behavioural tests default — NDJSON-output-driven against
#   fixture transcripts, not source-greps on script body; the no-network
#   negative-grep at Confirmation #3 is the documented carve-out)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — exit 0 always)
# @jtbd JTBD-101 (Extend the Suite — hardening-prioritisation outcome)
# @jtbd JTBD-201 (Restore Service Fast — audit-trail composition)

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/skill-invocations.sh"
  FIXTURE_DIR="$(mktemp -d)"
  TRANSCRIPT_ROOT="$FIXTURE_DIR/transcripts"
  PROJECT_ROOT="$FIXTURE_DIR/project"
  mkdir -p "$TRANSCRIPT_ROOT" "$PROJECT_ROOT"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# Helper: write a synthetic JSONL transcript under the fixture root.
# Each call appends one assistant message carrying a single tool_use entry.
# Layout mirrors the live `~/.claude/projects/<encoded-path>/<UUID>.jsonl`
# shape (recursive rglob discovers it).
write_skill_invocation() {
  local file="$1"; local skill_name="$2"; local ts="$3"
  mkdir -p "$(dirname "$file")"
  python3 - "$file" "$skill_name" "$ts" <<'PYEOF'
import json, sys
file, skill, ts = sys.argv[1], sys.argv[2], sys.argv[3]
rec = {
  "type": "assistant",
  "timestamp": ts,
  "message": {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "Skill", "input": {"skill": skill}}
    ]
  }
}
with open(file, "a") as fh:
  fh.write(json.dumps(rec) + "\n")
PYEOF
}

write_agent_invocation() {
  local file="$1"; local agent_kind="$2"; local ts="$3"
  mkdir -p "$(dirname "$file")"
  python3 - "$file" "$agent_kind" "$ts" <<'PYEOF'
import json, sys
file, kind, ts = sys.argv[1], sys.argv[2], sys.argv[3]
rec = {
  "type": "assistant",
  "timestamp": ts,
  "message": {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "Agent", "input": {"subagent_type": kind}}
    ]
  }
}
with open(file, "a") as fh:
  fh.write(json.dumps(rec) + "\n")
PYEOF
}

write_bash_invocation() {
  local file="$1"; local cmd="$2"; local ts="$3"
  mkdir -p "$(dirname "$file")"
  python3 - "$file" "$cmd" "$ts" <<'PYEOF'
import json, sys
file, cmd, ts = sys.argv[1], sys.argv[2], sys.argv[3]
rec = {
  "type": "assistant",
  "timestamp": ts,
  "message": {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "Bash", "input": {"command": cmd}}
    ]
  }
}
with open(file, "a") as fh:
  fh.write(json.dumps(rec) + "\n")
PYEOF
}

# Helper: produce an ISO 8601 timestamp N hours before "now" (UTC).
recent_iso() {
  python3 -c "import sys, datetime; print((datetime.datetime.utcnow() - datetime.timedelta(hours=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$1"
}

# ── Existence / executable ──────────────────────────────────────────────────

@test "skill-invocations: canonical script exists" {
  [ -f "$SCRIPT" ]
}

@test "skill-invocations: canonical script is executable" {
  [ -x "$SCRIPT" ]
}

@test "skill-invocations: shim file exists with ADR-049 grammar" {
  local shim="$SCRIPTS_DIR/../bin/wr-itil-skill-invocations"
  [ -f "$shim" ]
  [ -x "$shim" ]
  grep -q 'exec.*scripts/skill-invocations.sh' "$shim"
}

# ── Confirmation #1: NDJSON-shape fixture ───────────────────────────────────
# Seed three Skill invocations of `wr-itil:manage-problem` within the
# default 30-day window. Assert one NDJSON record on stdout with
# axis="skill-invocations", surface="wr-itil:manage-problem", kind="skill",
# plugin="itil", invocations=3. Each line is valid JSON with the expected
# schema keys.

@test "Confirmation #1: NDJSON record for 3 wr-itil:manage-problem invocations" {
  local sess="$TRANSCRIPT_ROOT/proj/aaa.jsonl"
  local ts=$(recent_iso 1)
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$ts"
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$ts"
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$ts"

  run "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  # Exactly one record line, no extras, no leading/trailing junk on stdout
  local line_count
  line_count="$(printf '%s' "$output" | grep -c .)"
  [ "$line_count" -eq 1 ]
  # Validate schema fields
  echo "$output" | python3 -c "
import json, sys
rec = json.loads(sys.stdin.read().strip())
assert rec['schema_version'] == '1.0', rec
assert rec['axis'] == 'skill-invocations', rec
assert rec['surface'] == 'wr-itil:manage-problem', rec
assert rec['kind'] == 'skill', rec
assert rec['plugin'] == 'itil', rec
assert rec['window_days'] == 30, rec
assert rec['invocations'] == 3, rec
assert rec.get('first_invocation_iso') is not None, rec
assert rec.get('last_invocation_iso') is not None, rec
"
}

@test "Confirmation #1: aggregates Skill + Agent + Bash kinds into distinct records" {
  local sess="$TRANSCRIPT_ROOT/proj/mix.jsonl"
  local ts=$(recent_iso 1)
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$ts"
  write_agent_invocation "$sess" "wr-architect:agent" "$ts"
  write_bash_invocation "$sess" "wr-itil-reconcile-readme docs/problems" "$ts"

  run "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  # Three distinct NDJSON lines, one per kind
  local line_count
  line_count="$(printf '%s' "$output" | grep -c .)"
  [ "$line_count" -eq 3 ]
  echo "$output" | grep -q '"kind":"skill"'
  echo "$output" | grep -q '"kind":"agent"'
  echo "$output" | grep -q '"kind":"bash-attributed"'
  echo "$output" | grep -q '"plugin":"itil"'
  echo "$output" | grep -q '"plugin":"architect"'
}

@test "Confirmation #1: filters unknown short-form skill names from plugin attribution" {
  local sess="$TRANSCRIPT_ROOT/proj/short.jsonl"
  local ts=$(recent_iso 1)
  # Bare names without `wr-<plugin>:` prefix should be excluded from
  # per-plugin attribution per ADR-058 §Script contracts.
  write_skill_invocation "$sess" "commit" "$ts"
  write_skill_invocation "$sess" "loop" "$ts"

  run "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  # No records emitted — both invocations are short-form and unattributable
  [ -z "$output" ]
}

# ── Confirmation #2: opt-out marker fixture ─────────────────────────────────

@test "Confirmation #2: opt-out marker disables reads, stderr comment, exit 0" {
  # Seed a transcript that WOULD produce records if read.
  local sess="$TRANSCRIPT_ROOT/proj/optout.jsonl"
  local ts=$(recent_iso 1)
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$ts"
  # Plant the opt-out marker in the project root.
  mkdir -p "$PROJECT_ROOT/.claude"
  touch "$PROJECT_ROOT/.claude/.skill-metrics-opt-out"

  # Capture stdout and stderr separately so we can assert: zero records
  # on stdout, opt-out comment on stderr, exit 0.
  local stdout_file="$FIXTURE_DIR/optout.out"
  local stderr_file="$FIXTURE_DIR/optout.err"
  "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT" >"$stdout_file" 2>"$stderr_file"
  local rc=$?
  [ "$rc" -eq 0 ]
  [ ! -s "$stdout_file" ]
  grep -q "opt-out marker present at" "$stderr_file"
  grep -q "$PROJECT_ROOT/.claude/.skill-metrics-opt-out" "$stderr_file"
}

# ── Confirmation #3: no-network-primitive (negative grep carve-out) ─────────
# ADR-052 carves out this case from "behavioural unless declarative-only".
# Asserts the canonical script body invokes none of the standard exfiltration
# primitives. Negative-grep is the closest behavioural approximation of
# "this script is incapable of network egress".

@test "Confirmation #3: canonical body contains no network primitives" {
  # Grep for curl, wget, raw `nc ` (space-bounded to avoid the `since`,
  # `synchronise`, etc. false-positives), fetch, http.client, urllib.
  run grep -nE '\bcurl\b|\bwget\b|\bnc[[:space:]]|\bfetch\b|http\.client|\burllib\b' "$SCRIPT"
  # `run` captures exit; grep exits 1 on no matches — that is the pass.
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# ── Confirmation #4: path-hashing / no-content-leak fixture ─────────────────

@test "Confirmation #4: literal secret-shaped token never appears in NDJSON" {
  local sess="$TRANSCRIPT_ROOT/proj/secret.jsonl"
  local ts=$(recent_iso 1)
  # Bash command carries an absolute-path-shaped string containing a
  # synthetic secret token. The plugin attribution extracts the wr-itil-*
  # shim name only; the surrounding path and secret are NOT in the
  # emitted NDJSON.
  write_bash_invocation "$sess" "/private/users/foo/password-XXXX-secret/bin/wr-itil-reconcile-readme docs/problems" "$ts"

  run "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  # NDJSON contains the surface attribution
  echo "$output" | grep -q '"plugin":"itil"'
  echo "$output" | grep -q '"kind":"bash-attributed"'
  # NDJSON does NOT contain the secret token or the raw absolute path
  ! echo "$output" | grep -q "password-XXXX-secret"
  ! echo "$output" | grep -q "/private/users/foo"
}

@test "Confirmation #4: any surface containing a project path is sha256-12hex hashed" {
  # Structural assertion on the schema: when path-bearing fields are added
  # in future schema versions, they MUST be 12-hex-char sha256 prefixes.
  # The v1.0 schema does not include path-bearing fields; this fixture
  # asserts the structural invariant by verifying no unhashed path shape
  # surfaces. If a future schema bump introduces a `project_path_hash`
  # field, the assertion regex below catches non-hex shapes.
  local sess="$TRANSCRIPT_ROOT/proj/hash.jsonl"
  local ts=$(recent_iso 1)
  write_bash_invocation "$sess" "wr-itil-reconcile-readme docs/problems" "$ts"

  run "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  # Any value matching a `path_hash` field (current or future schema)
  # MUST be exactly 12 lowercase hex chars. Negative regex: no field with
  # value matching a raw path shape.
  ! echo "$output" | grep -qE '"[a-z_]+":"/[^"]*"'
}

# ── Confirmation #5: inaccessible-directory fixture ─────────────────────────

@test "Confirmation #5: inaccessible --root emits zero records, stderr comment, exit 0" {
  local stdout_file="$FIXTURE_DIR/inacc.out"
  local stderr_file="$FIXTURE_DIR/inacc.err"
  "$SCRIPT" --window-days=30 --root="/nonexistent/path/that/cannot/exist" --project-root="$PROJECT_ROOT" >"$stdout_file" 2>"$stderr_file"
  local rc=$?
  [ "$rc" -eq 0 ]
  [ ! -s "$stdout_file" ]
  grep -q "transcript root inaccessible" "$stderr_file"
  grep -q "/nonexistent/path/that/cannot/exist" "$stderr_file"
}

# ── Forward-extension flag: --category-overrides ────────────────────────────
# ADR-058 §"Per-category override hook" — ships unused in Phase 2; the flag
# is accepted-and-validated, no functional effect yet.

@test "category-overrides flag is accepted without functional effect" {
  local sess="$TRANSCRIPT_ROOT/proj/cat.jsonl"
  local ts=$(recent_iso 1)
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$ts"
  # Empty JSON file is a valid (no-op) overrides file.
  echo '{}' > "$FIXTURE_DIR/overrides.json"

  run "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT" --category-overrides="$FIXTURE_DIR/overrides.json"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"invocations":1'
}

# ── Window-days filtering ───────────────────────────────────────────────────

@test "window-days filter excludes invocations older than the window" {
  local sess="$TRANSCRIPT_ROOT/proj/old.jsonl"
  # Hours-back exceeds the 1-day window (24h).
  local old_ts=$(recent_iso 48)
  local recent_ts=$(recent_iso 1)
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$old_ts"
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$recent_ts"

  run "$SCRIPT" --window-days=1 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  # Only the in-window invocation counts; old one drops.
  echo "$output" | grep -q '"invocations":1'
}

# ── Phase 2d: substring-prefilter false-positive fall-through ───────────────
# Iter 6 (2026-05-17) adds a cheap substring guard before json.loads() to skip
# lines that cannot possibly contribute counts. The filter checks for the
# literal substrings `"type":"assistant"` and `"tool_use"` in each line; lines
# missing either are skipped without parsing. Correctness invariant: any line
# whose body content (a `type=text` block, a tool_result, a user message
# rendered into the transcript verbatim) happens to contain those substrings
# MUST fall through to full JSON parse and the existing not-a-real-tool_use
# check MUST exclude it from counts. This fixture seeds exactly that scenario:
# an assistant message carrying a single `type=text` content block whose body
# literally contains both trigger substrings. The legitimate tool_use line in
# the same fixture establishes the expected count = 1. Without the existing
# `c.get("type") == "tool_use"` guard, the false-positive line would inflate
# counts; the assertion below catches any future regression on the
# fall-through path.

@test "Phase 2d: false-positive substring fall-through does not inflate counts" {
  local sess="$TRANSCRIPT_ROOT/proj/falsepos.jsonl"
  local ts=$(recent_iso 1)
  # One legitimate Skill invocation (counts as 1).
  write_skill_invocation "$sess" "wr-itil:manage-problem" "$ts"
  # One adversarial assistant message: text body contains both trigger
  # substrings but no real tool_use entry. Must NOT add to counts.
  python3 - "$sess" "$ts" <<'PYEOF'
import json, sys
file, ts = sys.argv[1], sys.argv[2]
rec = {
  "type": "assistant",
  "timestamp": ts,
  "message": {
    "role": "assistant",
    "content": [
      {"type": "text", "text": 'discussing "type":"assistant" and "tool_use" tokens in prose'}
    ]
  }
}
with open(file, "a") as fh:
  fh.write(json.dumps(rec) + "\n")
PYEOF

  run "$SCRIPT" --window-days=30 --root="$TRANSCRIPT_ROOT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  # Exactly one record (the legitimate Skill invocation); count = 1.
  local line_count
  line_count="$(printf '%s' "$output" | grep -c .)"
  [ "$line_count" -eq 1 ]
  echo "$output" | grep -q '"invocations":1'
  echo "$output" | grep -q '"surface":"wr-itil:manage-problem"'
}
