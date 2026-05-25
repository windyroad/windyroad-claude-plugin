# @windyroad/itil

**ITIL-aligned IT service management for Claude Code.** Track recurring incidents, perform root cause analysis, and prioritise fixes using WSJF -- all inside your coding sessions. *Maturity: Experimental (suite-bootstrap window; 327 invocations / 30d).*

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

See [ADR-011](../../docs/decisions/011-manage-incident-skill.proposed.md) for the incident-vs-problem split.

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

| Skill | Purpose | Maturity |
| ------- | --------- | --- |
| `/wr-itil:manage-problem` | Create, update, and close problem tickets through the Open → Known Error → Verifying → Closed lifecycle | Alpha |
| `/wr-itil:capture-problem` | Foreground-lightweight aside-invocation variant of `manage-problem` (per ADR-032 background-capture pattern + P078 capture-on-correction) — drafts a ticket scaffold without losing the operational thread when a problem signal surfaces mid-conversation | Experimental |
| `/wr-itil:work-problem` | Pick the highest-WSJF actionable ticket and work it to completion | Experimental |
| `/wr-itil:work-problems` | AFK orchestrator — batch-work the problem backlog by WSJF priority while the user is away | Experimental |
| `/wr-itil:list-problems` | Read-only display of the open and known-error backlog sorted by WSJF | Experimental |
| `/wr-itil:transition-problem` / `/wr-itil:transition-problems` | Advance one or many tickets through the lifecycle | Experimental |
| `/wr-itil:review-problems` | Re-rate every open and known-error ticket and refresh the WSJF ranking | Experimental |
| `/wr-itil:reconcile-readme` | Detect and correct drift between `docs/problems/README.md` and on-disk ticket inventory | Experimental |
| `/wr-itil:report-upstream` | Report a local problem as a structured issue against an upstream repository (ADR-024) | Experimental |
| `/wr-itil:check-upstream-responses` | Poll upstream issues we filed via `/wr-itil:report-upstream` and surface new comments / state changes / label changes since last check (P249 Phase 1; outbound symmetric counterpart to ADR-062 inbound discovery) | Experimental |
| `/wr-itil:capture-rfc` | Lightweight RFC-capture skill — mandatory problem-trace per ADR-060 I1 invariant; opens a coordinated multi-commit change traceable to ≥ 1 driving problem (Phase 1 of the Problem-RFC-Story framework, P170 / ADR-060) | Experimental |
| `/wr-itil:manage-rfc` | Heavyweight RFC intake + lifecycle management — proposed → accepted → in-progress → verifying → closed; sibling to `manage-problem` at the RFC tier (ADR-060) | Experimental |
| `/wr-itil:capture-story` | Lightweight story-capture skill — mandatory problem-trace AND JTBD-trace per ADR-060 I6 + I9 invariants; optional `--rfc` / `--story-map` flags (I7 + I8 enforce at `accepted` transition); drafts an INVEST-shaped sub-workstream entity under a parent RFC (Phase 2 of the Problem-RFC-Story framework, P170 / ADR-060) | Experimental |
| `/wr-itil:list-stories` | Read-only display of stories grouped by lifecycle state, with optional `--rfc RFC-<NNN>` filter rendering the RFC's ordered story list per ADR-060 line 259 (Phase 2 / P170) | Experimental |
| `/wr-itil:reconcile-stories` | Detect and correct drift between `docs/stories/README.md` and on-disk story inventory + reverse-trace `## Stories` sections on driving problems / RFCs / JTBDs (Phase 2 / P170) | Experimental |
| `/wr-itil:manage-story` | Heavyweight story lifecycle management — draft → accepted → in-progress → done → archived; I7+I8+I10 hard-block at accepted transition; INVEST 4-axis check; auto-transitions on `Refs: STORY-NNN` commit trailer + linked RFC closure (Phase 2 / P170) | Experimental |
| `/wr-itil:capture-story-map` | Lightweight story-map-capture skill — mandatory problem-trace AND JTBD-trace per ADR-060 I3 + I4 invariants; HTML skeleton at `docs/story-maps/draft/STORY-MAP-NNN-<slug>.html` per ADR-060 § Phase 2 encoding amendment 2026-05-12 (Phase 2 / P170) | Experimental |
| `/wr-itil:manage-story-map` | Heavyweight story-map lifecycle management — draft → accepted → in-progress → completed → archived; backbone/ribs/slices authoring guidance; reverse-trace `## Story Maps` refresh on driving problems + JTBDs (Phase 2 / P170) | Experimental |
| `/wr-itil:reconcile-story-maps` | Detect and correct drift between `docs/story-maps/README.md` and on-disk story-map HTML inventory (Phase 2 / P170) | Experimental |
| `/wr-itil:list-story-maps` | Read-only display of story-maps grouped by lifecycle state; no WSJF (I5 invariant — maps are planning artefacts, not work items) (Phase 2 / P170) | Experimental |
| `/wr-itil:manage-incident` | Declare, triage, mitigate, and close an incident with evidence-first discipline | Experimental |
| `/wr-itil:list-incidents` | Read-only display of active incidents by severity | Experimental |
| `/wr-itil:mitigate-incident` / `/wr-itil:restore-incident` / `/wr-itil:close-incident` / `/wr-itil:link-incident` | Incident lifecycle transitions (ADR-011) | Experimental |
| `/wr-itil:scaffold-intake` | Scaffold OSS intake surfaces (`.github/ISSUE_TEMPLATE/`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`) for downstream adopters (ADR-036) | Experimental |

## Updating and Uninstalling

```bash
npx @windyroad/itil --update
npx @windyroad/itil --uninstall
```

## Licence

[MIT](../../LICENSE)
