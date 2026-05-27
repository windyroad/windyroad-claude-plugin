---
"@windyroad/jtbd": patch
---

JTBD review flags changes built on an unratified persona or job (ADR-068 surface 3, RFC-011, P323).

The jtbd agent now emits a new [Unratified Dependency] verdict: when a change or plan explicitly cites, implements, or serves a persona or job that lacks `human-oversight: confirmed` (unratified, and not superseded), it reports ISSUES FOUND with the action "ratify it via /wr-jtbd:confirm-jobs-and-personas before this lands." This is the JTBD twin of the architect side's surface-3 control (RFC-010 / P318).

- Keyed on the human-oversight marker, NOT on `status:` — building on a ratified job is fine even when its status is still `proposed` (status and oversight are orthogonal axes).
- The agent runs the new `wr-jtbd-is-job-or-persona-unconfirmed` predicate by exit code (the jtbd agent has Bash) — the single-artifact sibling of the architect's `is-decision-unconfirmed`, resolving `persona: <name>` and `JTBD-NNN` refs over the ADR-008 layout and keeping its marker grammar in sync with `detect-unoversighted`.
- Bounded to explicit cite/implement (not ambient alignment); the inverse-P078 over-fire guard. Unlike the architect surface, the JTBD unratified set is currently large (P288 drain in progress), so this fires more often until that drain completes — the intended forcing function.
- Closes the JTBD-surface half of the build-on-unratified gap (the ADR-surface half is P318/RFC-010); completes the JTBD oversight surface-set (surfaces 1 & 2 shipped via ADR-068/P288).
