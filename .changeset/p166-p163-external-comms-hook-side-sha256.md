---
"@windyroad/risk-scorer": patch
"@windyroad/voice-tone": patch
---

Hook-side sha256 derivation for the external-comms gate eliminates the double-invocation cost class (P166) and the placeholder-key class (P163).

The PostToolUse:Agent mark hook now derives the marker key from the agent's `tool_input.prompt` (`SURFACE: <name>` line + `<draft>...</draft>` block) and computes `sha256(DRAFT + '\n' + SURFACE)` itself — single fire per gate cycle. Agents no longer emit or compute the key. Backward-compat fallback to the agent-emitted `EXTERNAL_COMMS_<EVAL>_KEY` line preserved for one release cycle.

Closes P166, closes P163. ADR-028 amended 2026-05-16.
