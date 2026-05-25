# @windyroad/connect

> **⚠ BLOCKED (as of 2026-04-15)** — Setup is not currently usable in Claude Code 2.1.108.
> The `--channels` flag removes the `AskUserQuestion`, `EnterPlanMode`, and `ExitPlanMode`
> tools that the interactive setup skill depends on. Tracked upstream at
> [anthropics/claude-code#42292](https://github.com/anthropics/claude-code/issues/42292)
> and internally at
> [P008](../../docs/problems/008-askuserquestion-unavailable-with-channels.open.md).
> Do not attempt setup until this is resolved. The plugin's runtime (sending/receiving
> messages) still works — only the guided setup is blocked.

> **EXPERIMENTAL** — This plugin uses Claude Code's `--channels` feature, which is a
> research preview as of April 2026. The API surface may change. See
> [ADR-006](../../docs/decisions/006-connect-plugin.proposed.md) for details.

Connect Claude Code sessions across repos via Discord so they can collaborate. *Maturity: Experimental.*

## What It Does

When running Claude Code sessions across multiple repos, this plugin lets sessions
communicate — with zero idle token cost. Sessions can hand off findings, ask questions,
share context, or coordinate work. The receiving session wakes up only when a message
arrives, using Discord as the collaboration channel.

**Example:** Session A (repo-a) discovers a bug in a package from repo-b. It sends a
message via `/wr-connect:send`, and Session B (repo-b) receives it immediately through
the Discord channel.

## Install

```bash
npx @windyroad/connect
```

Or via the meta-installer:

```bash
npx @windyroad/agent-plugins --plugin connect
```

## Setup

Run the interactive setup skill:

```
/wr-connect:setup
```

This is an interactive walkthrough that guides you through:
1. Creating a Discord bot (`wr-connect`)
2. Storing credentials (`.env` file, 1Password, or shell profile)
3. Installing the Discord channel plugin
4. Configuring the security allowlist

You can opt out at any point during setup.

## Usage

### Sending a message

```
/wr-connect:send BUG: Widget.parse() throws on null input at line 47
```

### Receiving messages

Start Claude Code with the channels flag:

```bash
claude --channels plugin:discord@claude-plugins-official
```

No explicit "wait" command is needed. The session listens automatically and wakes
when a message arrives.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `WR_CONNECT_BOT_TOKEN` | Discord bot token |
| `WR_CONNECT_CHANNEL_ID` | Discord channel ID |
| `WR_CONNECT_SESSION_NAME` | Human-readable name for this session (e.g. `repo-b`) |

Set these in your shell profile (`~/.zshrc`, `~/.bashrc`) or a `.env` file that is
in `.gitignore`.

## Hooks

| Event | Script | Behaviour |
|-------|--------|-----------|
| SessionStart | `session-start.sh` | Warns if env vars are set but `--channels` is not active. Silent if env vars are not set. Never blocks. |

## Security

- **Bot token is a credential** — it gives anyone who has it the ability to send
  messages to your Claude Code session (which has filesystem and shell access).
  Treat it like a password.
- **Environment variables only** — tokens are never stored in project files.
  This is consistent with the suite's `secret-leak-gate`.
- **Discord allowlist** — configure the Discord channel plugin to only accept
  messages from your own Discord user ID.
- **Private channel** — use a private Discord server or channel.
- **Dedicated bot** — use one bot per developer, not a shared team bot.

## Update

```bash
npx @windyroad/connect --update
```

## Uninstall

```bash
npx @windyroad/connect --uninstall
```

## Licence

MIT
