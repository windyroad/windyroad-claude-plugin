---
status: proposed
job-id: report-problem-without-pre-classifying
persona: plugin-user
date-created: 2026-04-20
---

# JTBD-301: Report a Problem Without Pre-Classifying It

## Job Statement

When I hit a problem with a windyroad plugin I installed, I want to describe what I observed in one place without deciding in advance whether it's a bug, a feature gap, or a documentation issue, so I can submit a useful report and get back to my own work.

## Desired Outcomes

- A single **Report a problem** intake template covers every class of inbound report — defects, missing capabilities, documentation gaps, configuration friction — so the reporter describes what they observed and triage decides the category.
- Required fields mirror the problem-ticket shape (Description, Symptoms, Workaround, Affected plugin, Frequency, Environment, Evidence) so signals collected at intake map 1:1 into the maintainers' `/wr-itil:manage-problem` workflow with no re-shaping.
- Security vulnerabilities have a clearly-declared private disclosure channel (GitHub Security Advisories) named in the intake config and in `SECURITY.md`; the public-issue path refuses silently-risky reports.
- Usage questions route to GitHub Discussions, not issues, so the issue tracker stays a reliable record of problems.
- Intake files (`problem-report.yml`, `config.yml`, `SUPPORT.md`, `CONTRIBUTING.md`, `SECURITY.md`) exist in every `@windyroad/*` repo AND in every downstream project that installs the suite — the scaffolding is provided, not hand-authored.
- Submitted reports receive a predictable acknowledgement: labelled (`problem`, `needs-triage`), routed into the maintainers' problem-management queue, and eventually responded to with a verdict (fix released / parked / duplicate / won't-fix).
- When a report is likely a duplicate of an existing upstream issue, the reporter is told before they invest in re-describing it — or the filing tool dedups automatically.
- **Maintainer-side complement** (added 2026-05-13 per ADR-060 Phase 4 amendment, F7 Option (b)): when a report lands, maintainer triage can assign persona + JTBD using the report's symptom signals without round-tripping back to the reporter. The reporter-side "no pre-classification" contract is symmetric to the maintainer-side "no re-asking" obligation — the symptom signals captured at intake must be rich enough for `/wr-itil:manage-problem` ingestion to derive type, persona, and JTBD trace deterministically. Preserves the firewall (plugin-user never prompted) by making the maintainer derivation a first-class job.

## Persona Constraints

- Low context on repo internals; intake must make sense without reading ADRs or source.
- High context on their own failure mode; intake must capture that context faithfully without forcing cognitive re-shaping.
- Reporting is incidental; intake must work in under 2 minutes or the report will be abandoned.
- May be filing via an AI agent rather than directly; intake shape must work equally well for agent-authored drafts as for hand-typed ones.

## Current Solutions

- **Until P066 landed**: pick "Bug report" or "Feature request", hope the classification is correct, rely on maintainer re-labelling. Mis-classified reports got re-bucketed during triage with no feedback to the reporter.
- **After P066**: single "Report a problem" template with fields mirroring the problem-ticket shape. Labels `problem` + `needs-triage`.
- **For scaffolding downstream projects**: no skill today. P065 (pending) proposes `/wr-itil:scaffold-intake` to seed `.github/ISSUE_TEMPLATE/`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md` in downstream repos.
- **For upstream reporting**: `/wr-itil:report-upstream` (shipped in `@windyroad/itil@0.8.0`, ADR-024) handles the maintainer-side outbound flow; P063 wires the trigger surface; P070 adds dedup.

## Related problem tickets

- **P066** — intake templates problem-first (Verification Pending, `ed36f69`). First ticket fully aligned to this job.
- **P055** — OSS intake scaffolding (Closed). Shipped the initial `.github/ISSUE_TEMPLATE/` + SECURITY/SUPPORT/CONTRIBUTING set.
- **P065** — `/wr-itil:scaffold-intake` skill for downstream projects (Open, WSJF 3.0 after re-rate). Extends this job's "intake exists in every repo" outcome from the Windy Road monorepo to every adopter.
- **P067** — `/wr-itil:report-upstream` classifier problem-first (Open, WSJF 4.5). Applies the same problem-first discipline to the upstream-classifier heuristic.
- **P070** — report-upstream dedup (Open, WSJF 6.0). Directly addresses the "was this a duplicate?" outcome above.
- **P072** — this job's originating ticket; filled the persona gap surfaced during P066's JTBD review.
