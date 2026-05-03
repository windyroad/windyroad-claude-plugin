# @windyroad/tdd

**TDD state machine enforcement for Claude Code.** Forces the Red-Green-Refactor cycle so your AI agent writes tests before implementation -- every time.

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

AI agents love to jump straight to implementation. This plugin stops that. It enforces a strict TDD state machine:

```
IDLE ──> RED ──> GREEN ──> RED (next test)
                   │
                   └──> Refactor (staying GREEN)
```

- **IDLE** -- No test written yet. Implementation file edits are blocked.
- **RED** -- A failing test exists. Implementation edits are allowed.
- **GREEN** -- Tests pass. You can refactor or write a new failing test.
- **BLOCKED** -- Test runner error or timeout. Fix the setup before continuing.

The agent must write a failing test first. There are no shortcuts.

## Install

```bash
npx @windyroad/tdd
```

Restart Claude Code after installing.

## Usage

The plugin activates automatically. On first use in a project without a test framework, it directs you to set one up:

```
/wr-tdd:setup-tests
```

This examines your codebase, recommends a test runner, configures `package.json`, and creates an example test.

Once active, the workflow is enforced on every edit:

1. Write a test file (`*.test.ts`, `*.spec.ts`, etc.) that describes the desired behaviour
2. The test must fail (RED state) -- proving the test is meaningful
3. Write the minimum implementation to make it pass (GREEN state)
4. Refactor while keeping tests green
5. Repeat

Test files and config/doc files are always writable regardless of state.

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `tdd-inject.sh` | Every prompt | Injects the current TDD state into the prompt |
| `tdd-enforce-edit.sh` | Edit or Write | Blocks implementation edits in IDLE or BLOCKED state |
| `tdd-post-write.sh` | After edit | Runs tests and transitions the state machine |
| `tdd-review-test.sh` | After edit | Classifies new test files as STRUCTURAL (asserts source content) or BEHAVIOURAL (exercises the target) and surfaces structural-test regressions per [ADR-052](../../docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md) |
| `tdd-setup-marker.sh` | Skill completes | Marks test setup as done |
| `tdd-reset.sh` | Session end | Resets the TDD state |

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Solo developer

- **[JTBD-001 Enforce Governance Without Slowing Down](../../docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md)** — implementation edits are blocked until a failing test exists; the agent cannot "forget" to write the test first.
- **[JTBD-002 Ship AI-Assisted Code with Confidence](../../docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md)** — Red-Green-Refactor enforcement turns the test suite into the agent's safety net, not an after-thought.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/tdd --update
npx @windyroad/tdd --uninstall
```

## Licence

[MIT](../../LICENSE)
