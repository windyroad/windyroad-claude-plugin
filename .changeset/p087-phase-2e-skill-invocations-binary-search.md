---
"@windyroad/itil": patch
---

P087 Phase 2e — wr-itil-skill-invocations binary-search-to-first-in-window byte-seek

Add a binary-search byte-seek before the line iterator in `packages/itil/scripts/skill-invocations.sh`. Files at or above a 256 KB threshold bisect to the earliest byte offset whose line carries a `timestamp` at or after the cutoff, then linear-scan from that offset; files below threshold continue to scan linearly from byte 0 (bisect overhead is not worth it for small files). JSONL is append-only within a single session jsonl file — older lines appear earlier by author-timestamp monotonicity — so the bisect skips the historical pre-cutoff portion of long-lived session files without paying the read cost.

Warm-cache median against a 5164 jsonl / ~1.08 GB corpus: **5.34s → 4.04s** (1.30s reduction, 24%) and **7.12s → 4.04s** (3.08s reduction, 43%) from the Phase 2c baseline. The 5s ADR-058 §Reassessment Triggers threshold is **now silenced** — warm-cache wall-clock sits 0.96s / 19% under budget.

NDJSON output schema and record count unchanged (235 records on the live corpus, identical surface attribution and ordering). Privacy posture unchanged. ADR-013 Rule 6 exit-0-always preserved. Bisect uses a whitespace-tolerant byte-regex for timestamp probes; readline-boundary alignment guarantees byte-safety; loop termination guaranteed by `hi = mid` on the in-window branch. Append-only monotonic-timestamps within a single session jsonl is the documented input invariant — synthetic violation under-counts gracefully without crashing or emitting malformed NDJSON. Four new bats fixtures pin the byte-seek correctness boundary (straddle, all-in-window, small-file linear, non-monotonic graceful-degradation); 19 tests now green.

ADR-058 §Performance contract amended with the Decision Outcome — Phase 2e block; §Reassessment Triggers updated to record the threshold silencing.
