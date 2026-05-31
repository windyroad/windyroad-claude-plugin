---
status: proposed
job-id: ship-with-confidence
persona: developer
secondary-persona: tech-lead
date-created: 2026-04-14
human-oversight: confirmed
oversight-date: 2026-05-31
---

# JTBD-002: Ship AI-Assisted Code with Confidence

## Job Statement

When I delegate coding to an AI agent, I want to know it followed the full TDD cycle (red-green-refactor) and passed architecture review, so I can trust the code is BOTH well-tested AND well-factored — not just passing tests.

## Desired Outcomes

- Every commit has been through architecture review, risk scoring, and TDD enforcement
- The agent cannot bypass governance — hooks block edits until reviews pass
- The refactor step is enforced and not skipped at green — structural quality lands with the tests, so the code is well-factored and not just test-passing
- Audit trail exists (markers, scores, review records) showing governance was followed

## Persona Constraints

- Wants speed without sacrificing quality
- No dedicated QA or architecture review process

## Current Solutions

Pair programming with the AI, manual review of every diff, restricting agent permissions
