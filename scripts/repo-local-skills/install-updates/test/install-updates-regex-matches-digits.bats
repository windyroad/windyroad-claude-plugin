#!/usr/bin/env bats

# P058: install-updates SKILL.md Step 2/3 discovery regex must match
# plugin names containing digits (e.g. wr-c4). The prior `[a-z-]+`
# character class silently skipped any such plugin; the corrected
# `[a-z0-9-]+` covers the npm naming convention (lowercase + digits
# + hyphens). Also exercises ADR-030's "bats tests optional under
# .claude/skills/<name>/test/" contract for the first time.

setup() {
  # This test file lives at .claude/skills/install-updates/test/ —
  # 4 levels below repo root.
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/.claude/skills/install-updates/SKILL.md"
}

@test "install-updates: SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "install-updates: Step 2 and Step 3 discovery regex uses [a-z0-9-]+ character class (P058)" {
  # Doc-lint guard — prevents regression to [a-z-]+ which drops wr-c4.
  local count
  count=$(grep -cE '"wr-\[a-z0-9-\]\+@windyroad"' "$SKILL_MD")
  [ "$count" -ge 2 ]
}

@test "install-updates: SKILL.md contains no regressed [a-z-]+ character class in windyroad pattern (P058)" {
  # Negative guard — the old broken pattern must not reappear.
  run grep -cE '"wr-\[a-z-\]\+@windyroad"' "$SKILL_MD"
  [ "$output" = "0" ]
}

@test "install-updates: SKILL.md's discovery regex matches wr-c4@windyroad against a synthetic fixture (P058)" {
  # Behavioral check — extract the bash-quoted pattern directly from
  # SKILL.md and apply it to a synthetic settings.json fixture. If
  # someone regresses the pattern, this assertion fails against the
  # wr-c4 fixture row.
  local pattern
  pattern=$(grep -oE "'\"wr-\[[^]]+\]\+@windyroad\"'" "$SKILL_MD" | head -1 | sed "s/^'//; s/'\$//")
  [ -n "$pattern" ]

  local fixture="$BATS_TEST_TMPDIR/settings.json"
  cat > "$fixture" <<'EOF'
{
  "enabledPlugins": {
    "wr-c4@windyroad": true,
    "wr-itil@windyroad": true,
    "wr-jtbd@windyroad": true
  }
}
EOF

  local matches
  matches=$(grep -oE "$pattern" "$fixture")
  [[ "$matches" == *'"wr-c4@windyroad"'* ]]
  [[ "$matches" == *'"wr-itil@windyroad"'* ]]
  [[ "$matches" == *'"wr-jtbd@windyroad"'* ]]
}
