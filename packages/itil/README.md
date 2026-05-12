# @windyroad/itil

**ITIL-aligned IT service management for Claude Code.** Track recurring incidents, perform root cause analysis, and prioritise fixes using WSJF -- all inside your coding sessions.

Part of [Windy Road Agent Plugins](../../README.md).

## What It Does

Bugs recur. Incidents repeat. Without a disciplined process, you fix symptoms instead of causes — or worse, jump to conclusions during a live outage. This plugin brings lightweight ITIL service management to your AI coding workflow:

**Problem management** — track underlying causes and prioritise fixes:

- **Create problem tickets** when incidents or failures surface during a session
- **Track root cause analysis** as investigation progresses
- **Transition status** through a structured lifecycle: Open, Known Error, Closed
- **Prioritise** using Weighted Shortest Job First (WSJF) to focus on the highest-value fixes

**Incident management** — restore service fast with an audit trail:

- **Declare incidents** when production is actively broken
- **Evidence-first discipline** — hypotheses must cite evidence before any mitigation
- **Reversible mitigations first** — rollback, feature flag, restart, route away
- **Automatic handoff** to problem management once service is restored

Tickets live in `docs/problems/` and `docs/incidents/` as markdown files — version-controlled and always accessible.

Room is reserved for peer ITIL skills (change, continual improvement) under the same plugin as they are added.

## Install

```bash
npx @windyroad/itil
```

Restart Claude Code after installing.

> **Requires:** [`@windyroad/risk-scorer`](../risk-scorer/). The installer warns if it's missing.
>
> **Renamed from `@windyroad/problem`** — see [ADR-010](../../docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md). If you had the old package installed, uninstall it (`npx @windyroad/problem --uninstall`) before installing `@windyroad/itil`.

## Usage

**Manage a problem ticket:**

```
/wr-itil:manage-problem
```

Supports creating new problems, updating root cause analysis, transitioning status (Open → Known Error → Closed), and closing problems with resolution details.

**Manage an incident:**

```
/wr-itil:manage-incident
```

Supports declaring new incidents, recording evidence-first observations and hypotheses, logging mitigation attempts, transitioning lifecycle (Investigating → Mitigating → Restored → Closed), and automatically handing off to `manage-problem` when service is restored.

See [ADR-011](../../docs/decisions/011-manage-incident-skill.proposed.md) for the incident-vs-problem split and [JTBD-201](../../docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md) for the job this serves.

## How It Works

| Hook | Trigger | What it does |
|------|---------|-------------|
| `bin/check-deps.sh` | Session start | Verifies that `wr-risk-scorer` is installed |
| `itil-assistant-output-gate.sh` | Every prompt | Detects classes of assistant output (e.g. prose-asks vs `AskUserQuestion`) that indicate ITIL-discipline regressions |
| `itil-correction-detect.sh` | Every prompt | Surfaces strong-signal user corrections (FFS / DO NOT / contradictions) and offers a problem ticket capture per P078 |
| `itil-runtime-sid-marker.sh` | Bash, Edit, Write, Read | Records per-session ID for runtime instrumentation (ADR-050) |
| `manage-problem-enforce-create.sh` | Write | Blocks creation of `docs/problems/*.md` outside the `/wr-itil:manage-problem` workflow |
| `itil-claude-space-protection.sh` | Write, Edit | Prevents project-generated artefacts from being written under `.claude/` (P131) |
| `p057-staging-trap-detect.sh` | Bash | Detects the P057 staging trap during ticket transitions |
| `pre-publish-intake-gate.sh` | Bash | Blocks `npm publish` when downstream OSS intake scaffolding is missing (ADR-036) |
| `itil-changeset-discipline.sh` | Bash | Gates `git commit` on changeset coverage for source-package changes (P141) |
| `itil-assistant-output-review.sh` | Stop | Reviews assistant output at session end for ITIL-discipline patterns |

## Skills

| Skill | Purpose |
|-------|---------|
| `/wr-itil:manage-problem` | Create, update, and close problem tickets through the Open → Known Error → Verifying → Closed lifecycle |
| `/wr-itil:capture-problem` | Foreground-lightweight aside-invocation variant of `manage-problem` (per ADR-032 background-capture pattern + P078 capture-on-correction) — drafts a ticket scaffold without losing the operational thread when a problem signal surfaces mid-conversation |
| `/wr-itil:work-problem` | Pick the highest-WSJF actionable ticket and work it to completion |
| `/wr-itil:work-problems` | AFK orchestrator — batch-work the problem backlog by WSJF priority while the user is away |
| `/wr-itil:list-problems` | Read-only display of the open and known-error backlog sorted by WSJF |
| `/wr-itil:transition-problem` / `/wr-itil:transition-problems` | Advance one or many tickets through the lifecycle |
| `/wr-itil:review-problems` | Re-rate every open and known-error ticket and refresh the WSJF ranking |
| `/wr-itil:reconcile-readme` | Detect and correct drift between `docs/problems/README.md` and on-disk ticket inventory |
| `/wr-itil:report-upstream` | Report a local problem as a structured issue against an upstream repository (ADR-024) |
| `/wr-itil:capture-rfc` | Lightweight RFC-capture skill — mandatory problem-trace per ADR-060 I1 invariant; opens a coordinated multi-commit change traceable to ≥ 1 driving problem (Phase 1 of the Problem-RFC-Story framework, P170 / ADR-060) |
| `/wr-itil:manage-rfc` | Heavyweight RFC intake + lifecycle management — proposed → accepted → in-progress → verifying → closed; sibling to `manage-problem` at the RFC tier (ADR-060) |
| `/wr-itil:capture-story` | Lightweight story-capture skill — mandatory problem-trace AND JTBD-trace per ADR-060 I6 + I9 invariants; optional `--rfc` / `--story-map` flags (I7 + I8 enforce at `accepted` transition); drafts an INVEST-shaped sub-workstream entity under a parent RFC (Phase 2 of the Problem-RFC-Story framework, P170 / ADR-060) |
| `/wr-itil:manage-incident` | Declare, triage, mitigate, and close an incident with evidence-first discipline |
| `/wr-itil:list-incidents` | Read-only display of active incidents by severity |
| `/wr-itil:mitigate-incident` / `/wr-itil:restore-incident` / `/wr-itil:close-incident` / `/wr-itil:link-incident` | Incident lifecycle transitions (ADR-011) |
| `/wr-itil:scaffold-intake` | Scaffold OSS intake surfaces (`.github/ISSUE_TEMPLATE/`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`) for downstream adopters (ADR-036) |

## Jobs to be Done

This plugin serves the [Jobs to be Done](../../docs/jtbd/) below. Per [ADR-051](../../docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md), the persona-grouped JTBD anchor is the canonical source of truth for the README's value framing.

### Plugin user

- **[JTBD-301 Report a Problem Without Pre-Classifying It](../../docs/jtbd/plugin-user/JTBD-301-report-problem-without-pre-classifying.proposed.md)** — adopters who hit a problem with an installed `@windyroad/*` plugin describe what they observed; `/wr-itil:scaffold-intake` provisions the intake template downstream so triage decides the category, not the reporter.

### Tech lead / consultant

- **[JTBD-201 Restore Service Fast with an Audit Trail](../../docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md)** — the manage-incident skill carries an evidence-first lifecycle (investigating → mitigating → restored → closed), with handoff to manage-problem for the root-cause work.

### Solo developer

- **[JTBD-006 Progress the Backlog While I'm Away](../../docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md)** — `/wr-itil:work-problems` is the AFK orchestrator that loops through the WSJF-ranked backlog, working tickets without interactive input until quota or a stop condition fires.
- **[JTBD-008 Decompose a Fix Into Coordinated Changes](../../docs/jtbd/solo-developer/JTBD-008-decompose-fix-into-coordinated-changes.proposed.md)** — `/wr-itil:capture-rfc` + `/wr-itil:manage-rfc` are the capture-time decomposition surface for multi-commit coordinated changes traced to a driving problem (Phase 1); `/wr-itil:capture-story` is the INVEST-shaped sub-workstream surface for individual slices under those coordinated changes (Phase 2 — story tier). The I1 trace-to-problem invariant is gate-enforced at capture-rfc time; I6 + I9 problem-and-JTBD-trace invariants are gate-enforced at capture-story time (P170 / ADR-060).

### Plugin user (currency anchor)

- **[JTBD-302 Trust That the README Describes the Plugin I Just Installed](../../docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)** — this README is anchored on current JTBD job IDs; drift between prose and shipped behaviour is detectable at retro time per ADR-051.

## Updating and Uninstalling

```bash
npx @windyroad/itil --update
npx @windyroad/itil --uninstall
```

## Licence

[MIT](../../LICENSE)
