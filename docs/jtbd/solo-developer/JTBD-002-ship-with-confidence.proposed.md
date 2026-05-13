---
status: proposed
job-id: ship-with-confidence
persona: solo-developer
secondary-persona: tech-lead
date-created: 2026-04-14
---

# JTBD-002: Ship AI-Assisted Code with Confidence

## Job Statement

When I delegate coding to an AI agent, I want to know it followed TDD and passed architecture review, so I can trust the code is tested and structurally sound.

## Desired Outcomes

- Every commit has been through architecture review, risk scoring, and TDD enforcement
- The agent cannot bypass governance — hooks block edits until reviews pass
- Audit trail exists (markers, scores, review records) showing governance was followed

## Persona Constraints

- Wants speed without sacrificing quality
- No dedicated QA or architecture review process

## Current Solutions

Pair programming with the AI, manual review of every diff, restricting agent permissions
