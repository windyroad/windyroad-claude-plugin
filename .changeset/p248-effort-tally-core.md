---
"@windyroad/itil": minor
---

Per-ticket effort tally from AFK iteration cost metadata (P248, ADR-067). New `wr-itil-effort-tally` shim + `effort-tally.sh` attribute `.afk-run-state/iter*.json` actuals back to their source ticket (via the `pNNN` filename token) and emit a per-ticket tally line honouring the P089 Gap 2 authority hierarchy (`total_cost_usd` authoritative, `duration_ms` reliable, raw token counts best-effort). This is the reusable, adopter-portable core (reads each project's own `.afk-run-state`) shared by the backfill and the go-forward per-iter append.
