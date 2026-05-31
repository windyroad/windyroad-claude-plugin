---
status: proposed
job-id: connect-agents
persona: developer
date-created: 2026-04-14
human-oversight: confirmed
oversight-date: 2026-05-31
---

# JTBD-004: Connect Agents Across Repos to Collaborate

## Job Statement

When I have multiple AI sessions working on related repos, I want them to communicate via a shared channel, so they can hand off findings, ask questions, and coordinate work without me switching terminals.

## Desired Outcomes

- Messages arrive with zero idle token cost (no polling)
- Sessions can direct messages to specific agents via @session-name
- Human participants can weigh in on the same channel

## Persona Constraints

- May be working across multiple repos simultaneously

## Current Solutions

Copy-paste between terminals, manually restarting sessions with new instructions
