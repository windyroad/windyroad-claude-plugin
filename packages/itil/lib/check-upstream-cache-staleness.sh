#!/usr/bin/env bash
# Inbound-discovery cache staleness check — Step 0b of /wr-itil:work-problems.
# ADR-062 § JTBD-006 driver: work-problems should pre-flight
# /wr-itil:review-problems when the upstream inbound-discovery cache is stale
# or missing, so AFK loops keep upstream-reported problems visible without
# the maintainer remembering to invoke review-problems first.
#
# The staleness comparison MUST stay symmetric with review-problems Step 4.5b's
# branches (first-run / TTL-expiry / cache-fresh). Drift here re-opens the
# inbound-discovery staleness contract — any change to TTL semantics MUST
# update both this helper and packages/itil/skills/review-problems/SKILL.md
# Step 4.5b in the same commit.
# <!-- INBOUND-CACHE-STALENESS-CONTRACT-SOURCE: packages/itil/skills/review-problems/SKILL.md Step 4.5b -->
#
# Source this file, then call `should_promote_inbound_discovery_preflight`:
#   . packages/itil/lib/check-upstream-cache-staleness.sh
#   reason="$(should_promote_inbound_discovery_preflight "$PWD")"
#
# Output (one of):
#   no-channels-config           → channels-config absent; skip silently.
#                                  Downstream-adopter non-obligation per
#                                  ADR-062 § Downstream-adopter contract.
#   first-run-cache-absent       → channels-config present, cache file absent.
#                                  Dispatch review-problems.
#   first-run-last-checked-null  → cache present but last_checked is null.
#                                  Dispatch review-problems.
#   fresh-within-ttl             → cache within TTL; silent-pass.
#   ttl-expiry age=<N>s ttl=<M>s → cache older than TTL; dispatch.
#
# Dependencies: bash 4+, jq, python3 (for ISO-8601 parsing — portable across
# Linux/BSD date implementations).

should_promote_inbound_discovery_preflight() {
  local repo_root="${1:-$PWD}"
  local channels_file="$repo_root/docs/problems/.upstream-channels.json"
  local cache_file="$repo_root/docs/problems/.upstream-cache.json"

  if [ ! -f "$channels_file" ]; then
    echo "no-channels-config"
    return 0
  fi

  local ttl_seconds
  ttl_seconds="$(jq -r '.ttl_seconds // 86400' "$channels_file")"

  if [ ! -f "$cache_file" ]; then
    echo "first-run-cache-absent"
    return 0
  fi

  local last_checked
  last_checked="$(jq -r '.last_checked // ""' "$cache_file")"

  if [ -z "$last_checked" ] || [ "$last_checked" = "null" ]; then
    echo "first-run-last-checked-null"
    return 0
  fi

  local last_checked_epoch now_epoch cache_age
  last_checked_epoch="$(python3 -c "import datetime,sys; ts=sys.argv[1].replace('Z','+00:00'); print(int(datetime.datetime.fromisoformat(ts).timestamp()))" "$last_checked" 2>/dev/null || echo "0")"
  now_epoch="$(date +%s)"
  cache_age=$((now_epoch - last_checked_epoch))

  if [ "$cache_age" -gt "$ttl_seconds" ]; then
    echo "ttl-expiry age=${cache_age}s ttl=${ttl_seconds}s"
    return 0
  fi

  echo "fresh-within-ttl"
  return 0
}
