# Problem 008: AskUserQuestion Unavailable When --channels Is Active

**Status**: Parked
**Reported**: 2026-04-15
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost Certain (5) when using connect plugin

## Description

The AskUserQuestion tool (and EnterPlanMode/ExitPlanMode) is not available when Claude Code is started with `--channels plugin:discord@claude-plugins-official`. This makes interactive skills that depend on AskUserQuestion (like `/wr-connect:setup`) unusable in the very sessions where the connect plugin is meant to be used.

Tested:
- Session started without `--channels` — AskUserQuestion available
- Session started with `--channels plugin:discord@claude-plugins-official` — AskUserQuestion, EnterPlanMode, ExitPlanMode all removed

## Symptoms

- `ToolSearch` with `select:AskUserQuestion` returns "No matching deferred tools found" in `--channels` sessions
- Setup skill's structured-question flow cannot run
- Users must choose between interactive setup and Discord messaging — can't have both in one session

## Workaround

Run setup in a session without `--channels` (steps 1-7), then restart with `--channels` for pairing (stages 8+). Setup skill's Stage 7 already documents the restart — but the user then loses AskUserQuestion for stages 8-13.

## Status: Parked pending upstream (2026-04-15)

Blocker is in Claude Code's `--channels` flag, not our code. Upstream issues filed (see Related). Reopen when upstream moves or when the connect plugin becomes a higher priority than other work. A local fallback (plain-prompt path when AskUserQuestion is unavailable) is possible but deferred until then — the two-session workaround is usable.

## Impact Assessment

- **Who is affected**: Every wr-connect user running the setup skill
- **Frequency**: Every setup
- **Severity**: Medium — creates a chicken-and-egg where the setup tool can't run in the session it's configuring
- **Analytics**: N/A

## Root Cause Analysis

### Preliminary Hypothesis

Possible causes (not yet investigated):

1. **`--channels` replaces the default tool set** — the flag may swap the MCP tool manifest for a channel-specific one that omits AskUserQuestion/EnterPlanMode/ExitPlanMode.
2. **Tool conflict** — AskUserQuestion may itself be a deferred/MCP-provided tool that conflicts with the Discord plugin's tool registration.
3. **Claude Code bug** — `--channels` may not compose correctly with the default tool set.

### Investigation Tasks

- [ ] Check Claude Code docs/release notes for `--channels` tool-set behaviour
- [ ] File an issue on `anthropics/claude-code` if confirmed platform bug
- [ ] Decide how wr-connect should handle this — fallback to plain prompts, or document the two-session dance

## Related

- `packages/connect/skills/setup/SKILL.md` — currently refuses to run without AskUserQuestion
- ADR-006 — connect plugin decision
- P007 — related platform limitation (Discord plugin doesn't deliver reactions)
- Upstream issue (canonical): https://github.com/anthropics/claude-code/issues/42292
- Related upstream issues:
  - https://github.com/anthropics/claude-code/issues/41787 (suggests per-prompt gating instead of global suppression)
  - https://github.com/anthropics/claude-code/issues/40644 (AskUserQuestion specifically)
- Our duplicate (closed): https://github.com/anthropics/claude-code/issues/48216
