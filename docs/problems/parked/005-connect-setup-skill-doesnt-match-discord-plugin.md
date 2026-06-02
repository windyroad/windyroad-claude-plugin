# Problem 005: Connect Setup Skill Doesn't Match Discord Plugin Flow

**Status**: Parked
**Reported**: 2026-04-14
**Priority**: 20 (Very High) — Impact: Significant (4) x Likelihood: Almost Certain (5) on first setup

## Description

The wr-connect setup skill (`/wr-connect:setup`) has its own credential storage flow (env vars, .env file, 1Password) that doesn't match how the Discord channel plugin actually works. The Discord plugin uses `/discord:configure <token>` to store the token at `~/.claude/channels/discord/.env` and requires `--channels` flag to connect. The setup skill doesn't know about any of this.

## Symptoms

- Setup skill guides user to store bot token in project `.env` or shell profile
- But the Discord plugin expects the token via `/discord:configure`
- Setup skill doesn't mention the `--channels` flag is required
- Setup skill doesn't guide through pairing (DM the bot, get code, `/discord:access pair <code>`)
- Setup skill doesn't guide through lockdown (`/discord:access policy allowlist`)
- User ends up with credentials in the wrong place and a non-functional setup

## Workaround

Ignore the setup skill's credential steps and follow the Discord plugin's own README (`~/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/README.md`).

## Impact Assessment

- **Who is affected**: Every user setting up wr-connect for the first time
- **Frequency**: Every first-time setup
- **Severity**: High — setup doesn't work as documented
- **Analytics**: N/A

## Root Cause Analysis

### Confirmed Root Cause

The setup skill was written based on the original proposal (which assumed env vars for credential storage) before the actual Discord plugin was examined. The Discord plugin has its own setup flow (`/discord:configure`, `--channels`, pairing, allowlist) that the setup skill needs to integrate with rather than replace.

### Fix Strategy

Rewrite the setup skill to:
1. Detect the git remote to suggest a bot name (org/repo format)
2. Guide through Discord bot creation (same as now)
3. Use `/discord:configure <token>` instead of writing env vars
4. Explain `--channels` flag and restart requirement
5. Guide through DM pairing and `/discord:access pair <code>`
6. Guide through lockdown (`/discord:access policy allowlist`)
7. Guide through guild channel setup (`/discord:access group add <channel-id>`)
8. The `.env.tpl` / `WR_CONNECT_*` env vars become optional metadata (session name, channel ID for the send skill) rather than the primary credential store

### Investigation Tasks

- [x] Confirm root cause — setup skill doesn't match Discord plugin flow
- [x] Read Discord plugin README for correct flow
- [x] Rewrite setup skill to integrate with Discord plugin
- [ ] Test end-to-end setup flow in a clean project
- [ ] Release and verify fix

## Fix Released

Setup skill rewritten to use `/discord:configure`, `--channels`, DM pairing,
`/discord:access pair`, allowlist lockdown, and guild channel setup. Each repo
gets its own bot named after org/repo. Awaiting release and verification.

## Parked

**Reason**: Upstream Claude Code bug — `--channels` flag removes `AskUserQuestion` (P008). All connect plugin work is suspended until the upstream bug is resolved.
**Un-park trigger**: P008 resolved upstream (Anthropic fixes `--channels` to preserve `AskUserQuestion`).
**Parked**: 2026-04-16

## Related

- `packages/connect/skills/setup/SKILL.md` — the setup skill to rewrite
- `~/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/README.md` — Discord plugin's actual setup flow
- ADR-006 — connect plugin decision (credential storage section needs updating)
