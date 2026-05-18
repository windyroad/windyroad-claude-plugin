#!/usr/bin/env bats

# @problem P237 — Phase 3a population script behavioural confirmation.
# @problem P087 — parent: plugin maturity battle-hardening signal.
#
# Contract under test: `packages/itil/scripts/plugin-maturity-populate.sh`
# reads two Phase 2 NDJSON streams (`wr-itil-skill-invocations` +
# `wr-itil-plugin-exercise-index`), applies ADR-053 §promotion criteria +
# §Bootstrapping clause, and writes `maturity:` field per surface and per
# plugin root in each `packages/<plugin>/.claude-plugin/plugin.json`.
# Idempotent — re-running with unchanged inputs (including pinned `--now`)
# produces byte-identical plugin.json output.
#
# Confirmation criteria 1-3 from ADR-063 §Confirmation are the load-bearing
# behavioural assertions; criteria 4-9 belong to Phase 3b / 3c sibling
# tickets (P238 / P239).
#
# @adr ADR-063 (Plugin maturity presentation layer — Phase 3a contract)
# @adr ADR-053 (Plugin maturity taxonomy — promotion criteria + Bootstrapping)
# @adr ADR-058 (Phase 2 NDJSON measurement — input shape)
# @adr ADR-049 (Shim grammar — `wr-itil-plugin-maturity-populate` on $PATH)
# @adr ADR-052 (Behavioural tests default — NDJSON-fixture-driven, not
#   structural grep on script body; AskUserQuestion negative-presence is
#   the documented carve-out)
# @adr ADR-044 (Silent-framework carve-out — Phase 3a band recomputation
#   is mechanical, policy-resolved per ADR-053 §promotion criteria; no
#   `AskUserQuestion` per band recompute)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — exit 0 always)
# @jtbd JTBD-201 (Restore Service Fast — audit-trail composition; the
#   per-surface evidence block IS the durable audit-trail surface)

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/plugin-maturity-populate.sh"
  FIXTURE_DIR="$(mktemp -d)"
  PROJECT_ROOT="$FIXTURE_DIR/project"
  mkdir -p "$PROJECT_ROOT/packages"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# Helper: create a synthetic plugin under packages/<name>/ with a
# minimal plugin.json and the declared surface inventory. Surfaces are
# passed as `kind:name` tokens — e.g. `skill:manage-problem`,
# `agent:agent`, `hook:itil-changeset-discipline`.
make_plugin() {
  local plugin="$1"; shift
  local pkg="$PROJECT_ROOT/packages/$plugin"
  mkdir -p "$pkg/.claude-plugin"
  cat >"$pkg/.claude-plugin/plugin.json" <<EOF
{
  "name": "wr-$plugin",
  "version": "0.1.0",
  "description": "fixture plugin"
}
EOF
  for token in "$@"; do
    local kind="${token%%:*}"
    local name="${token#*:}"
    case "$kind" in
      skill)   mkdir -p "$pkg/skills/$name"; echo "fixture" >"$pkg/skills/$name/SKILL.md" ;;
      agent)   mkdir -p "$pkg/agents"; echo "fixture" >"$pkg/agents/$name.md" ;;
      hook)    mkdir -p "$pkg/hooks"; echo "fixture" >"$pkg/hooks/$name.sh" ;;
      command) mkdir -p "$pkg/commands"; echo "fixture" >"$pkg/commands/$name.md" ;;
    esac
  done
}

# Helper: write a synthetic transcript NDJSON file (`wr-itil-skill-invocations`
# output shape, schema_version 1.0) with one record per (kind, surface).
# Args: file, then triples of kind, surface, invocations.
write_transcript_ndjson() {
  local out="$1"; shift
  : >"$out"
  while [ "$#" -ge 3 ]; do
    local kind="$1"; local surface="$2"; local invocations="$3"
    shift 3
    local plugin
    # Extract plugin name: skill/agent surfaces use `wr-<plugin>:<rest>`,
    # bash-attributed surfaces use `wr-<plugin>-<rest>`.
    if [[ "$surface" == *:* ]]; then
      plugin="${surface%%:*}"
      plugin="${plugin#wr-}"
    else
      plugin="${surface#wr-}"
      plugin="${plugin%%-*}"
    fi
    printf '{"schema_version":"1.0","axis":"skill-invocations","surface":"%s","kind":"%s","plugin":"%s","window_days":30,"invocations":%d,"first_invocation_iso":"2026-04-20T00:00:00Z","last_invocation_iso":"2026-05-17T00:00:00Z"}\n' \
      "$surface" "$kind" "$plugin" "$invocations" >>"$out"
  done
}

# Helper: write a synthetic exercise NDJSON file (`wr-itil-plugin-exercise-index`
# output shape, schema_version 1.0). Args: file, then 5-tuples of
# plugin, commits_window, days_shipped, closed_tickets, breaking_age (or NULL).
write_exercise_ndjson() {
  local out="$1"; shift
  : >"$out"
  while [ "$#" -ge 5 ]; do
    local plugin="$1"; local cw="$2"; local ds="$3"; local ctw="$4"; local bca="$5"
    shift 5
    if [ "$bca" = "NULL" ]; then
      bca="null"
    fi
    printf '{"schema_version":"1.0","axis":"plugin-exercise-index","plugin":"%s","commits_window":%d,"window_days":60,"days_shipped":%d,"closed_tickets_window":%d,"tickets_window_days":90,"breaking_change_age_days":%s,"composite_index":1.0}\n' \
      "$plugin" "$cw" "$ds" "$ctw" "$bca" >>"$out"
  done
}

# Helper: extract a JSON field from a plugin.json via python3 stdlib.
# Args: plugin-json-path, dotted-path (e.g. `maturity.band` or
# `skills.manage-problem.maturity.band`).
get_json_field() {
  local file="$1"; local path="$2"
  python3 -c "
import json, sys
with open('$file') as fh:
    obj = json.load(fh)
for part in '$path'.split('.'):
    if not isinstance(obj, dict) or part not in obj:
        print('MISSING'); sys.exit(0)
    obj = obj[part]
print(obj if not isinstance(obj, (dict, list)) else json.dumps(obj))
"
}

# ── Existence / executable ──────────────────────────────────────────────────

@test "plugin-maturity-populate: canonical script exists" {
  [ -f "$SCRIPT" ]
}

@test "plugin-maturity-populate: canonical script is executable" {
  [ -x "$SCRIPT" ]
}

@test "plugin-maturity-populate: shim file exists with ADR-049 grammar" {
  local shim="$SCRIPTS_DIR/../bin/wr-itil-plugin-maturity-populate"
  [ -f "$shim" ]
  [ -x "$shim" ]
  grep -q 'exec.*scripts/plugin-maturity-populate.sh' "$shim"
}

# ── Confirmation #1: idempotency (ADR-063 §Confirmation 1) ──────────────────
# Run twice with the same --now pin; assert byte-identical plugin.json.

@test "plugin-maturity-populate: idempotency — second run produces byte-identical plugin.json" {
  make_plugin "fixp" "skill:manage-problem" "agent:agent"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" \
    "skill" "wr-fixp:manage-problem" 50 \
    "agent" "wr-fixp:agent" 200
  write_exercise_ndjson "$exer" \
    "fixp" 30 20 3 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/fixp/.claude-plugin/plugin.json"
  local checksum_1
  checksum_1=$(python3 -c "import hashlib; print(hashlib.sha256(open('$pj','rb').read()).hexdigest())")

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local checksum_2
  checksum_2=$(python3 -c "import hashlib; print(hashlib.sha256(open('$pj','rb').read()).hexdigest())")
  [ "$checksum_1" = "$checksum_2" ]
}

# ── Confirmation #2: band-mapping during bootstrapping (ADR-063 #2 first half) ─
# 20 days_shipped → bootstrapping active (suite-oldest < 60d).
# 200 invocations + 20 days_shipped → meets provisional Alpha conditions
# (≥100 invocations + ≥14 days). Lower invocations → Experimental.

@test "plugin-maturity-populate: bootstrapping — provisional Alpha on high-invocation surface" {
  make_plugin "alphap" "agent:agent"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" "agent" "wr-alphap:agent" 200
  write_exercise_ndjson "$exer" "alphap" 30 20 3 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/alphap/.claude-plugin/plugin.json"
  local band
  band=$(get_json_field "$pj" "maturity.agents.agent.band")
  [ "$band" = "Alpha" ]
}

@test "plugin-maturity-populate: bootstrapping — Experimental on low-invocation surface" {
  make_plugin "expp" "skill:list-incidents"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" "skill" "wr-expp:list-incidents" 2
  write_exercise_ndjson "$exer" "expp" 5 20 1 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/expp/.claude-plugin/plugin.json"
  local band
  band=$(get_json_field "$pj" "maturity.skills.list-incidents.band")
  [ "$band" = "Experimental" ]
}

# ── Confirmation #2 second half: steady-state post-sunset (ADR-063 #2) ──────
# Suite-oldest ≥60 days_shipped → bootstrapping inactive.
# 796 invocations + 200 days_shipped + 15 tickets + null breaking → Beta-
# floor satisfied, Stable-floor not (invocations <1000). Expect Beta.

@test "plugin-maturity-populate: steady-state — Beta on heavy-invocation aged surface" {
  make_plugin "betap" "agent:agent"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" "agent" "wr-betap:agent" 796
  write_exercise_ndjson "$exer" "betap" 100 200 15 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-07-01T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/betap/.claude-plugin/plugin.json"
  local band
  band=$(get_json_field "$pj" "maturity.agents.agent.band")
  [ "$band" = "Beta" ]
}

# ── Confirmation #3: no AskUserQuestion per band recompute ──────────────────
# ADR-044 silent-framework carve-out (ADR-063 §scope-limited carve-out).
# Negative-presence check on stdin / stderr — case-insensitive per architect
# adjustment G.

@test "plugin-maturity-populate: no AskUserQuestion invocation during band recompute" {
  make_plugin "silentp" "skill:list-stories"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" "skill" "wr-silentp:list-stories" 50
  write_exercise_ndjson "$exer" "silentp" 10 20 2 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  # Case-insensitive scan of combined stdout + stderr for any
  # AskUserQuestion-token spelling.
  printf '%s' "$output" | grep -i -E 'askuserquestion|<askuser' && return 1 || true
}

# ── Schema shape (ADR-063 §plugin.json maturity field schema) ───────────────

@test "plugin-maturity-populate: per-surface maturity record carries schema_version + band + computed_at + evidence" {
  make_plugin "shapep" "skill:manage-problem"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" "skill" "wr-shapep:manage-problem" 100
  write_exercise_ndjson "$exer" "shapep" 20 25 5 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/shapep/.claude-plugin/plugin.json"
  [ "$(get_json_field "$pj" "maturity.skills.manage-problem.schema_version")" = "2.0" ]
  [ "$(get_json_field "$pj" "maturity.skills.manage-problem.band")" != "MISSING" ]
  [ "$(get_json_field "$pj" "maturity.skills.manage-problem.computed_at")" != "MISSING" ]
  [ "$(get_json_field "$pj" "maturity.skills.manage-problem.evidence.invocations_30d")" = "100" ]
  [ "$(get_json_field "$pj" "maturity.skills.manage-problem.evidence.days_shipped")" = "25" ]
  [ "$(get_json_field "$pj" "maturity.skills.manage-problem.evidence.closed_tickets_window")" = "5" ]
}

@test "plugin-maturity-populate: plugin root rollup carries schema_version + band only, no evidence" {
  make_plugin "rollupp" "skill:s1" "skill:s2"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" \
    "skill" "wr-rollupp:s1" 200 \
    "skill" "wr-rollupp:s2" 1
  write_exercise_ndjson "$exer" "rollupp" 10 20 2 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/rollupp/.claude-plugin/plugin.json"
  [ "$(get_json_field "$pj" "maturity.schema_version")" = "2.0" ]
  [ "$(get_json_field "$pj" "maturity.band")" != "MISSING" ]
  [ "$(get_json_field "$pj" "maturity.evidence")" = "MISSING" ]
}

# ── Granularity contract (ADR-063 #10): rollup = worst-case among surfaces ──

@test "plugin-maturity-populate: rollup band equals worst-case among constituent surfaces" {
  make_plugin "worstp" "skill:hot" "skill:cold"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  # hot → Alpha (200 invocations + 20 days during bootstrapping);
  # cold → Experimental (1 invocation). Worst-case = Experimental.
  write_transcript_ndjson "$trans" \
    "skill" "wr-worstp:hot" 200 \
    "skill" "wr-worstp:cold" 1
  write_exercise_ndjson "$exer" "worstp" 10 20 2 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/worstp/.claude-plugin/plugin.json"
  [ "$(get_json_field "$pj" "maturity.band")" = "Experimental" ]
}

# ── Hook evidence shape (architect adjustment C) — null invocation sentinel ──
# Hooks are not transcript-observable; invocations_30d MUST be `null`, not 0,
# to preserve "not measurable" vs "measurably zero" semantics.

@test "plugin-maturity-populate: hook surfaces emit null invocations_30d sentinel" {
  make_plugin "hookp" "hook:itil-fictional-defer-detect"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  # Empty transcript NDJSON — hooks never appear in transcript stream.
  : >"$trans"
  write_exercise_ndjson "$exer" "hookp" 5 30 1 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj="$PROJECT_ROOT/packages/hookp/.claude-plugin/plugin.json"
  # Read the raw JSON and check that invocations_30d is literally null,
  # not 0. (`get_json_field` collapses null/0 to display; use python3 directly.)
  local raw
  raw=$(python3 -c "
import json
obj = json.load(open('$pj'))
print(json.dumps(obj['maturity']['hooks']['itil-fictional-defer-detect']['evidence']['invocations_30d']))
")
  [ "$raw" = "null" ]
}

# ── Deprecated-band overlay preservation (architect adjustment I) ───────────
# Pre-existing author-declared `band: "Deprecated"` + `supersededBy:` MUST
# survive recompute unchanged. Recompute does NOT overwrite Deprecated
# downward.

@test "plugin-maturity-populate: preserves author-declared Deprecated band + supersededBy pointer" {
  make_plugin "depp" "skill:oldskill"
  local pj="$PROJECT_ROOT/packages/depp/.claude-plugin/plugin.json"
  # Hand-author the Deprecated entry that the script must preserve.
  python3 <<EOF
import json
obj = json.load(open("$pj"))
obj.setdefault("maturity", {}).setdefault("skills", {})["oldskill"] = {
    "schema_version": "2.0",
    "band": "Deprecated",
    "computed_at": "2026-04-01T00:00:00Z",
    "supersededBy": "wr-depp:newskill",
    "evidence": {
        "invocations_30d": 50,
        "days_shipped": 100,
        "closed_tickets_window": 3,
        "breaking_change_age_days": None,
    },
}
with open("$pj","w") as fh:
    json.dump(obj, fh, indent=2, sort_keys=True)
EOF
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_transcript_ndjson "$trans" "skill" "wr-depp:oldskill" 50
  write_exercise_ndjson "$exer" "depp" 5 100 3 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  [ "$(get_json_field "$pj" "maturity.skills.oldskill.band")" = "Deprecated" ]
  [ "$(get_json_field "$pj" "maturity.skills.oldskill.supersededBy")" = "wr-depp:newskill" ]
}

# ── Bootstrapping clause sunset auto-derivation (architect adjustment D) ────
# Sunset is computed from `max(days_shipped)` ≥ 60 in the exercise NDJSON.
# Same surface evidence → Experimental during bootstrapping (suite-oldest < 60d);
# Beta+ once suite-oldest ≥ 60d (no calendar-date hard-code required).

@test "plugin-maturity-populate: bootstrapping lapses when max(days_shipped) ≥ 60" {
  make_plugin "p1" "agent:agent"
  make_plugin "p2" "agent:agent"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  # Both plugins have 796 invocations + 200 days_shipped + 15 tickets.
  # In steady-state these would each be Beta. Under bootstrapping (oldest <60d)
  # they would be Alpha. Test: with one plugin aged 200d, bootstrapping is
  # inactive and the band is Beta. Independent of --now (no hard-coded date).
  write_transcript_ndjson "$trans" \
    "agent" "wr-p1:agent" 796 \
    "agent" "wr-p2:agent" 796
  write_exercise_ndjson "$exer" \
    "p1" 100 200 15 NULL \
    "p2" 100 25  15 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]

  local pj1="$PROJECT_ROOT/packages/p1/.claude-plugin/plugin.json"
  local pj2="$PROJECT_ROOT/packages/p2/.claude-plugin/plugin.json"
  # p1 aged 200d → Beta. p2 aged 25d → Beta-floor unmet (days <60), demotes
  # to Alpha steady-state OR Experimental depending on the days_shipped cell;
  # only assert here that bootstrapping is inactive (the p1 outcome).
  [ "$(get_json_field "$pj1" "maturity.agents.agent.band")" = "Beta" ]
}

# ── ADR-013 Rule 6 fail-safe — missing NDJSON inputs ────────────────────────

@test "plugin-maturity-populate: exits 0 when transcript NDJSON missing" {
  make_plugin "failsafe" "skill:thing"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  write_exercise_ndjson "$exer" "failsafe" 10 20 2 NULL

  run "$SCRIPT" \
    --transcript-ndjson="$FIXTURE_DIR/does-not-exist.ndjson" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]
}

@test "plugin-maturity-populate: exits 0 when no packages directory exists" {
  rm -rf "$PROJECT_ROOT/packages"
  local trans="$FIXTURE_DIR/transcript.ndjson"
  local exer="$FIXTURE_DIR/exercise.ndjson"
  : >"$trans"; : >"$exer"

  run "$SCRIPT" \
    --transcript-ndjson="$trans" \
    --exercise-ndjson="$exer" \
    --project-root="$PROJECT_ROOT" \
    --now=2026-05-17T12:00:00Z
  [ "$status" -eq 0 ]
}

# ── Privacy posture (mirrored from ADR-058 §Confirmation #3) ────────────────
# No network primitive in the script body — defensive negative-grep.

@test "plugin-maturity-populate: script body invokes no network egress primitives" {
  ! grep -E '(\bcurl\b|\bwget\b|\bnc\b|fetch\b|http\.client|urllib|socket\.connect)' "$SCRIPT"
}
