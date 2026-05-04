# R003: Hook regression / behaviour change ships to adopters

A change to a `packages/*/hooks/*.sh` file (or `hooks.json` event registration, or hook prose budget, or a detector that hooks consume) ships under a regular minor/patch bump. Hooks fire on every gated tool call across every adopter session, so any regression — false-deny that blocks legitimate work, false-allow that misses what it was meant to catch, syntax error that fail-opens, byte-budget overflow that truncates inject content — propagates to every installed user the moment they update the plugin cache.

Cascade fan-out is high (one hook fires across thousands of tool calls per adopter per day); detection latency is long (adopters notice over days/weeks); rollback path is slow (npm publish + marketplace cache update + per-adopter reinstall window is days); AFK orchestrator iters can compound a regression for a full overnight run before the user sees output.

## Controls

- **Held-changeset / dogfood-window pattern** (`docs/changesets-holding/`, ADR-042 Rule 7) — hook-bearing changesets land in held area for in-repo dogfood before adopter release. Concurrent holds at any time signal the dogfood pipeline is doing its job (P085 / P064 / P159 are exemplars).
- **Behavioural bats per ADR-052** (`packages/*/hooks/test/*.bats`) — TDD discipline; existing hooks have 15-71-test suites covering documented surfaces.
- **`packages/itil/hooks/itil-changeset-discipline.sh`** (P141) — ensures every plugin source change has a changeset that classifies the bump explicitly.
- **CLAUDE.md briefing** "Plugin hooks run from the marketplace cache, not from source" — sets the agent's expectations so it doesn't test source-tree-locally and ship without dogfood.
- **ADR-045 hook injection budget policy** — per-hook prose budget (≤300 bytes deny; ≤150 bytes additionalContext); prevents context-overflow regression class.

## Watch-out

- Cross-shell portability is a recurring sub-class — hooks tested on macOS bash may fail on adopter zsh / dash. Fixing one without testing the other is the canonical pattern.
- Bundled-plugin hooks with broad matchers (`PreToolUse:Bash|Write|Edit|Read`) have higher cascade than narrow matchers. Wide-matcher changes warrant tighter scrutiny.
- **Same-commit-self-block**: a hook that gates `git commit` and ships in the same commit it gates can self-block if the commit doesn't satisfy the new gate. The bootstrap-commit pattern needs explicit handling.
- Hook prose changes that ship under a `patch` bump but actually shift behaviour are a R005 (semver violation) sub-class; flag those there instead.
