#!/usr/bin/env bats

# @problem P238 — Phase 3b renderer behavioural confirmation.
# @problem P087 — parent: plugin maturity battle-hardening signal.
#
# Contract under test: `packages/itil/scripts/plugin-maturity-render.sh`
# reads `plugin.json` `maturity:` field (per Phase 3a populate output)
# and writes a prose-woven rollup badge into each plugin's README.md
# value-framing lead prose AND populates a per-skill `Maturity` column
# in the existing `## Skills` table. Idempotent — re-running with
# unchanged inputs produces byte-identical README output.
#
# Anti-patterns enforced (ADR-063 §README badge rendering format):
#   - NO standalone `## Maturity` section
#   - NO header block immediately after H1 before any prose framing
#   - NO shields.io URL or inline SVG (markdown text only)
#
# Bootstrapping rendering: rollup carries compound form during the
# suite-bootstrap window; per-skill column carries band name only
# (compound stays at rollup, never at cell).
#
# @adr ADR-063 (Plugin maturity presentation layer — Phase 3b contract)
# @adr ADR-053 (Plugin maturity taxonomy — Bootstrapping clause rendering)
# @adr ADR-051 (JTBD-anchored README — prose-weaving precedent)
# @adr ADR-049 (Shim grammar — `wr-itil-plugin-maturity-render` on $PATH)
# @adr ADR-052 (Behavioural tests default)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — exit 0 always)

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/plugin-maturity-render.sh"
  FIXTURE_DIR="$(mktemp -d)"
  PROJECT_ROOT="$FIXTURE_DIR/project"
  mkdir -p "$PROJECT_ROOT/packages"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# Helper: write a synthetic plugin layout with plugin.json + README.md
make_plugin() {
  local name="$1"
  local plugin_json="$2"
  local readme="$3"
  local pkg="$PROJECT_ROOT/packages/$name"
  mkdir -p "$pkg/.claude-plugin"
  printf '%s\n' "$plugin_json" > "$pkg/.claude-plugin/plugin.json"
  printf '%s\n' "$readme" > "$pkg/README.md"
}

# ── Pre-checks ──────────────────────────────────────────────────────────────

@test "script file exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "missing packages dir exits 0 with stderr comment" {
  run bash "$SCRIPT" --project-root="$FIXTURE_DIR/does-not-exist"
  [ "$status" -eq 0 ]
}

@test "opt-out marker present: skips all writes" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"
  mkdir -p "$PROJECT_ROOT/.claude"
  touch "$PROJECT_ROOT/.claude/.skill-metrics-opt-out"
  local before; before="$(cat "$PROJECT_ROOT/packages/stub/README.md")"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local after; after="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  [ "$before" = "$after" ]
}

# ── Confirmation #1 (ADR-063): rollup badge prose-woven into lead prose ─────

@test "rollup badge: inserts prose-woven Maturity span into bold lead prose line" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/stub

**Stub plugin description.** Some more prose.

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out; out="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  # Prose-woven Maturity span appears, italicised, in the lead-prose area
  [[ "$out" == *"*Maturity: Alpha"* ]]
}

@test "rollup badge: bootstrapping window renders compound form with invocation count" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Experimental","bootstrapping":true,"rollup_invocations_30d":796}}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out; out="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  [[ "$out" == *"Experimental"* ]]
  [[ "$out" == *"suite-bootstrap window"* ]]
  [[ "$out" == *"796 invocations"* ]]
}

@test "rollup badge: post-bootstrap renders band name only (no compound)" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Beta"}}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out; out="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  [[ "$out" == *"*Maturity: Beta.*"* ]]
  [[ "$out" != *"suite-bootstrap"* ]]
  [[ "$out" != *"invocations"* ]]
}

# ── Confirmation #2 (ADR-063): per-skill Maturity column populated ──────────

@test "per-skill column: adds Maturity column to existing Skills table" {
  make_plugin "stub" '{
"name":"wr-stub","version":"0.1.0","description":"Stub",
"maturity":{"schema_version":"2.0","band":"Alpha","skills":{
"thing":{"schema_version":"2.0","band":"Alpha","computed_at":"2026-05-18T00:00:00Z","evidence":{"invocations_30d":50,"days_shipped":30,"closed_tickets_window":5,"breaking_change_age_days":null}},
"widget":{"schema_version":"2.0","band":"Experimental","computed_at":"2026-05-18T00:00:00Z","evidence":{"invocations_30d":2,"days_shipped":5,"closed_tickets_window":0,"breaking_change_age_days":null}}
}}
}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
| /wr-stub:widget | Widgets things |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out; out="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  # Header row gains Maturity column
  [[ "$out" == *"| Skill | Purpose | Maturity |"* ]]
  # Cells populated
  [[ "$out" == *"/wr-stub:thing"*"| Alpha |"* ]]
  [[ "$out" == *"/wr-stub:widget"*"| Experimental |"* ]]
  # Per-skill cell carries band name ONLY (no compound)
  [[ "$out" != *"| Alpha (suite"* ]]
}

# ── Idempotency: second run produces no diff ────────────────────────────────

@test "idempotency: second run against unchanged plugin.json produces byte-equal README" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  local first; first="$(cat "$PROJECT_ROOT/packages/stub/README.md")"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  local second; second="$(cat "$PROJECT_ROOT/packages/stub/README.md")"

  [ "$first" = "$second" ]
}

@test "idempotency: existing Maturity badge gets replaced (not appended)" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Beta"}}' \
"# @windyroad/stub

**Stub plugin description.** *Maturity: Alpha.*

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out; out="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  # Beta replaced Alpha (no duplication)
  [[ "$out" == *"*Maturity: Beta"* ]]
  [[ "$out" != *"*Maturity: Alpha"* ]]
  # Single Maturity span (no duplication)
  local count
  count="$(grep -oE '\*Maturity: [^*]+\*' "$PROJECT_ROOT/packages/stub/README.md" | wc -l)"
  [ "$count" -eq 1 ]
}

# ── Anti-pattern: no standalone ## Maturity section emitted ─────────────────

@test "anti-pattern: renderer never emits a standalone ## Maturity section" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out; out="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  [[ "$out" != *"## Maturity"* ]]
  [[ "$out" != *"# Maturity"* ]]
}

@test "anti-pattern: no shields.io badge URL emitted" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out; out="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  [[ "$out" != *"shields.io"* ]]
  [[ "$out" != *"img.shields"* ]]
}

# ── Fail-safe: missing maturity field is a no-op (Phase 3a not yet run) ─────

@test "fail-safe: plugin.json without maturity: field is skipped" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub"}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"
  local before; before="$(cat "$PROJECT_ROOT/packages/stub/README.md")"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local after; after="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  [ "$before" = "$after" ]
}

# ── Fail-safe: plugin without README is skipped ─────────────────────────────

@test "fail-safe: plugin without README.md is silently skipped" {
  local pkg="$PROJECT_ROOT/packages/no-readme"
  mkdir -p "$pkg/.claude-plugin"
  echo '{"name":"wr-no-readme","version":"0.1.0","description":"No README","maturity":{"schema_version":"1.0","band":"Alpha"}}' > "$pkg/.claude-plugin/plugin.json"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  [ ! -f "$pkg/README.md" ]
}

# ── No-AskUserQuestion: ADR-044 silent-framework carve-out ──────────────────

@test "ADR-044: renderer never invokes AskUserQuestion per re-render" {
  # Negative-presence behavioural assertion per ADR-052 §carve-out — the
  # renderer is mechanical (band already computed by Phase 3a) and must
  # not surface a consent gate per re-render. Scans combined stdout +
  # stderr output for any AskUserQuestion-token spelling, case-insensitive
  # per architect adjustment G to plugin-maturity-populate.bats.
  make_plugin "silentp" '{"name":"wr-silentp","version":"0.1.0","description":"Silent","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/silentp

**Silent plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-silentp:thing | Does a thing |
"
  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | grep -i -E 'askuserquestion|<askuser' && return 1 || true
}

# ── No-network primitive: ADR-035 privacy posture ───────────────────────────

@test "ADR-035: script body invokes no network primitive" {
  # Negative-presence behavioural assertion — the renderer reads
  # plugin.json + README.md from filesystem only; never reaches a
  # network endpoint. Mirrors plugin-maturity-populate.bats.
  run grep -E "(curl|wget|nc -|netcat|ssh |scp |rsync|http\.client|urllib|requests)" "$SCRIPT"
  [ "$status" -ne 0 ]
}

# ── Multi-plugin: renders each plugin independently ─────────────────────────

@test "multi-plugin: renders each packages/<plugin>/README.md independently" {
  make_plugin "alpha" '{"name":"wr-alpha","version":"0.1.0","description":"Alpha","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/alpha

**Alpha plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-alpha:thing | Does a thing |
"
  make_plugin "bravo" '{"name":"wr-bravo","version":"0.1.0","description":"Bravo","maturity":{"schema_version":"1.0","band":"Beta"}}' \
"# @windyroad/bravo

**Bravo plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-bravo:thing | Does a thing |
"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT"
  [ "$status" -eq 0 ]

  local out_a; out_a="$(cat "$PROJECT_ROOT/packages/alpha/README.md")"
  local out_b; out_b="$(cat "$PROJECT_ROOT/packages/bravo/README.md")"
  [[ "$out_a" == *"*Maturity: Alpha"* ]]
  [[ "$out_b" == *"*Maturity: Beta"* ]]
}

# ── Dry-run: prints diff to stdout, does not write ──────────────────────────

@test "dry-run: --dry-run flag prints intended diff to stdout without modifying README" {
  make_plugin "stub" '{"name":"wr-stub","version":"0.1.0","description":"Stub","maturity":{"schema_version":"1.0","band":"Alpha"}}' \
"# @windyroad/stub

**Stub plugin description.**

## Skills

| Skill | Purpose |
|-------|---------|
| /wr-stub:thing | Does a thing |
"
  local before; before="$(cat "$PROJECT_ROOT/packages/stub/README.md")"

  run bash "$SCRIPT" --project-root="$PROJECT_ROOT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Maturity: Alpha"* ]]

  local after; after="$(cat "$PROJECT_ROOT/packages/stub/README.md")"
  [ "$before" = "$after" ]
}
