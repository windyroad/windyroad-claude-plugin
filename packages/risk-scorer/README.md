# @windyroad/risk-scorer

**Pipeline risk scoring, commit/push gates, and secret leak detection for Claude Code.** Scores every change for risk and blocks high-risk commits and pushes before they happen. *Maturity: Experimental.*

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

The risk-scorer plugin brings ISO 31000-aligned risk management to your AI coding workflow. It:

1. **Scores risk** on every edit, assessing cumulative pipeline risk as changes build up
2. **Gates commits** -- blocks `git commit` when cumulative risk exceeds your policy threshold
3. **Gates pushes** -- blocks `git push` for high-risk changesets (use `npm run push:watch` instead)
4. **Detects secrets** -- scans edits for API keys, tokens, passwords, and other credentials before they're written
5. **Reviews plans** -- scores implementation plans for risk before you start building
6. **Gates outbound prose** -- reviews `gh issue/pr` bodies, security advisories, npm publish content, and `.changeset/*.md` drafts for confidential-information leaks before they reach external surfaces

All thresholds are configurable through your project's `RISK-POLICY.md`.

## Install

```bash
npx @windyroad/risk-scorer
```

Restart Claude Code after installing.

## Usage

The plugin works automatically once installed. On first run in a project without a risk policy, it blocks edits and directs you to generate one:

```
/wr-risk-scorer:update-policy
```

This creates a `RISK-POLICY.md` tailored to your project, defining impact levels, likelihood scales, risk appetite, and the risk matrix -- all aligned to ISO 31000.

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `risk-score.sh` | Every prompt | Injects risk scoring context |
| `secret-leak-gate.sh` | Edit or Write | Blocks writes containing secrets |
| `wip-risk-gate.sh` | Edit or Write | Blocks edits if WIP risk hasn't been assessed |
| `risk-policy-enforce-edit.sh` | Edit or Write | Blocks edits if no `RISK-POLICY.md` exists |
| `git-push-gate.sh` | Bash (git push) | Blocks direct `git push`; requires `npm run push:watch` |
| `risk-score-commit-gate.sh` | Bash (git commit) | Blocks commits when risk exceeds threshold |
| `risk-score-plan-enforce.sh` | ExitPlanMode | Ensures plans are risk-scored before execution |
| `plan-risk-guidance.sh` | EnterPlanMode | Injects risk guidance into plan mode |
| `external-comms-gate.sh` | Bash, Edit, Write | Gates outbound prose (`gh issue/pr`, `gh api .../security-advisories`, `npm publish`, `.changeset/*.md`) on confidential-information leak review |
| `wip-risk-mark.sh` | After edit | Records WIP risk assessment |
| `risk-score-mark.sh` | Agent completes | Marks risk review as done; writes external-comms marker on `wr-risk-scorer:external-comms` PASS |
| `risk-hash-refresh.sh` | After Bash | Refreshes content hashes |
| `risk-slide-marker.sh` | Agent or Bash | Slides the review marker forward across non-edit operations so an active review session is not invalidated by intervening Bash or sub-agent calls |

## Agents

The plugin includes six specialised agents:

| Agent | Purpose |
|-------|---------|
| `wr-risk-scorer:agent` | Routes to the appropriate mode-specific agent |
| `wr-risk-scorer:wip` | Assesses cumulative risk after each edit |
| `wr-risk-scorer:pipeline` | Scores pipeline actions (commit, push, release) |
| `wr-risk-scorer:plan` | Reviews implementation plans for risk |
| `wr-risk-scorer:policy` | Validates `RISK-POLICY.md` for ISO 31000 compliance |
| `wr-risk-scorer:external-comms` | Reviews drafts of outbound prose (gh issues/PRs, advisories, npm publish, changeset bodies) for confidential-information leaks per `RISK-POLICY.md` |
| `wr-risk-scorer:inbound-report` | Reviews inbound third-party reports (problem-report issues, Q&A discussions, security-advisory submissions) for Request-risk + Fix-risk per `RISK-POLICY.md` § Inbound Report Risk Classes — sibling of `:external-comms` (NOT extension). Consumed by the assessment-pipeline (P079 / ADR-062). Serves JTBD-301 (verdict-on-close acknowledgement) + JTBD-001 (mechanical-stage carve-out). |

## On-demand assessment skills

| Skill | Purpose |
|-------|---------|
| `/wr-risk-scorer:assess-wip` | WIP risk nudge for the current uncommitted diff |
| `/wr-risk-scorer:assess-release` | Pipeline risk assessment for the unpushed queue (pre-satisfies the commit gate) |
| `/wr-risk-scorer:assess-external-comms` | External-comms leak review for a draft outbound body (pre-satisfies the external-comms gate) |
| `/wr-risk-scorer:assess-inbound-report` | Inbound-report risk review for a third-party submission — two-axis (Request-risk + Fix-risk) classification per `RISK-POLICY.md` (P079 / ADR-062). Serves JTBD-005 (on-demand assessment) + JTBD-202 (pre-flight governance check). |
| `/wr-risk-scorer:create-risk` | Create a standing-risk register entry (interactive authoring; orchestrator-driven prefilled invocation via `--slug` / `--prefill` flags per ADR-059) |
| `/wr-risk-scorer:bootstrap-catalog` | Bootstrap `docs/risks/` register from existing `.risk-reports/` corpus per ADR-059 — walks reports, dedupes by ADR-056 slug, emits one `R<NNN>-<slug>.active.md` per unique slug. Idempotent. Auto-triggers from `/install-updates` Step 6.5.1 when register is empty + `RISK-POLICY.md` present + `.risk-reports/` non-empty |
| `/wr-risk-scorer:update-policy` | Generate or update `RISK-POLICY.md` |

## External-comms gate

The `external-comms-gate.sh` hook intercepts outbound prose tool calls and the
`.changeset/*.md` author surface so confidential-information leaks are caught
before they reach a public or vendor-private channel.

Gated surfaces:
- `gh issue create` / `gh issue comment` / `gh issue edit`
- `gh pr create` / `gh pr comment` / `gh pr edit`
- `gh api .../security-advisories` and `gh api .../comments`
- `npm publish`
- `PreToolUse:Write` and `PreToolUse:Edit` on `.changeset/*.md` (P073 — gated at author time, before the changeset body lands in CHANGELOG.md and every published npm tarball)

Behaviour:
1. A hybrid regex pre-filter (`hooks/lib/leak-detect.sh`) catches high-confidence
   leak shapes (credentials, business-context-paired financial figures and
   user-counts) and denies immediately with the matched class.
2. Anything not pre-filtered is delegated to the `wr-risk-scorer:external-comms`
   subagent for context-aware review against `RISK-POLICY.md` Confidential
   Information classes. The PostToolUse marker hook writes a per-draft marker
   on `EXTERNAL_COMMS_RISK_VERDICT: PASS`.
3. If `RISK-POLICY.md` is absent, the gate runs in advisory-only mode and
   permits the call (graceful adoption).

Override: `BYPASS_RISK_GATE=1` short-circuits the gate (consistent with
`git-push-gate.sh`). Reserved for cases the user has confirmed safe.

The canonical hook lives at `packages/shared/hooks/external-comms-gate.sh` and
is synced into each consumer plugin via `scripts/sync-external-comms-gate.sh`
per ADR-017 (CI runs `npm run check:external-comms-gate` to detect drift).

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Tech lead / consultant

- **[JTBD-202 Run Pre-Flight Governance Checks Before Release or Handover](../../docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md)** — `/wr-risk-scorer:assess-release` produces a structured release-readiness score (commit, push, release layers) that is attachable to a release note or handover doc.

### Solo developer

- **[JTBD-001 Enforce Governance Without Slowing Down](../../docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md)** — pipeline risk is scored on every edit, commit, and push without manual invocation; secret-leak detection runs in the same gate.
- **[JTBD-002 Ship AI-Assisted Code with Confidence](../../docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md)** — every release passes through ISO 31000-aligned criteria defined in the project's own `RISK-POLICY.md` so the safety bar is the team's, not the agent's.
- **[JTBD-005 Invoke Governance Assessments On Demand](../../docs/jtbd/solo-developer/JTBD-005-assess-on-demand.proposed.md)** — `/wr-risk-scorer:assess-wip`, `assess-release`, and `assess-external-comms` give an on-demand assessment surface outside the hook gate cycle.

### Plugin user

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/risk-scorer --update
npx @windyroad/risk-scorer --uninstall
```

## Licence

[MIT](../../LICENSE)
