---
"@windyroad/itil": patch
---

P178 capture — agent skips ITIL state-machine gates on architecture-driven problems

Captures the class-of-behaviour observed during P170 RFC framework
implementation: agent treats architect-PASS verdict on driving ADR as
substitute for empirical RCA, skips Open → Known Error transition,
proceeds with implementation against an `*.open.md` ticket.

Sibling-of-P175 root-cause class (agent inferring framework-resolved
decisions from non-framework signals; P175 was loop-control, P178 is
state-machine).

Captured under P078 discipline after user mid-session correction.
Implementation work on P170 (8 iters / 26 commits) preceded any Known
Error transition. P170 itself is being retroactively transitioned in a
companion commit using session evidence.

Riding the same held-window atomicity contract as the rest of the
P170 RFC framework chain per ADR-060 § Confirmation criterion 6.
