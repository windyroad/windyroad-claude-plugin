#!/usr/bin/env bats
# P151 / ADR-049 Confirmation criterion 1.
#
# Behavioural grep-as-lint asserting no published packages/*/skills/*/SKILL.md
# contains a `bash <repo-relative-path>` invocation as a load-bearing dispatch.
#
# The driver: published SKILL.md prose is read by adopter agents and dispatched
# via the Bash tool from the adopter's project root. Repo-relative paths
# (`packages/<plugin>/scripts/<name>.sh`) do not resolve in adopter trees, so
# the bash command exits 127 with `No such file or directory` and the SKILL.md
# control flow halts before the skill produces any user value.
#
# ADR-049 normative rule: plugin-bundled scripts invoked from SKILL.md MUST
# resolve via `bin/` on `$PATH` (e.g. `wr-itil-reconcile-readme`), never via
# repo-relative paths. This test fails CI on regression.
#
# Cross-plugin scope (matches sibling `packages/shared/test/external-comms-gate-canonical.bats`
# and `plugin-manifest-sync.bats` precedent for cross-cutting published-skill contract tests).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
}

@test "no published SKILL.md contains 'bash packages/<plugin>/scripts/<name>.<ext>' (P151 / ADR-049)" {
  # Pattern matches `bash packages/<plugin>/scripts/<name>.{sh,py,bats,js,ts}`
  # at any indent level. Captures the load-bearing dispatch surface only —
  # patterns inside fenced code blocks that document the failure mode would
  # also match (and that is acceptable: even literary references to the
  # repo-relative path are confusing for adopter agents and should be replaced
  # with the bin-wrapper name per ADR-049 Confirmation criterion 4).
  local hits
  hits=$(grep -rnE 'bash +packages/[a-z][a-z0-9-]*/(scripts|hooks)/[a-z0-9-]+\.(sh|py|bats|js|ts)' \
    "$REPO_ROOT"/packages/*/skills/*/SKILL.md 2>/dev/null || true)

  if [ -n "$hits" ]; then
    echo "ADR-049 violation — repo-relative script invocation found in published SKILL.md:"
    echo "$hits"
    echo ""
    echo "Replace each match with the bin-wrapper name per ADR-049 naming grammar:"
    echo "  bash packages/<plugin>/scripts/<name>.sh ARG"
    echo "  → wr-<plugin>-<kebab-name> ARG"
    echo ""
    echo "Add the shim wrapper at packages/<plugin>/bin/wr-<plugin>-<kebab-name>"
    echo "with body: exec \"\$(dirname \"\$0\")/../scripts/<name>.sh\" \"\$@\""
    return 1
  fi
}

@test "no published SKILL.md contains 'bash packages/<plugin>/hooks/<name>.<ext>' (P151 / ADR-049)" {
  # Matched by the same regex as the first test, but expressed as a separate
  # @test block so the failure surface names which directory class regressed
  # (scripts/ vs hooks/). Hooks are a different invocation class than scripts —
  # hooks are Claude Code runtime callouts, not adopter-agent dispatches — but
  # if a SKILL.md ever invokes a hook directly, the same plugin-boundary rule
  # applies.
  local hits
  hits=$(grep -rnE 'bash +packages/[a-z][a-z0-9-]*/hooks/[a-z0-9-]+\.(sh|py|bats|js|ts)' \
    "$REPO_ROOT"/packages/*/skills/*/SKILL.md 2>/dev/null || true)

  if [ -n "$hits" ]; then
    echo "ADR-049 violation — repo-relative hook invocation found in published SKILL.md:"
    echo "$hits"
    return 1
  fi
}

@test "shim wrapper packages/itil/bin/wr-itil-reconcile-readme exists and is executable" {
  [ -x "$REPO_ROOT/packages/itil/bin/wr-itil-reconcile-readme" ]
}

@test "shim wrapper packages/itil/bin/wr-itil-check-problems-readme-budget exists and is executable" {
  [ -x "$REPO_ROOT/packages/itil/bin/wr-itil-check-problems-readme-budget" ]
}

@test "shim wrapper packages/retrospective/bin/wr-retrospective-measure-context-budget exists and is executable" {
  [ -x "$REPO_ROOT/packages/retrospective/bin/wr-retrospective-measure-context-budget" ]
}

@test "wr-itil-reconcile-readme shim resolves canonical script (smoke)" {
  # Drive the shim against a docs-equivalent path to verify the exec relay
  # works. The script is diagnose-only (exit 0 = clean, 1 = drift, 2 = parse
  # error) — any of those means the shim successfully dispatched the canonical
  # body. Exit 127 (the failure mode P151 closes) would mean the shim itself
  # didn't resolve.
  run "$REPO_ROOT/packages/itil/bin/wr-itil-reconcile-readme" "$REPO_ROOT/docs/problems"
  [ "$status" -ne 127 ]
}

@test "wr-itil-check-problems-readme-budget shim resolves canonical script (smoke)" {
  run "$REPO_ROOT/packages/itil/bin/wr-itil-check-problems-readme-budget" "$REPO_ROOT/docs/problems/README.md"
  [ "$status" -ne 127 ]
}

@test "wr-retrospective-measure-context-budget shim resolves canonical script (smoke)" {
  run "$REPO_ROOT/packages/retrospective/bin/wr-retrospective-measure-context-budget" "$REPO_ROOT"
  [ "$status" -ne 127 ]
}
