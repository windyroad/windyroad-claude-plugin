#!/usr/bin/env bats

# P139: Repo-local skills under .claude/skills/ pay architect-gate
# overhead on every edit. Fix: source-of-truth lives at
# scripts/repo-local-skills/<skill-name>/; .claude/skills/<skill-name>/
# carries relative symlinks pointing back to the source. ADR-030's
# Symlink Contract section governs the shape (relative; per-file
# for SKILL.md/REFERENCE.md; directory-level allowed for test/;
# source-of-truth files are regular files, not symlinks).

setup() {
  # This test file lives at scripts/repo-local-skills/install-updates/test/
  # — 4 levels below repo root. (.claude/skills/install-updates/test/ is
  # also 4 levels below repo root, so the path math is invariant under
  # symlink-resolution.)
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  CLAUDE_SKILL_DIR="$REPO_ROOT/.claude/skills/install-updates"
  SOURCE_SKILL_DIR="$REPO_ROOT/scripts/repo-local-skills/install-updates"
}

@test "P139: source-of-truth SKILL.md exists at scripts/repo-local-skills/install-updates/" {
  [ -f "$SOURCE_SKILL_DIR/SKILL.md" ]
  # Source-of-truth must be a regular file, not a symlink (avoid loops
  # or chained resolution per ADR-030 Symlink Contract).
  [ ! -L "$SOURCE_SKILL_DIR/SKILL.md" ]
}

@test "P139: source-of-truth REFERENCE.md exists at scripts/repo-local-skills/install-updates/" {
  [ -f "$SOURCE_SKILL_DIR/REFERENCE.md" ]
  [ ! -L "$SOURCE_SKILL_DIR/REFERENCE.md" ]
}

@test "P139: .claude/skills/install-updates/SKILL.md is a symlink" {
  [ -L "$CLAUDE_SKILL_DIR/SKILL.md" ]
}

@test "P139: .claude/skills/install-updates/REFERENCE.md is a symlink" {
  [ -L "$CLAUDE_SKILL_DIR/REFERENCE.md" ]
}

@test "P139: SKILL.md symlink target is relative (not absolute)" {
  local target
  target=$(readlink "$CLAUDE_SKILL_DIR/SKILL.md")
  # Reject absolute paths — they break across clones / worktrees / repo moves.
  [[ "$target" != /* ]]
}

@test "P139: REFERENCE.md symlink target is relative" {
  local target
  target=$(readlink "$CLAUDE_SKILL_DIR/REFERENCE.md")
  [[ "$target" != /* ]]
}

@test "P139: SKILL.md symlink resolves to source-of-truth" {
  # Behavioural — confirm Claude Code's slash-command resolver (which
  # follows symlinks transparently when reading file content) sees the
  # same content via .claude/skills/install-updates/SKILL.md as it does
  # via scripts/repo-local-skills/install-updates/SKILL.md. This is the
  # JTBD-006 / persona-discoverability invariant ADR-030 protects.
  local symlink_content source_content
  symlink_content=$(cat "$CLAUDE_SKILL_DIR/SKILL.md")
  source_content=$(cat "$SOURCE_SKILL_DIR/SKILL.md")
  [ "$symlink_content" = "$source_content" ]
}

@test "P139: REFERENCE.md symlink resolves to source-of-truth" {
  local symlink_content source_content
  symlink_content=$(cat "$CLAUDE_SKILL_DIR/REFERENCE.md")
  source_content=$(cat "$SOURCE_SKILL_DIR/REFERENCE.md")
  [ "$symlink_content" = "$source_content" ]
}

@test "P139: test/ symlink resolves to source-of-truth test directory" {
  # ADR-030 Symlink Contract permits a single directory-level symlink
  # for test/ because adding a new bats file is a routine TDD action.
  [ -L "$CLAUDE_SKILL_DIR/test" ]
  # The resolved path must be a directory.
  [ -d "$CLAUDE_SKILL_DIR/test/" ]
  # And it must reach the same files as the source-of-truth directory.
  local symlink_listing source_listing
  symlink_listing=$(ls "$CLAUDE_SKILL_DIR/test/" | sort)
  source_listing=$(ls "$SOURCE_SKILL_DIR/test/" | sort)
  [ "$symlink_listing" = "$source_listing" ]
}

@test "P139: gate-exclusion audit — architect hook does NOT exclude scripts/" {
  # Failing this test means a future change added a scripts/* carve-out
  # to the architect gate, which would silently re-introduce the
  # per-edit gate-skip P139 was closed by relocating AWAY from. Edits
  # to scripts/repo-local-skills/<name>/ MUST go through the normal
  # architect review path.
  local hook="$REPO_ROOT/packages/architect/hooks/architect-enforce-edit.sh"
  [ -f "$hook" ]
  ! grep -E '\*?/?scripts/\*|/scripts/repo-local-skills' "$hook"
}

@test "P139: gate-exclusion audit — JTBD hook does NOT exclude scripts/" {
  local hook="$REPO_ROOT/packages/jtbd/hooks/jtbd-enforce-edit.sh"
  [ -f "$hook" ]
  ! grep -E '\*?/?scripts/\*|/scripts/repo-local-skills' "$hook"
}
