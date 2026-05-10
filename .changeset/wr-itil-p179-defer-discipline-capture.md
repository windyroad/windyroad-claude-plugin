---
"@windyroad/itil": patch
---

P179 capture — agent defers requested work into untracked phases (phases OK, untracked phases not OK)

Captures the class-of-behaviour observed across the P170 RFC framework
session 2026-05-06 to 2026-05-10: agent silently splits described
solutions into "ship now" vs "defer to Phase N" without explicit user
authorisation or sibling-ticket tracking. Deferrals end up in ADR
prose / iter notes only — invisible to WSJF rankings.

Sibling-of-P175 + sibling-of-P178 root-cause class (agent inferring
framework-resolved boundaries from non-framework signals). P175 was
loop-control; P178 was state-machine; P179 is scope-control.

User direction 2026-05-10:
  "I don't mind phases, but I do mind if those phases never happen"

Captured under P078 discipline. Riding the same held-window atomicity
contract as the rest of the P170 RFC framework chain per ADR-060
§ Confirmation criterion 6.
