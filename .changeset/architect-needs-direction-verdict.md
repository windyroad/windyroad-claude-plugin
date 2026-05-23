---
"@windyroad/architect": minor
---

Add a Needs-Direction verdict to the architect agent. When the architect detects a new decision with two or more viable options and no pinned direction, it now names the decision question and the candidate options instead of auto-picking one or asking in prose — and the main agent turns that into a structured AskUserQuestion before the decision is recorded. When direction is already pinned (a same-turn or same-session choice, an accepted ADR, RISK-POLICY.md, or a CLAUDE.md rule), the architect notes it and the agent acts without re-asking. The create-adr and capture-adr skills document the handoff, and a capture-adr skeleton now needs an AskUserQuestion confirm pass before it can be accepted. See ADR-064.
