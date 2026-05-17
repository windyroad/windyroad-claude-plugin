#!/usr/bin/env bats

# @problem P249 — no process for issue reporters to check for responses
# (symmetric gap to ADR-062 inbound discovery). Phase 1: us-as-upstream-
# reporter side — scan local tickets for `## Reported Upstream` back-
# link sections (written by `/wr-itil:report-upstream` Step 7), poll
# each upstream issue via `gh issue view`, diff against cache, surface
# new comments / state changes / label changes.
#
# Contract: `check-upstream-responses.sh [--problems-dir <dir>]
# [--cache-file <path>] [--audit-log <path>] [--force-recheck]
# [--ticket P<NNN>] [--gh-bin <path>]` is a foreground governance
# script that polls upstream issues, writes cache + audit-log, and
# emits a structured one-line-per-ticket report to stdout.
#
# Read-soft externally: only `gh issue view` (read-only) — no
# `gh issue comment` / `gh issue create`. Does NOT trip ADR-028
# external-comms gate. AFK-safe.
#
# Cache: `docs/problems/.outbound-responses-cache.json` (mirrors
# ADR-062 inbound cache shape under same dir per ADR-031 §"Cache
# files live under docs/problems/"). Committed for replay
# determinism; rebuild via --force-recheck.
#
# Audit-log: `docs/audits/outbound-responses-log.md` (mirrors
# ADR-062 inbound audit-log under docs/audits/ per CLAUDE.md P131).
#
# Exit codes:
#   0 = success (zero or more new responses surfaced; check stdout
#       for per-ticket lines)
#   1 = error (cache file malformed, upstream URL malformed, gh CLI
#       missing, problems-dir not found)
#   2 = partial — some upstream polls failed (network / 404); the
#       successful ones are still written to cache + audit-log
#
# Structured stdout format (≤ 150 bytes per line per ADR-038
# progressive-disclosure budget):
#   NEW     P<NNN> <url> state=<state> new-comments=<N>
#   STATE   P<NNN> <url> state=<old>→<new>
#   LABEL   P<NNN> <url> labels-added=<csv> labels-removed=<csv>
#   NONE    P<NNN> <url> no-change-since=<last-checked>
#   SKIP    P<NNN> reason=no-reported-upstream-section
#   FAIL    P<NNN> <url> reason=<gh-error-short>
#
# @adr ADR-014 (governance skills commit their own work — cache +
# audit-log ride one commit per pass)
# @adr ADR-024 (back-link source of truth — `## Reported Upstream`
# URL field is what this script reads)
# @adr ADR-031 (cache file placement under docs/problems/)
# @adr ADR-032 (foreground synchronous skill — no AskUserQuestion)
# @adr ADR-038 (progressive disclosure — per-row byte budget on diff)
# @adr ADR-049 (script invoked via wr-itil-check-upstream-responses
# bin shim from SKILL.md)
# @adr ADR-062 (inbound discovery pattern — this script is the
# outbound symmetric counterpart)
# @jtbd JTBD-004 (cross-repo coordination — primary anchor)
# @jtbd JTBD-006 (AFK-safe surface)
# @jtbd JTBD-001 (governance without slowing down — eliminates
# manual upstream polling)
# @jtbd JTBD-201 (audit trail — outbound-responses-log.md replay)

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/check-upstream-responses.sh"
  FIXTURE_DIR="$(mktemp -d)"
  PROBLEMS_DIR="$FIXTURE_DIR/problems"
  AUDITS_DIR="$FIXTURE_DIR/audits"
  GHFAKE_DIR="$FIXTURE_DIR/ghfake"
  mkdir -p "$PROBLEMS_DIR" "$AUDITS_DIR" "$GHFAKE_DIR"
  CACHE_FILE="$PROBLEMS_DIR/.outbound-responses-cache.json"
  AUDIT_LOG="$AUDITS_DIR/outbound-responses-log.md"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# ── Helper: install a fake `gh` binary that prints a canned JSON
# ── response keyed by upstream URL. Tests prime $GHFAKE_DIR/<url-hash>
# ── with the JSON they want returned.

make_fake_gh() {
  cat > "$GHFAKE_DIR/gh" <<'EOF'
#!/usr/bin/env bash
# Fake gh shim. Recognised invocations:
#   gh issue view <url> --json comments,state,labels,updatedAt
# Looks up canned response by url-hash from $GHFAKE_DATA dir.
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  URL="$3"
  HASH=$(echo -n "$URL" | shasum | awk '{print $1}')
  if [ -f "$GHFAKE_DATA/$HASH.json" ]; then
    cat "$GHFAKE_DATA/$HASH.json"
    exit 0
  else
    echo "could not resolve issue: $URL" >&2
    exit 1
  fi
fi
echo "fake-gh: unrecognised invocation: $*" >&2
exit 1
EOF
  chmod +x "$GHFAKE_DIR/gh"
}

prime_gh_response() {
  local url="$1"
  local payload="$2"
  local hash
  hash=$(echo -n "$url" | shasum | awk '{print $1}')
  printf '%s' "$payload" > "$GHFAKE_DIR/$hash.json"
}

# ── Existence + executable ──────────────────────────────────────────────────

@test "check-upstream-responses: script exists" {
  [ -f "$SCRIPT" ]
}

@test "check-upstream-responses: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── Behavioural: ticket with `## Reported Upstream` is polled ───────────────

@test "ticket with Reported Upstream section is polled and surfaces NEW state on first check" {
  cat > "$PROBLEMS_DIR/100-foo.open.md" <<'EOF'
# Problem 100: Foo

**Status**: Open

## Description

Some description.

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/42
- **Reported**: 2026-05-01
- **Template used**: bug_report.yml
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/42" '{"state":"OPEN","comments":[{"id":1,"author":{"login":"someone"},"createdAt":"2026-05-10T10:00:00Z","body":"thanks"}],"labels":[{"name":"triage"}],"updatedAt":"2026-05-10T10:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^NEW *P100"
  echo "$output" | grep -q "https://github.com/example/repo/issues/42"
}

# ── Behavioural: ticket without Reported Upstream is skipped ────────────────

@test "ticket without Reported Upstream section is skipped" {
  cat > "$PROBLEMS_DIR/101-bar.open.md" <<'EOF'
# Problem 101: Bar

**Status**: Open

## Description

No upstream link here.
EOF

  make_fake_gh
  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  # P101 should not appear in output at all (no Reported Upstream → silently skipped).
  ! echo "$output" | grep -q "P101"
}

# ── Behavioural: cache fresh → no new responses surfaced ────────────────────

@test "ticket with cached state matching upstream surfaces NONE" {
  cat > "$PROBLEMS_DIR/102-baz.open.md" <<'EOF'
# Problem 102: Baz

**Status**: Open

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/77
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  # Seed cache to match upstream state.
  cat > "$CACHE_FILE" <<'EOF'
{
  "last_checked": "2026-05-15T00:00:00Z",
  "tickets": {
    "P102": {
      "upstream_url": "https://github.com/example/repo/issues/77",
      "last_checked_at": "2026-05-15T00:00:00Z",
      "last_seen_state": "OPEN",
      "last_seen_comment_count": 3,
      "last_seen_labels": ["triage"],
      "last_seen_updated_at": "2026-05-14T12:00:00Z"
    }
  }
}
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/77" '{"state":"OPEN","comments":[{"id":1},{"id":2},{"id":3}],"labels":[{"name":"triage"}],"updatedAt":"2026-05-14T12:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^NONE *P102"
}

# ── Behavioural: new comments surface as NEW with delta count ───────────────

@test "ticket with new comments since last check surfaces NEW with count" {
  cat > "$PROBLEMS_DIR/103-qux.open.md" <<'EOF'
# Problem 103: Qux

**Status**: Open

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/88
- **Reported**: 2026-05-01
- **Template used**: bug_report.yml
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  cat > "$CACHE_FILE" <<'EOF'
{
  "last_checked": "2026-05-15T00:00:00Z",
  "tickets": {
    "P103": {
      "upstream_url": "https://github.com/example/repo/issues/88",
      "last_checked_at": "2026-05-15T00:00:00Z",
      "last_seen_state": "OPEN",
      "last_seen_comment_count": 1,
      "last_seen_labels": [],
      "last_seen_updated_at": "2026-05-14T12:00:00Z"
    }
  }
}
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/88" '{"state":"OPEN","comments":[{"id":1},{"id":2},{"id":3}],"labels":[],"updatedAt":"2026-05-17T08:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^NEW *P103"
  echo "$output" | grep -q "new-comments=2"
}

# ── Behavioural: state change surfaces STATE marker ─────────────────────────

@test "ticket with state change OPEN to CLOSED surfaces STATE marker" {
  cat > "$PROBLEMS_DIR/104-baz.open.md" <<'EOF'
# Problem 104: Baz

**Status**: Open

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/99
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  cat > "$CACHE_FILE" <<'EOF'
{
  "last_checked": "2026-05-15T00:00:00Z",
  "tickets": {
    "P104": {
      "upstream_url": "https://github.com/example/repo/issues/99",
      "last_checked_at": "2026-05-15T00:00:00Z",
      "last_seen_state": "OPEN",
      "last_seen_comment_count": 2,
      "last_seen_labels": [],
      "last_seen_updated_at": "2026-05-14T12:00:00Z"
    }
  }
}
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/99" '{"state":"CLOSED","comments":[{"id":1},{"id":2}],"labels":[],"updatedAt":"2026-05-17T08:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^STATE *P104"
  echo "$output" | grep -q "state=OPEN.*CLOSED"
}

# ── Behavioural: cache file is created/updated after a pass ─────────────────

@test "cache file is written with the latest state after the pass" {
  cat > "$PROBLEMS_DIR/105-quux.open.md" <<'EOF'
# Problem 105: Quux

**Status**: Open

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/55
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/55" '{"state":"OPEN","comments":[{"id":1},{"id":2}],"labels":[{"name":"triage"},{"name":"bug"}],"updatedAt":"2026-05-17T08:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  [ -f "$CACHE_FILE" ]
  # Cache file contains P105 entry with the current state.
  grep -q '"P105"' "$CACHE_FILE"
  grep -q '"upstream_url": *"https://github.com/example/repo/issues/55"' "$CACHE_FILE"
  grep -q '"last_seen_state": *"OPEN"' "$CACHE_FILE"
}

# ── Behavioural: audit-log file is appended after the pass ──────────────────

@test "audit-log file is appended with a timestamped pass heading" {
  cat > "$PROBLEMS_DIR/106-corge.open.md" <<'EOF'
# Problem 106: Corge

**Status**: Open

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/66
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/66" '{"state":"OPEN","comments":[],"labels":[],"updatedAt":"2026-05-17T08:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  [ -f "$AUDIT_LOG" ]
  # Audit-log contains a heading line matching the ISO timestamp pattern + pass summary.
  grep -qE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "$AUDIT_LOG"
}

# ── Behavioural: --ticket filter restricts to one ticket ────────────────────

@test "--ticket filter restricts polling to the named ticket only" {
  cat > "$PROBLEMS_DIR/107-grault.open.md" <<'EOF'
# Problem 107: Grault

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/107
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  cat > "$PROBLEMS_DIR/108-garply.open.md" <<'EOF'
# Problem 108: Garply

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/108
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/107" '{"state":"OPEN","comments":[],"labels":[],"updatedAt":"2026-05-17T08:00:00Z"}'
  prime_gh_response "https://github.com/example/repo/issues/108" '{"state":"OPEN","comments":[],"labels":[],"updatedAt":"2026-05-17T08:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh" --ticket P107
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "P107"
  ! echo "$output" | grep -q "P108"
}

# ── Behavioural: dual-tolerant subdir layout (RFC-002) ──────────────────────

@test "ticket in per-state subdir is discovered and polled" {
  mkdir -p "$PROBLEMS_DIR/open"
  cat > "$PROBLEMS_DIR/open/109-waldo.md" <<'EOF'
# Problem 109: Waldo

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/109
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/109" '{"state":"OPEN","comments":[],"labels":[],"updatedAt":"2026-05-17T08:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "P109"
}

# ── Behavioural: gh failure for one URL doesn't kill the pass ───────────────

@test "gh failure on one URL is surfaced as FAIL; pass continues for other tickets" {
  cat > "$PROBLEMS_DIR/110-broken.open.md" <<'EOF'
# Problem 110: Broken

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/110
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  cat > "$PROBLEMS_DIR/111-working.open.md" <<'EOF'
# Problem 111: Working

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/111
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  make_fake_gh
  # Only prime 111; 110 will fail.
  prime_gh_response "https://github.com/example/repo/issues/111" '{"state":"OPEN","comments":[],"labels":[],"updatedAt":"2026-05-17T08:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh"
  # Exit 2 = partial (some polls failed).
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "^FAIL *P110"
  echo "$output" | grep -q "P111"
}

# ── Behavioural: --force-recheck ignores cache and re-emits NEW ─────────────

@test "--force-recheck re-emits ticket as new even when cache matches" {
  cat > "$PROBLEMS_DIR/112-fresh.open.md" <<'EOF'
# Problem 112: Fresh

## Reported Upstream

- **URL**: https://github.com/example/repo/issues/112
- **Reported**: 2026-05-01
- **Template used**: structured default
- **Disclosure path**: public issue
- **Cross-reference confirmed**: yes
EOF

  cat > "$CACHE_FILE" <<'EOF'
{
  "last_checked": "2026-05-17T00:00:00Z",
  "tickets": {
    "P112": {
      "upstream_url": "https://github.com/example/repo/issues/112",
      "last_checked_at": "2026-05-17T00:00:00Z",
      "last_seen_state": "OPEN",
      "last_seen_comment_count": 0,
      "last_seen_labels": [],
      "last_seen_updated_at": "2026-05-17T00:00:00Z"
    }
  }
}
EOF

  make_fake_gh
  prime_gh_response "https://github.com/example/repo/issues/112" '{"state":"OPEN","comments":[],"labels":[],"updatedAt":"2026-05-17T00:00:00Z"}'

  export GHFAKE_DATA="$GHFAKE_DIR"
  run "$SCRIPT" --problems-dir "$PROBLEMS_DIR" --cache-file "$CACHE_FILE" --audit-log "$AUDIT_LOG" --gh-bin "$GHFAKE_DIR/gh" --force-recheck
  [ "$status" -eq 0 ]
  # With --force-recheck, the line is emitted as NEW regardless of cache match.
  echo "$output" | grep -qE "^NEW *P112"
}
