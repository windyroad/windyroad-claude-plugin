---
name: wr-itil:check-upstream-responses
description: Poll upstream issues we've filed via `/wr-itil:report-upstream` and surface new comments, state changes, or label changes since last check. Reads `## Reported Upstream` back-link sections in local problem tickets, queries `gh issue view` (read-only), diffs against `docs/problems/.outbound-responses-cache.json`, and appends an audit-log entry to `docs/audits/outbound-responses-log.md`. Outbound symmetric counterpart to ADR-062's inbound discovery pipeline (P249 Phase 1).
allowed-tools: Read, Edit, Write, Bash, Glob, Grep
---

# Check Upstream Responses — Outbound Response-Check Skill

Poll the upstream issues we have filed via `/wr-itil:report-upstream` and surface new responses (comments, state changes, label changes) since the last check. This skill closes the outbound half of the feedback loop that ADR-062's inbound assessment pipeline opens — together they form the bidirectional cross-repo coordination surface JTBD-004 names.

This is **Phase 1** of P249. Phase 1 covers the **us-as-upstream-reporter** half (we polling our own filed-upstream reports). Phase 2 — the external-reporter-as-our-reporter half (plugin users polling responses to reports they filed against this repo) — is deferred to a separate iter.

## Scope

In scope:
- Scan `docs/problems/**/*.md` for `## Reported Upstream` back-link sections (the contract section written by `/wr-itil:report-upstream` Step 7 — see [ADR-024](../../../../docs/decisions/024-cross-project-problem-reporting-contract.proposed.md) Step 7).
- For each ticket with a back-link, extract the `- **URL**:` line and poll the upstream issue via `gh issue view <url> --json comments,state,labels,updatedAt`.
- Diff against `docs/problems/.outbound-responses-cache.json` (cache file mirroring the inbound `.upstream-cache.json` shape per ADR-031 § "Cache files live under docs/problems/").
- Surface five response classes: NEW (new comments), STATE (state change), LABEL (label change), NONE (no change), FAIL (gh poll error).
- Update the cache file with the latest seen state.
- Append a timestamped pass entry to `docs/audits/outbound-responses-log.md` (audit-log mirroring `docs/audits/inbound-discovery-log.md` per ADR-062's audit-log surface contract).

Out of scope:
- Posting comments back to the upstream issue. The skill is **read-only externally** — does not trip ADR-028's external-comms gate.
- Auto-transitioning local ticket lifecycle based on upstream state change (that is P080's bidirectional update axis, separate).
- Polling against the inbound-discovery channels (`docs/problems/.upstream-channels.json`). That is the inverse axis, owned by `/wr-itil:review-problems` Step 4.5 per ADR-062.
- Phase 2 external-reporter-as-our-reporter surface (deferred).

## Invocation

```
/wr-itil:check-upstream-responses
  [--problems-dir <dir>]   default: docs/problems
  [--cache-file <path>]    default: <problems-dir>/.outbound-responses-cache.json
  [--audit-log <path>]     default: docs/audits/outbound-responses-log.md
  [--ticket P<NNN>]        restrict polling to one ticket
  [--force-recheck]        ignore cache; treat all as new
```

Future iter will wire `/wr-itil:work-problems` Step 0c pre-flight to invoke this skill when the outbound cache is stale (sibling to Step 0b inbound cache check per ADR-062 Confirmation #5). Phase 1 ships manual-invocation only.

## AFK behaviour

This skill is **AFK-safe by construction**:

- Read-only `gh issue view` calls — does NOT fire ADR-028 external-comms gate.
- No `AskUserQuestion` calls — five flag-based knobs (`--problems-dir`, `--cache-file`, `--audit-log`, `--ticket`, `--force-recheck`) are the user-direction surface per CLAUDE.md `act on obvious, AskUserQuestion for ambiguous, NEVER prose-ask` (P085).
- Partial-failure exit code (2) lets AFK orchestrators distinguish "some upstream URLs were unreachable" from "everything broke" without halting the loop.

## Steps

### 1. Run the diagnose+act script

Invoke the helper:

```bash
wr-itil-check-upstream-responses
```

The `wr-itil-check-upstream-responses` command is a `$PATH`-resolved shim shipped in `packages/itil/bin/` that dispatches the canonical `packages/itil/scripts/check-upstream-responses.sh` body. Per [ADR-049](../../../../docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md) — never invoke the canonical script via repo-relative path; the path does not resolve in adopter trees.

The script:

1. Walks `<problems-dir>` (both flat layout `<NNN>-*.<state>.md` AND per-state subdir layout `<state>/<NNN>-*.md` per RFC-002 dual-tolerant migration).
2. For each ticket file, extracts the `## Reported Upstream` URL line. Tickets without that section are silently skipped.
3. For each URL, calls `gh issue view <url> --json comments,state,labels,updatedAt`.
4. Compares the response against the cached entry for that ticket and emits one of: NEW / STATE / LABEL / NONE / FAIL.
5. Updates the cache file and appends an audit-log entry.

Exit codes:

- `0` — success. Cache and audit-log have been updated. Per-ticket lines printed to stdout.
- `1` — error (problems-dir missing, malformed cache, malformed CLI args, jq missing).
- `2` — partial. Some upstream polls failed; the successful ones are still written to cache + audit-log.

### 2. Summarise the response classes inline

Read the stdout output and summarise the response classes in chat for the user. The audit-log is the durable surface — the agent's inline summary is the in-session affordance. Do NOT re-dump the full stdout; lead with the most-important classes:

- STATE changes (upstream state OPEN → CLOSED / REOPENED) — most actionable; usually a verification signal.
- NEW comments (delta count > 0) — second-most actionable; may carry triage labels, follow-up questions, or fix confirmation.
- LABEL changes — informational; signals maintainer triage activity.
- NONE — quiet; only mention the count, not each ticket.
- FAIL — call out per-ticket reasons so the user can investigate (URL changed, repo renamed, auth issue).

### 3. Commit per ADR-014

The cache file and audit-log file ride a single commit:

```bash
git add docs/problems/.outbound-responses-cache.json docs/audits/outbound-responses-log.md
git commit -m "chore(problems): check upstream responses — <N> polled, <M> new"
```

See [ADR-014](../../../../docs/decisions/014-governance-skills-commit-their-own-work.proposed.md) commit-message-convention table for the canonical row.

If the cumulative pipeline risk lands above appetite and `AskUserQuestion` is unavailable, apply the [ADR-013](../../../../docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md) Rule 6 non-interactive fail-safe: skip the commit and report the uncommitted state.

## When invoked

Three invocation surfaces:

1. **Direct user invocation** — `/wr-itil:check-upstream-responses` (or with flags). The default user-facing surface.
2. **AFK orchestrator pre-flight** (future iter) — `/wr-itil:work-problems` Step 0c will invoke this skill when the outbound cache is stale, mirroring Step 0b's inbound staleness check per ADR-062 Confirmation #5. This wiring is deferred to a future iter; Phase 1 ships manual only.
3. **Manual investigation during a problem-management session** — when a maintainer wants to see if any upstream reports moved before transitioning a `verifying` ticket back to `closed`. Foreground synchronous; the maintainer reads the inline summary and decides next steps.

## Confirmation

This skill's contract holds when:

1. The script `packages/itil/scripts/check-upstream-responses.sh` is read-only externally — only `gh issue view` (no `gh issue comment`, no `gh issue create`, no `gh api`).
2. The script extracts the URL from `## Reported Upstream` sections matching the format `- **URL**: <url>` per ADR-024 Step 7's back-link contract.
3. After a successful pass, the cache file exists, is valid JSON, and contains a `tickets.<P<NNN>>` entry for every polled ticket.
4. After a successful pass, the audit-log file exists and has a new `## YYYY-MM-DDTHH:MM:SSZ` heading appended.
5. The skill is AFK-safe: zero `AskUserQuestion` calls, zero external-comms gate triggers.
6. The exit code distinguishes success (0), error (1), and partial failure (2) so AFK orchestrators can branch correctly.

## ADR alignment

- **ADR-014** — governance skills commit their own work. Cache file + audit-log ride a single commit per pass. ADR-014's commit-message-convention table is amended in the same commit as this skill ships to add the canonical row.
- **ADR-024** — cross-project problem-reporting contract. The `## Reported Upstream` back-link section (Step 7) is the source of truth this skill reads. ADR-024's Confirmation section is amended in the same commit to record that the back-link section's URL field is now a load-bearing contract surface for two skills (one writes, one reads).
- **ADR-031** — problem-ticket directory layout. Cache file lives under `docs/problems/` per the same precedent that placed `.upstream-cache.json` and `.upstream-channels.json` there for the inbound axis.
- **ADR-032** — governance skill invocation patterns. Foreground synchronous; no subagent dispatch needed.
- **ADR-037** — skill testing strategy. Behavioural bats at `packages/itil/scripts/test/check-upstream-responses.bats` (script-level) covers the contract.
- **ADR-038** — progressive disclosure. Per-row stdout output ≤ 150 bytes; the agent expands per-ticket detail on demand.
- **ADR-049** — bin shim. Script invoked as `wr-itil-check-upstream-responses`, not via repo-relative `bash <path>`.
- **ADR-062** — inbound upstream-report discovery + assessment pipeline. This skill is the outbound symmetric counterpart; ADR-062 `## Related` is amended in the same commit to forward-point at this skill.

## Related

- `packages/itil/scripts/check-upstream-responses.sh` — the diagnose+act script body.
- `packages/itil/scripts/test/check-upstream-responses.bats` — behavioural bats covering the script contract.
- `packages/itil/skills/report-upstream/SKILL.md` — the writer of the `## Reported Upstream` section this skill reads.
- `packages/itil/skills/review-problems/SKILL.md` — the inbound axis sibling (Step 4.5 inbound-discovery pass per ADR-062).
- `docs/audits/inbound-discovery-log.md` — inbound audit-log; symmetric peer of `docs/audits/outbound-responses-log.md`.
- `docs/problems/.upstream-cache.json` — inbound cache; symmetric peer of `docs/problems/.outbound-responses-cache.json`.
- `docs/decisions/024-cross-project-problem-reporting-contract.proposed.md` — outbound contract; back-link section is the source of truth.
- `docs/decisions/062-inbound-upstream-report-discovery-assessment-pipeline.proposed.md` — inbound discovery; this skill is the outbound counterpart.
- **P249** (`docs/problems/open/249-no-process-for-reporters-to-check-for-responses-symmetric-to-inbound-discovery.md`) — driver ticket. Phase 1 (us-as-upstream-reporter) ships here; Phase 2 (external-reporter-as-our-reporter) deferred.
- **P080** (`docs/problems/open/080-no-bidirectional-update-of-upstream-reported-problems.md`) — inverse axis (we push local status BACK to upstream issues we ingested). Composes with this skill.
- **P229** — inbound discovery ack-comment shape gap (verdict-shaped acks). Inverse-shape sibling on the inbound axis.
- **JTBD-004** — Connect Agents Across Repos to Collaborate (primary anchor).
- **JTBD-006** — Progress the Backlog While I'm Away (AFK-safe).
- **JTBD-001** — Enforce Governance Without Slowing Down (eliminates manual upstream polling).
- **JTBD-201** — Restore Service Fast with an Audit Trail (audit-log replay).
- **JTBD-202** — Run Pre-Flight Governance Checks Before Release or Handover (state-change signals before retro / release).
