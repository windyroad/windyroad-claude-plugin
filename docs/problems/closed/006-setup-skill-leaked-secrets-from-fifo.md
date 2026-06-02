# Problem 006: Setup Skill Leaked Secrets by Reading 1Password FIFO

**Status**: Closed (documented guidance only; no enforceable code fix)
**Reported**: 2026-04-14
**Priority**: 10 (High) — Impact: Severe (5) x Likelihood: Unlikely (2)

## Description

During the wr-connect setup, the agent ran `cat .env` to check the file format. The `.env` was a 1Password FIFO (named pipe) that served all resolved secrets from the 1Password vault — including API keys, tokens, and passwords for multiple services (OpenAI, GitHub, npm, MongoDB, Clerk, Cloudflare, Namecheap). All secrets were dumped into the conversation context.

## Symptoms

- `cat .env` on a FIFO reads the full secret payload into the conversation
- All secrets from the 1Password environment were exposed in the Claude Code session
- Credentials need rotation after exposure

## Workaround

Never `cat`, `head`, `tail`, or `Read` a `.env` file without first checking if it's a FIFO (`[ -p .env ]`). If it is a FIFO, do not read it.

## Impact Assessment

- **Who is affected**: Anyone using 1Password's environment injection with the FIFO approach
- **Frequency**: Rare — only happens if the agent reads the .env file
- **Severity**: Severe — full credential dump into conversation context
- **Analytics**: N/A

## Root Cause Analysis

### Confirmed Root Cause

The agent ran `cat .env` without checking the file type. The `.env` was a named pipe (FIFO) created by 1Password's desktop app "Environments" feature. Reading a FIFO consumes its content and serves all resolved secrets, not template references.

### Fix Strategy — REJECTED

Initial strategy proposed in-plugin mitigations (FIFO check in setup skill; secret-leak-gate detection of FIFO reads). On review these were rejected:

1. **Setup-skill FIFO check**: narrowly scoped — only fires in one skill, doesn't prevent the agent from `cat`ing any other `.env` FIFO anywhere.
2. **secret-leak-gate FIFO detection**: architecturally messy — the gate operates on Edit/Write, not Read/Bash output. Intercepting reads would require a fundamentally different hook.
3. **CLAUDE.md rule**: only effective for users who install the rule; many don't.

The root cause is a general agent-behaviour concern (be careful with `.env` files that may be FIFOs), not something our plugin suite can enforce in code for the whole ecosystem.

### Resolution

Documented in `docs/BRIEFING.md`:

> `.env` may be a 1Password FIFO (named pipe). Never `cat >` to it. Use `.env.tpl` with `op://` references and `op inject -i .env.tpl -o .env` instead.

Closing as **accepted behaviour** — agents working in this repo will read the briefing and be aware. Users of the plugins downstream need to be aware through their own practices. We have no mechanism to enforce this globally.

### Investigation Tasks

- [x] Confirm root cause — agent read FIFO without checking type
- [x] Rejected in-plugin mitigations as too narrow / architecturally unfit
- [x] Documented in BRIEFING.md
- [x] Closed as "not solvable in our code"

## Related

- `packages/connect/skills/setup/SKILL.md` — setup skill that triggered the read
- `packages/risk-scorer/hooks/secret-leak-gate.sh` — could be extended to detect FIFO reads
- P005 — related setup flow issues
