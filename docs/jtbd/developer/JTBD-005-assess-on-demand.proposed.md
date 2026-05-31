---
status: proposed
job-id: assess-on-demand
persona: developer
date-created: 2026-04-16
human-oversight: confirmed
oversight-date: 2026-05-31
---

# JTBD-005: Invoke Governance Assessments On Demand

## Job Statement

When I want to know whether my work is safe to release, architecturally sound, or aligned with persona goals, I want to invoke a governance assessment directly, so I can course-correct before reaching a gate or starting a commit.

## Desired Outcomes

- A pre-flight risk score is available with one command, before I decide to commit or push
- Architecture compliance and JTBD alignment checks are available on demand, not just at hook trigger points
- On-demand assessments produce the same structured output as hook-triggered assessments — no special formatting or prompting required
- Running an on-demand assessment pre-satisfies the corresponding gate for the current session, so I don't get a duplicate check at the commit/push step
- Assessment skills are discoverable via `/` autocomplete — I don't need to know the subagent_type string

## Persona Constraints

- Wants speed without sacrificing quality
- Works alone or with a small team — no dedicated review process
- Must not need to leave the current task context to invoke an assessment

## Current Solutions

Invoke subagents manually via the Task tool with the exact subagent_type string and a self-contained prompt. Requires knowing the string and crafting the context — high friction.
