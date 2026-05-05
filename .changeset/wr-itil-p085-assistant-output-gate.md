---
"@windyroad/itil": minor
---

P085: assistant-output gate — act on obvious, AskUserQuestion for ambiguous, never prose-ask

The `@windyroad/itil` plugin now registers two new hooks that together enforce ADR-013 Rule 1 ("use AskUserQuestion for governance decisions") plus the `feedback_act_on_obvious_decisions.md` memory guidance ("obvious default → act; genuine ambiguity → AskUserQuestion; never prose-ask"):

- **UserPromptSubmit** (`itil-assistant-output-gate.sh`) — when the incoming user prompt contains a direction-pinning signal (`yes`, `go`, `proceed`, `act`, `just do it`, ...), injects a MANDATORY reminder instructing the assistant to act on the obvious next step or use the `AskUserQuestion` tool for genuine ambiguity — never prose-ask. Once-per-session full block, terse reminder thereafter (ADR-038 progressive disclosure + ≤150-byte budget per P095 pattern).
- **Stop** (`itil-assistant-output-review.sh`) — reads the last assistant turn from `transcript_path` and scans for canonical prose-ask phrasings (`Want me to`, `Should I`, `Would you like me to`, `Shall we`, `Option A or Option B`, `(a) / (b) / (c)?`, `Do you want to`, `Let me know if`). When a prose-ask is detected — and the turn did NOT use the `AskUserQuestion` tool — emits a `stopReason` nudge so the next assistant turn self-corrects. Stop hooks cannot rewrite the emitted turn; the nudge biases the subsequent turn.

Detector registry (`packages/itil/hooks/lib/detectors.sh`) is the single source of truth for both hooks. Composition: P078 (correction → ticket) and future itil assistant-output validators extend this registry.

Root `CLAUDE.md` updated with a 2–4 line pointer promoting the memory rule to a repo-level MANDATORY; full phrasing list stays in the detector library per ADR-038 progressive disclosure.

`scripts/sync-session-marker.sh` adds `itil` to the CONSUMERS list so the canonical `packages/shared/hooks/lib/session-marker.sh` is mirrored per ADR-017.

22 new behavioural bats tests under `packages/itil/hooks/test/` (per `feedback_behavioural_tests.md` / P081 — behavioural, not structural grep-for-string).

Closes P085 → Verification Pending.
