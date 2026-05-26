---
"@windyroad/architect": patch
"@windyroad/itil": patch
"@windyroad/retrospective": patch
---

Enforce confirm-substance-before-build (ADR-074, RFC-008, closes the P315 mechanical layer).

A genuine ≥2-option decision the framework cannot resolve must have its **substance** human-confirmed before any dependent work is built on it — recording a born-`proposed` decision is not a licence to build on its unconfirmed substance.

- **architect**: the Needs-Direction verdict now requires naming the *substantive* choice, not a meta/grain framing question. New `wr-architect-is-decision-unconfirmed` predicate (PATH shim per ADR-049) + the `is-decision-unconfirmed.sh` script answer "is this referenced decision unconfirmed?" for the build-upon guard.
- **itil**: `manage-problem` adds a substance-confirm-before-build guard at the propose-fix surface (ADR-060 I13) — surfaces the unconfirmed decision's substance via `AskUserQuestion` before building. `work-problems` queues it to `outstanding_questions` (category `direction`) under AFK rather than blocking or guessing.
- **retrospective**: substance-confirm-before-build asks are classified as ADR-044 cat-1 `direction` and excluded from the lazy-AskUserQuestion regression metric (run-retro Step 2d + `check-ask-hygiene.sh`).
