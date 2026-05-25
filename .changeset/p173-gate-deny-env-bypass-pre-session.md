---
"@windyroad/itil": patch
"@windyroad/retrospective": patch
"@windyroad/risk-scorer": patch
"@windyroad/voice-tone": patch
---

Gate deny messages no longer advertise the `BYPASS_*_GATE=1` env bypass as an in-flight escape. The bypass only takes effect when set in Claude Code's process env before the session starts, so a mid-session Bash export never reaches the hook process. The deny now leads with the accurate in-flight recovery and states the env bypass is pre-session only:

- changeset-discipline gate: `Recovery: bun run changeset. Env bypass is pre-session only.`
- README-inventory currency gate: `Recovery: name the skill in the README. Env bypass is pre-session only.`
- external-comms gate: `Override only ... (pre-session env): BYPASS_RISK_GATE=1.` (already names delegation as the in-flight recovery).

Closes the misleading-deny friction class (P173).
