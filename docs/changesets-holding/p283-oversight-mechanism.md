---
"@windyroad/architect": minor
"@windyroad/itil": patch
---

Decision-oversight mechanism (P283 prong 2, ADR-066). The architect plugin now records human oversight on ADRs with a `human-oversight: confirmed` + `oversight-date` frontmatter marker (orthogonal to `status:`), detects unoversighted decisions with a token-cheap grep (`wr-architect-detect-unoversighted`), nudges at session start when decisions lack oversight, and drains the unconfirmed set via the new `/wr-architect:review-decisions` skill (confirm / amend / reject per ADR, in batches via AskUserQuestion). New ADRs are born oversighted — `create-adr` writes the marker on the Step 5 confirm. The session-start nudge self-suppresses inside AFK iterations; `@windyroad/itil` work-problems Step 5 now exports `WR_SUPPRESS_OVERSIGHT_NUDGE=1` so the nudge never fires into an absent-user subprocess (the paired sender for the hook's self-suppress receiver).
