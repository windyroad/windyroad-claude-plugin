#!/usr/bin/env bats

# Step 0b behavioural fixture per ADR-062 § JTBD-006 driver:
# work-problems pre-flights /wr-itil:review-problems when the
# upstream inbound-discovery cache is stale or missing. The
# staleness decision lives in
# `packages/itil/lib/check-upstream-cache-staleness.sh::should_promote_inbound_discovery_preflight`
# so the SKILL.md Step 0b prose is a thin source-and-call wrapper
# around a behaviorally-testable shell function (P081 / user
# feedback: prefer behavioural over structural-grep tests).
#
# Cases covered:
#   1. No channels-config file → "no-channels-config" (downstream-adopter non-obligation, ADR-062 § Downstream-adopter contract).
#   2. Channels-config present, cache file absent → "first-run-cache-absent".
#   3. Channels-config present, cache present, last_checked null → "first-run-last-checked-null".
#   4. Channels-config present, cache fresh within TTL → "fresh-within-ttl".
#   5. Channels-config present, cache older than TTL → "ttl-expiry" (with age + ttl in the reason).
#   6. Custom ttl_seconds in channels-config is respected (not hardcoded default).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  HELPER="$REPO_ROOT/packages/itil/lib/check-upstream-cache-staleness.sh"

  FIXTURE="$(mktemp -d)"
  mkdir -p "$FIXTURE/docs/problems"
}

teardown() {
  rm -rf "$FIXTURE"
}

@test "helper exists at the contracted path" {
  [ -f "$HELPER" ]
}

@test "case 1: no channels-config → no-channels-config" {
  # shellcheck disable=SC1090
  source "$HELPER"
  run should_promote_inbound_discovery_preflight "$FIXTURE"
  [ "$status" -eq 0 ]
  [ "$output" = "no-channels-config" ]
}

@test "case 2: channels-config present, cache absent → first-run-cache-absent" {
  cat > "$FIXTURE/docs/problems/.upstream-channels.json" <<'EOF'
{ "channels": [], "ttl_seconds": 86400 }
EOF
  # shellcheck disable=SC1090
  source "$HELPER"
  run should_promote_inbound_discovery_preflight "$FIXTURE"
  [ "$status" -eq 0 ]
  [ "$output" = "first-run-cache-absent" ]
}

@test "case 3: cache present, last_checked null → first-run-last-checked-null" {
  cat > "$FIXTURE/docs/problems/.upstream-channels.json" <<'EOF'
{ "channels": [], "ttl_seconds": 86400 }
EOF
  cat > "$FIXTURE/docs/problems/.upstream-cache.json" <<'EOF'
{ "last_checked": null, "channels": [] }
EOF
  # shellcheck disable=SC1090
  source "$HELPER"
  run should_promote_inbound_discovery_preflight "$FIXTURE"
  [ "$status" -eq 0 ]
  [ "$output" = "first-run-last-checked-null" ]
}

@test "case 4: cache fresh within TTL → fresh-within-ttl (silent-pass)" {
  cat > "$FIXTURE/docs/problems/.upstream-channels.json" <<'EOF'
{ "channels": [], "ttl_seconds": 86400 }
EOF
  # last_checked 1 hour ago — well within 24h TTL.
  local recent_iso
  recent_iso="$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
  cat > "$FIXTURE/docs/problems/.upstream-cache.json" <<EOF
{ "last_checked": "$recent_iso", "channels": [] }
EOF
  # shellcheck disable=SC1090
  source "$HELPER"
  run should_promote_inbound_discovery_preflight "$FIXTURE"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh-within-ttl" ]
}

@test "case 5: cache older than TTL → ttl-expiry with age + ttl in the reason" {
  cat > "$FIXTURE/docs/problems/.upstream-channels.json" <<'EOF'
{ "channels": [], "ttl_seconds": 86400 }
EOF
  # last_checked 2 days ago — past 24h TTL.
  local stale_iso
  stale_iso="$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=2)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
  cat > "$FIXTURE/docs/problems/.upstream-cache.json" <<EOF
{ "last_checked": "$stale_iso", "channels": [] }
EOF
  # shellcheck disable=SC1090
  source "$HELPER"
  run should_promote_inbound_discovery_preflight "$FIXTURE"
  [ "$status" -eq 0 ]
  # Format: "ttl-expiry age=<N>s ttl=<M>s"
  [[ "$output" =~ ^ttl-expiry\ age=[0-9]+s\ ttl=86400s$ ]]
}

@test "case 6: custom ttl_seconds is honored (not hardcoded default)" {
  # 1-hour TTL; last_checked 90 minutes ago → stale under the custom TTL,
  # but would be FRESH under the 86400s default. Confirms the helper reads
  # ttl_seconds from channels-config rather than hardcoding 86400.
  cat > "$FIXTURE/docs/problems/.upstream-channels.json" <<'EOF'
{ "channels": [], "ttl_seconds": 3600 }
EOF
  local mid_iso
  mid_iso="$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=90)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
  cat > "$FIXTURE/docs/problems/.upstream-cache.json" <<EOF
{ "last_checked": "$mid_iso", "channels": [] }
EOF
  # shellcheck disable=SC1090
  source "$HELPER"
  run should_promote_inbound_discovery_preflight "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^ttl-expiry\ age=[0-9]+s\ ttl=3600s$ ]]
}

@test "case 7: missing ttl_seconds field defaults to 86400 (24h)" {
  cat > "$FIXTURE/docs/problems/.upstream-channels.json" <<'EOF'
{ "channels": [] }
EOF
  # last_checked 1 hour ago — fresh under the default 86400s TTL.
  local recent_iso
  recent_iso="$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
  cat > "$FIXTURE/docs/problems/.upstream-cache.json" <<EOF
{ "last_checked": "$recent_iso", "channels": [] }
EOF
  # shellcheck disable=SC1090
  source "$HELPER"
  run should_promote_inbound_discovery_preflight "$FIXTURE"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh-within-ttl" ]
}
