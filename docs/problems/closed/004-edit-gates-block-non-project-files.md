# Problem 004: Edit Gates Block Non-Project Files

**Status**: Closed
**Reported**: 2026-04-14
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Likely (4) when using Discord plugin

## Description

The architect and JTBD enforce hooks block Write/Edit to files outside the project directory (e.g., `~/.claude/channels/discord/access.json`). These files are user configuration, not project files, and should not require architecture or JTBD review.

## Symptoms

- Writing to `~/.claude/channels/discord/access.json` triggers "BLOCKED: Cannot edit 'access.json' without architecture review"
- Writing to any file with a recognised extension (`.json`, `.md`) outside the project triggers gates
- Workaround: use `bash cat >` to bypass the hook system

## Workaround

Use bash (`cat >` or `echo >`) to write non-project files directly, bypassing the Claude Code tool hook system.

## Impact Assessment

- **Who is affected**: Users of wr-connect plugin during Discord setup
- **Frequency**: During initial setup and access policy changes
- **Severity**: Low — bash workaround is simple but unintuitive
- **Analytics**: N/A

## Root Cause Analysis

### Preliminary Hypothesis

The enforce hooks check the file extension but not whether the file is inside the project directory. They should only gate files within the project root (`$PWD` or the git repo root). Files in `~/.claude/` or other system locations should pass through.

### Investigation Tasks

- [x] Confirmed: hooks didn't check project directory scope
- [x] Added project-root check to all 6 enforce hooks (architect, jtbd, voice-tone, style-guide, risk-policy, tdd)
- [x] BATS tests added for each plugin

## Fix

Added an inline `case` guard near the top of each enforce hook that exits 0 if `FILE_PATH` is absolute and doesn't start with `$PWD/`:

```bash
case "$FILE_PATH" in
  /*)
    case "$FILE_PATH" in
      "$PWD"/*) ;;
      *) exit 0 ;;
    esac
    ;;
esac
```

Relative paths fall through (assumed to be in-project). Absolute paths must be under the project root.

Hooks updated: architect, jtbd, voice-tone, style-guide, risk-policy, tdd. Each has a BATS test verifying the exemption.

## Related

- `packages/architect/hooks/architect-enforce-edit.sh`
- `packages/jtbd/hooks/jtbd-enforce-edit.sh`
- P001 — related gate friction issue
