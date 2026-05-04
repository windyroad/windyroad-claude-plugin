# R004: Ambient / unstaged state included in commits

A commit using `git add -A` / `git add .` (or a too-broad `git add <glob>`) captures session-ambient files that should have stayed local: `.claude/settings.json` modifications (user-machine-specific config, sometimes API key fragments), `.afk-run-state/*.jsonl` (queue files revealing session structure), `/tmp/<session-marker>` artefacts, novel `.claude/.foo-marker` classes that haven't been added to `.gitignore` yet.

The agent has Bash access including `git add` and the ambient state surfaced in `git status` is non-deterministic (varies per session, OS, Claude Code version). `.gitignore` covers known classes; novel classes appear with new plugin features and aren't covered until someone notices.

## Controls

- **`.gitignore`** — covers `.claude/settings.local.json`, `.afk-run-state/`, `/tmp/`, `node_modules/`, etc. Covers known classes; zero coverage for novel classes until added.
- **CLAUDE.md P131** "Never write project-generated artefacts under `.claude/`" — discipline rule preventing agents from creating new ambient classes that escape `.gitignore`.
- **`git add <specific-paths>` discipline** over `git add -A` / `git add .` — codified in many SKILL.md files (manage-problem, transition-problem, etc.).
- **gitStatus visibility per-prompt** — every prompt shows ambient files; agent can see and avoid staging them.

## Watch-out

- Throughout typical sessions, `.claude/settings.json` is persistently modified-not-staged — discipline is the only thing preventing accidental inclusion.
- New plugin features can introduce new ambient classes (markers, queues, caches) that aren't in `.gitignore` until someone notices. Lag window is days-to-weeks.
- False-positive sub-class: agent annotates a ticket about an ambient class, then auto-stages the very ambient file the ticket references. Always re-check `git status` before bulk staging.
- Pre-existing test failures showing up in `git status` (e.g., flaky/known-broken bats results) are an "ambient broken state" sub-class — they can leak into commits as if the commit fixed them, when actually they regressed earlier and just weren't reverted.
