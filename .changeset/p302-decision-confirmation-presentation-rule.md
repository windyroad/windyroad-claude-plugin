---
"@windyroad/architect": patch
---

Presentation rule for decision-confirmation prompts (P302). The `/wr-architect:review-decisions` Step 3 now directs the `AskUserQuestion` `question` field to lead with the one-line Decision Outcome ("This ADR decides: X"). Sibling-ADR relationships, supersession lineage, and Considered-Options recording-shape meta belong in a trailing clause or are omitted. Worked bad/good examples grounded in two 2026-05-25 drain re-asks (ADR-045, ADR-020) where the user couldn't tell what they were confirming. Applies ADR-074 *name the substance, not the grain* to the confirm-prompt surface; extends ADR-026 grounding from artifact body to the `AskUserQuestion` `question` text.

The mirrored rule in `/wr-jtbd:confirm-jobs-and-personas` (held in `docs/changesets-holding/p288-jtbd-persona-oversight.md`) ships with that drain skill's graduation; the agent-interaction briefing note generalises the rule to any decision-presentation surface (`docs/briefing/agent-interaction-patterns.md`).
