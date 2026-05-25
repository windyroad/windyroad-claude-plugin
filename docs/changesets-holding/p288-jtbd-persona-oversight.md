---
"@windyroad/jtbd": minor
---

JTBD + persona decision-oversight mechanism (P288, ADR-068 — sibling of ADR-066). The jtbd plugin now records human oversight on jobs and personas with a `human-oversight: confirmed` + `oversight-date` frontmatter marker (orthogonal to `status:`), detects unoversighted jobs/personas with a token-cheap grep (`wr-jtbd-detect-unoversighted`), nudges at session start when jobs/personas lack oversight (self-suppressing inside AFK iterations via the shared `WR_SUPPRESS_OVERSIGHT_NUDGE` guard), and drains the unconfirmed set via the new `/wr-jtbd:confirm-jobs-and-personas` skill (confirm/amend/reject per artifact via AskUserQuestion). Jobs/personas created through `update-guide` are born oversighted. This is the read-write oversight drain — distinct from the read-only `/wr-jtbd:review-jobs` alignment reviewer.
