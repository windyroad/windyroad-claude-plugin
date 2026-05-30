---
"@windyroad/architect": minor
"@windyroad/jtbd": minor
---

ADR-066 marker vocabulary gains a third value: `human-oversight: rejected-pending-supersede` + companion `supersede-ticket: P<NNN>` scalar. The detector (`detect-unoversighted.sh`) and build-upon predicate (`is-decision-unconfirmed.sh`) treat the marker+ticket pair as ratified-equivalent — the `/wr-architect:review-decisions` drain stops re-asking ADRs the user explicitly rejected with a tracked supersede. The same grammar mirrors onto the JTBD sibling (`detect-unoversighted.sh` + `is-job-or-persona-unconfirmed.sh` + `/wr-jtbd:confirm-jobs-and-personas`). Compendium renderer surfaces the disposition: `**Oversight:** rejected-pending-supersede (P<NNN>)`. Closes P316.
