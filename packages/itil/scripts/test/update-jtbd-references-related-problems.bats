#!/usr/bin/env bats

# P170 / Phase 4 P4.1 — behavioural fixture for the
# update-jtbd-references-section.sh "Related problems" extension.
# Adds a fourth lookup-table row (alongside RFCs / Story Maps /
# Stories) so JTBD files auto-maintain a `## Related problems`
# reverse-trace section sourced from problem-ticket frontmatter
# `jtbd:` arrays. Mirrors the parallel-existence one-way reverse-
# trace shape from ADR-060 § Phase 3 + Phase 4 in-scope amendment
# (2026-05-13) P4.1.
#
# Per ADR-060 architect finding A4 + JTBD finding F5: lookup-table
# row addition, NOT a new helper. The body MUST remain
# per-section-name-branchless (assertion in
# update-references-section-sibling-helpers.bats).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="$REPO_ROOT/packages/itil/scripts/update-jtbd-references-section.sh"

  WORKSPACE="$(mktemp -d)"
  cd "$WORKSPACE"
  mkdir -p docs/problems/open docs/problems/known-error docs/jtbd/solo-developer

  cat > docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md <<'EOF'
---
status: proposed
job-id: sample-job
persona: solo-developer
date-created: 2026-05-13
---

# JTBD-999: Sample Job

## Job Statement

Sample.

## Desired Outcomes

- Outcome A.
EOF
}

teardown() {
  if [ -n "${WORKSPACE:-}" ] && [ -d "$WORKSPACE" ]; then
    rm -rf "$WORKSPACE"
  fi
}

@test "Related problems: extracts user-business problem citing the JTBD" {
  cat > docs/problems/open/501-business-problem.md <<'EOF'
---
type: user-business
jtbd: [JTBD-999]
persona: solo-developer
---
# Problem 501: Business problem citing JTBD-999

**Status**: Open

## Description

Business problem.
EOF

  run bash "$SCRIPT" docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md "Related problems"
  [ "$status" -eq 0 ]
  grep -q '^## Related problems' docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md
  grep -q '| P501 |' docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md
}

@test "Related problems: ignores problems that don't cite the JTBD" {
  cat > docs/problems/open/502-unrelated.md <<'EOF'
---
type: technical
---
# Problem 502: Unrelated technical problem

**Status**: Open

## Description

Unrelated.
EOF

  run bash "$SCRIPT" docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md "Related problems"
  [ "$status" -eq 0 ]
  ! grep -q '^## Related problems' docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md
}

@test "Related problems: lazy-empty when no problem cites the JTBD" {
  cat > docs/problems/open/503-something-else.md <<'EOF'
---
type: user-business
jtbd: [JTBD-001]
---
# Problem 503: Cites a different JTBD

**Status**: Open
EOF

  run bash "$SCRIPT" docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md "Related problems"
  [ "$status" -eq 0 ]
  ! grep -q '^## Related problems' docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md
}

@test "Related problems: searches per-state subdirs (RFC-002 layout)" {
  cat > docs/problems/known-error/504-business-known-error.md <<'EOF'
---
type: user-business
jtbd: [JTBD-999]
persona: solo-developer
---
# Problem 504: Known-error business problem

**Status**: Known Error
EOF

  run bash "$SCRIPT" docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md "Related problems"
  [ "$status" -eq 0 ]
  grep -q '| P504 |' docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md
}

@test "Related problems: idempotent across re-runs" {
  cat > docs/problems/open/505-idempotent.md <<'EOF'
---
type: user-business
jtbd: [JTBD-999]
persona: solo-developer
---
# Problem 505: Idempotent test

**Status**: Open
EOF

  run bash "$SCRIPT" docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md "Related problems"
  [ "$status" -eq 0 ]
  before_hash=$(md5 -q docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md 2>/dev/null || md5sum docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md | awk '{print $1}')

  run bash "$SCRIPT" docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md "Related problems"
  [ "$status" -eq 0 ]
  after_hash=$(md5 -q docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md 2>/dev/null || md5sum docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md | awk '{print $1}')

  [ "$before_hash" = "$after_hash" ]
}

@test "Related problems: unknown section-name still fails" {
  run bash "$SCRIPT" docs/jtbd/solo-developer/JTBD-999-sample-job.proposed.md "Bogus Section"
  [ "$status" -ne 0 ]
}

@test "Related problems: helper still no per-section-name branch (P4.1 lookup-table-row addition only)" {
  ! grep -E 'case[[:space:]]+"\$\{?section[_-]?name\}?"|if[[:space:]]+\[[[:space:]]+"\$\{?section[_-]?name\}?"[[:space:]]+=' "$SCRIPT"
}
