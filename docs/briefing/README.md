# Project Briefing

Cross-session learnings captured via `/wr-retrospective:run-retro`. Split into per-topic files under this directory so each file stays naturally bounded. Progressive-disclosure entry point for future sessions.

## Critical Points (Session-Start Surface)

The highest-value entries across the briefing — the handful of rules that save the most wasted turns. A future SessionStart hook (P100 slice 2) surfaces this list at session start so the agent sees them without reading the full tree.

- **Risk appetite is Low (4).** Changes scoring Medium (5+) need explicit acknowledgement. See `RISK-POLICY.md`.
- **Four edit gates fire on every edit** (architect, JTBD, WIP risk, TDD). Each requires its own agent delegation; markers have a ~3600s TTL and may expire mid-session on very long batches. Plan for the re-review cycle.
- **Plugin hooks run from the marketplace cache, not from source.** Editing a hook file does not change hook behaviour until push + `claude plugin marketplace update` + reinstall + restart.
- **Never run `changeset version` locally.** Release via `push:watch` then `release:watch`. The git-push-gate blocks bare `git push`.
- **`changeset publish` E404 on an existing scoped package = an npm-auth/2FA failure masked as 404, NOT a missing package.** Siblings "publishing fine" only SKIPPED (read-only `npm info`); the new-version package is the sole token-write. Ladder: `npm whoami` with the token → if valid-but-can't-publish, the token lacks **Bypass-2FA** (use an Automation/Granular token, not a "Publish" token). A fresh token surfaces the real `EOTP`. Fix → update `NPM_TOKEN`/`NPM_AUTH_TOKEN` secrets, re-run `release:watch`. Main self-poisons every push until fixed. See `releases-and-ci.md`, P284. (2026-05-24.)
- **The plugin install cache is GLOBAL/shared across projects** — refreshing it from one project (`uninstall + install`) advances the version for every project that enables the plugin; there is no per-project cache (settings.json carries no version pin). Drove the 2026-05-25 `/install-updates` simplification to a single current-project refresh. See `plugin-distribution-cache-mechanics.md`.
- **AFK iteration-workers use `claude -p` subprocess dispatch**, not Agent-tool spawning. Subagents spawned via `Agent` cannot spawn further subagents; iteration-workers that need architect/JTBD/risk gates must be subprocesses.
- **`git mv` + `Edit` + `git add` requires re-stage after the Edit** — `git mv` alone stages only the rename. Miss this and content edits leak into the next commit.
- **`claude plugin install` is a silent no-op when already installed at any version** — does NOT refresh to npm latest. `plugin update` rejects project scope. The refresh pattern is `uninstall + install`. Check cache dir vs `npm view` after any release; don't trust `✔ already installed` as "latest" (P106).
- **Multi-decision-file changes DEADLOCK the architect edit-gate.** Editing ≥2 `docs/decisions/` files in one session can't pass it: verdict-grep treats a thorough review's conditions as FAIL (P181/P217) + the gate re-locks on each decision-file edit via hash drift (P215/P216/P226) + post-approval re-reviews fail because the work isn't on disk yet. After a genuine approving architect review, recover: assert `/tmp/architect-reviewed-$SID` + `rm` the `.hash` sibling (user-authorised — load-bearing-gate bypass). Bites any multi-ADR rework (P290/P298 next). See `hooks-and-gates.md`, P303. (2026-05-25.)
- **A commit that removes/narrows a load-bearing currency hook is blocked by the cached OLD hook; `BYPASS_*=1` can't reach it (P173) — commit from an EXTERNAL terminal** (the PreToolUse gate only intercepts in-session commits; write the msg to `.git/<name>.txt`, session `/tmp` is sandboxed). See `hooks-and-gates.md`, memory `feedback_land_gate_blocked_commit_externally`. (2026-05-25.)
- **Progressive disclosure is the session-wide unifying pattern** for context-budget problems (ADR-038). Less info upfront + explicit affordances (agent pointers, REFERENCE.md paths); consumers expand on demand. This briefing directory is an instance of the pattern.
- **Voice-tone hook gates `.html` writes anywhere in the project** when `docs/VOICE-AND-TONE.md` does not exist — even dev-tooling internal HTML. Hook is extension-only; no path-based exemption mechanism. Author the policy doc + delegate to `wr-voice-tone:agent` per artefact OR extend the hook source (requires marketplace cache release cycle). See `hooks-and-gates.md`. (P170 Phase 2 Slice 8 bootstrap blocker, 2026-05-12.)
- **Conditional phase deferrals can lift; re-check before parent-ticket transitions.** Language like "Phase N SHIP deferred to post-Phase-M-graduation" is a CONDITIONAL deferral that becomes in-scope when Phase M graduates — NOT a permanent "out of scope". P184 captures the agent failure mode where this was missed; would have silently lost Phase 2 work if user hadn't asked an orthogonal question.

## Topic Index

| File | Topic | When to load |
|---|---|---|
| [hooks-and-gates.md](./hooks-and-gates.md) | PreToolUse / PostToolUse gates, marker TTLs, exemptions, per-prompt terse reminders | Any edit-gate friction, hook-script work, understanding why a write was blocked. |
| [releases-and-ci.md](./releases-and-ci.md) | push:watch, release:watch, changesets, npm publish, GitHub Actions pipeline | Any release work, CI debugging, workflow authoring, bypass-marker behaviour. |
| [governance-workflow.md](./governance-workflow.md) | ADRs, architect/JTBD reviews, risk scoring, voice-tone, canonical+sync, SKILL+REFERENCE | ADR drafting, governance skill work, session-wide pattern application. |
| [afk-subprocess.md](./afk-subprocess.md) | `/wr-itil:work-problems` AFK loops, `claude -p` subprocess, iteration workers | AFK orchestrator work, subprocess dispatch debugging, iteration-worker protocol. |
| [plugin-distribution.md](./plugin-distribution.md) | Skill invocation grammar, Discord wiring, 1Password env, npm package naming | Plugin naming, Discord setup, environment setup. |
| [plugin-distribution-cache-mechanics.md](./plugin-distribution-cache-mechanics.md) | Marketplace cache, install/uninstall/refresh patterns, manifest validator, worktree shadowing, TUI vs agent enumerator | Plugin install / refresh / publish work, `/install-updates` debugging, broken-manifest recovery. |
| [agent-interaction-patterns.md](./agent-interaction-patterns.md) | Framing validation, re-stage traps, user-frustration signals | Before asking the user solution-detail questions; ticket-framing checks. |

> **Archive siblings** (Tier 3 budget rotations per P145, multi-pass 2026-05-11 / 13 / 17): topic files have date-stratified archives. Load alongside the primary file when full historical context is needed.
> - `hooks-and-gates-archive.md` (2026-05-04/05) + `hooks-and-gates-archive-pre-2026-05-04.md` (2026-04-19 through 04-26)
> - `governance-workflow-archive.md` (2026-05-04/05/12) + `governance-workflow-archive-mid.md` (2026-04-23/24/25) + `governance-workflow-archive-pre-2026-04-23.md` (2026-04-19 through 04-22)
> - `governance-workflow-surprises.md` (sibling brief — ADR mechanics, JTBD reviewer behaviour, README-refresh reconciliation)
> - `releases-and-ci-archive.md` (older release-pipeline entries)
> - `afk-subprocess-mechanics.md` + `afk-subprocess-recovery.md` (sibling briefs split out 2026-05-03) + `afk-subprocess-recovery-archive.md` (oldest recovery entries, 2026-05-26)
> - `agent-hook-gate-quirks.md` (sibling brief — hook-gate quirks)
> - `agent-interaction-patterns-archive.md` (settled/codified entries split out 2026-05-26 — P057 re-stage, P014 framing, P121 Fix-Strategy-premise)

## How to Use

- **At session start**: the Critical Points section above is the intended session-start surface. Load this README first; expand topic files on demand.
- **When a topic becomes relevant** during a task, load the matching topic file only. Files are append-only across retros; entries remain stable across sessions.
- **When authoring a retro** via `/wr-retrospective:run-retro`: read this README, then the topic file(s) whose scope matches the new learning, add to the appropriate section, update the topic-file summary if the entry changes the file character, and refresh the Critical Points section only when a new entry is genuinely the highest-value rule of the session.

## Relationship to `docs/BRIEFING.md`

During P100 slice 1 (2026-04-22), `docs/BRIEFING.md` was split into this tree. The original path is retained as a short transitional stub that points here — slice 2 will retire it once the SessionStart hook (P100 slice 2 scope) makes the stub unnecessary.
