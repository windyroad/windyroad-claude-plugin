---
status: "proposed"
date: 2026-05-25
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: []
reassessment-date: 2026-08-25
---

# ADR-067: Cost-based WSJF effort — capture time + cost actuals, tally per ticket, retro-driven RMS calibration (tally-first)

## Context and Problem Statement

WSJF effort is t-shirt sizing (S/M/L/XL → divisor **1/2/4/8** per `manage-problem/SKILL.md`). It is subjective and has no calibration loop: an estimate is set at capture, carried through transitions, and never compared against what the work actually cost. P047 (closed) added the XL bucket, widened the L divisor, and added lifecycle re-rating — but kept the buckets ungrounded.

Per-iteration actuals (`total_cost_usd`, `duration_ms`, token usage) are **already captured** in `.afk-run-state/iter*.json` (work-problems Step 5 cost-metadata contract) but are **never attributed back to the source ticket**, so estimates never improve. P248: *"keep a tally of the time or token spent … the retrospective can then use this data to refine the estimation process so that over time the RMS of the estimation error is reduced … I'd love it to do both time and tokens."*

**Empirical grounding (2026-05-25 analysis of the existing `.afk-run-state/` data).** 120 iter JSON files carrying `total_cost_usd` map (via the `pNNN` filename token) to **75 distinct tickets** that also carry a t-shirt Effort size. Median actual cost per bucket: **S $8.04 (n=22), M $9.87 (n=43), L $15.83 (n=5), XL $13.59 (n=5)** — overall spread $2.34–$124.53 (50×). Two concrete mis-calibrations: (a) **S ≈ M in actuals** despite the divisor halving M's WSJF weight; (b) **XL median < L median** — the buckets are *mis-ordered* against actual cost. Within-bucket spread is enormous (M: 25×, L: 12×) — the bucket predicts almost nothing. Caveats: t-shirt sizes were sometimes re-rated post-hoc (not clean capture-time predictions), cost includes per-iter governance/retro overhead, and L/XL n is only 5. This is strong directional evidence that the current buckets are poorly calibrated and that real actuals exist to bootstrap a better model.

## Decision Drivers

- Estimation accuracy compounds across the whole backlog — every WSJF rank, every `/wr-itil:work-problems` selection, every `/wr-itil:review-problems` re-rate.
- A calibration loop needs **actual-vs-estimate data before** the formula can change — you cannot calibrate a divisor with no data. This mandates tally-first sequencing.
- Both **time and cost** are valuable signals to the user.
- **ADR-026 grounding** — no ungrounded quantitative estimates; actuals must come from a sound measurement source.
- Keep tooling stable — `manage-problem`, `work-problems` Step 3 selection, `review-problems`, and the README WSJF render all consume the divisor; changing the formula now would churn all of them with no calibration data to justify the new shape.

## Considered Options

- **Option A — status quo (t-shirt only).** Rejected: P248's whole point is that t-shirt sizing has no calibration loop; doing nothing leaves the compounding estimation noise.
- **Option B — immediate formula change (replace the divisor with a cost-derived value now).** Rejected: with zero actual-vs-estimate data, any cost-derived divisor is an ungrounded guess (ADR-026 violation), and it churns every divisor consumer before there is evidence the new shape is better.
- **Option C — tally-first (CHOSEN).** Capture estimates + actuals now, keep the 1/2/4/8 divisor, accumulate data, compute RMS in the retro, and defer the formula change to a follow-up ADR once data exists. User-pinned 2026-05-25 via `AskUserQuestion`.

## Decision Outcome

Chosen: **Option C (tally-first)**.

1. **Effort estimate fields.** Open problems estimate **RCA effort**; Known Errors estimate **RFC-implementation effort**. Both axes captured: `**Estimated time**:` + `**Estimated tokens**:`, recorded as body-field bullets matching the existing `**Status**`/`**Priority**`/`**Effort**` convention (problem tickets use body bullets, not YAML — ADR-060 grandfathered inconsistency). Fields are **derived silently** (category-4 silent-framework per P185 / inverse-P078) — NO `AskUserQuestion` at capture time; default from the t-shirt bucket's typical cost where no better signal exists (JTBD-301 plugin-user friction guard + JTBD-006 AFK trust).

2. **Per-ticket Effort Tally.** A `## Effort Tally` section, appended per relevant iter, fed from `.afk-run-state/iter*.json`. Separate tallies for the RCA phase (Open) vs the RFC-implementation phase (Known Error). **Authority hierarchy (P089 Gap 2) — load-bearing:**
   - **`actual_cost_usd`** (from `.total_cost_usd`) is the **authoritative** actual — session-cumulative by CLI contract. Dollar cost is the reliable proxy for token spend.
   - **`actual_time`** (from `.duration_ms`) is reliable wall-clock.
   - Raw **token counts** (from `.usage.*`) are recorded but flagged **best-effort** — they undercount dramatically when a subprocess exits on a background-task completion-ack turn (observed AFK-iter-7 iter 5, 2026-04-21: ~137K tokens for a 1071s/60-tool iter). The RMS calibration (item 4) treats the token axis as best-effort and weights time + cost as the authoritative axes.

3. **Tally-first migration.** KEEP the current **1/2/4/8** divisor in the WSJF formula. Existing tickets keep their t-shirt size. New tickets ADD the estimate fields alongside. **No WSJF formula change in this ADR.**

4. **Backfill from historical AFK data (user direction 2026-05-25).** Seed the per-ticket `## Effort Tally` from the existing `.afk-run-state/iter*.json` actuals (the 75 tickets / 120 iters above), attributed via the `pNNN` filename token. The calibration loop therefore starts with **real data from day one**, not an empty accumulator. Backfilled entries are flagged `source: afk-backfill` (vs `source: live-iter` for go-forward) so the retro can weight clean go-forward capture-time pairs over post-hoc-re-rated historical ones, and so the P089 Gap 2 token caveat is visible on the backfilled rows.

5. **Retro-driven calibration.** `/wr-retrospective:run-retro` computes the **RMS of estimation error** (estimate vs actual) over the most recent **N = 10** closed/transitioned tickets per axis (time, cost authoritative; tokens best-effort), and surfaces the trend. Over sessions this drives estimate accuracy up. N is a tunable with a sane default (revisit at reassessment).

6. **Formula change deferred to a follow-up ADR — but urgent, not someday.** The divisor staying 1/2/4/8 is explicitly transitional. The empirical grounding above ALREADY shows the buckets are mis-ordered (XL < L) and S ≈ M, so the follow-up divisor-change ADR is a near-term priority once the backfill + a short window of go-forward clean pairs corroborate the historical signal — not an indefinite "someday." Tracked as a `Blocks:` line on P248. This ADR still does not change the divisor (we want the corroborating go-forward pairs first, per ADR-026 grounding — the historical data alone has post-hoc-re-rate noise).

### Relationship to existing decisions

- **Extends ADR-026.** ADR-026 established an `Actual Effort:` field captured via `AskUserQuestion` at the `.verifying.md → .closed.md` transition. The auto-fed `## Effort Tally` IS the automated grounded actual ADR-026 envisioned. **The auto-tally is preferred where `.afk-run-state/iter*.json` data exists; the manual `Actual Effort:` capture is retained as the fallback for non-AFK / interactive work that produced no iter JSON.** Not a supersession — an automation of ADR-026's measurement intent.
- **Builds on P047.** Keeps P047's XL bucket, widened-L divisor (1/2/4/8), and lifecycle re-rate discipline. ADR-067 is the calibration-data layer P047's closure anticipated ("actuals-grounded bucket selection on top").

## Consequences

**Good:** WSJF ranking quality improves over time (JTBD-006); estimate→actual delta becomes auditable where today it is invisible (JTBD-202); zero new AFK friction (the tally reads data the loop already emits; RMS runs in the retro, not mid-loop).

**Neutral:** two new estimate body-fields per ticket (derived silently, so no capture friction); the `## Effort Tally` section grows per iter.

**Bad / costs:** the token axis carries the P089 Gap 2 best-effort caveat (mitigated by anchoring calibration on time + cost); a future follow-up ADR + migration is needed to actually change the divisor formula (deliberately deferred).

## Confirmation

1. A new ticket carries `**Estimated time**:` + `**Estimated tokens**:` fields, derived (no `AskUserQuestion` fired) — behavioural bats.
2. After an iter works a ticket, its `## Effort Tally` section gains an entry sourced from `.afk-run-state/iter*.json` with `actual_cost_usd` authoritative + token counts flagged best-effort — behavioural bats.
2a. The backfill seeds `## Effort Tally` for tickets with historical `.afk-run-state/iter*.json` data, flagged `source: afk-backfill` — behavioural bats over a fixture iter-JSON tree.
3. The retro computes an RMS-of-estimation-error figure over the last N closed/transitioned tickets per axis and surfaces it — behavioural bats.
4. The WSJF divisor remains 1/2/4/8 (no formula change) — assertion against `manage-problem` SKILL.

## Reassessment Criteria

- **Primary trigger:** enough actual-vs-estimate data has accumulated (heuristic: ≥ ~15 closed/transitioned tickets with both estimate and tally) to choose a cost-derived divisor with grounded confidence → record the follow-up formula-change ADR.
- Revisit the RMS window N (=10) if the closed-ticket throughput makes it too noisy or too laggy.
- Reassess at 2026-08-25.

## Related

- **P248** (`docs/problems/open/248-...md`) — driver. Carries a stale "1/2/3/5" divisor reference (actual is 1/2/4/8) to correct when next touched; gains a `Blocks: future divisor-formula ADR` line.
- **P047** (`docs/problems/closed/047-...md`) — prior attempt; ADR-067 builds on its buckets + re-rate.
- **ADR-026** — measurement-surface parent; ADR-067 automates its `Actual Effort:` intent.
- **P089 Gap 2** — the `total_cost_usd`-authoritative / `usage.*`-best-effort asymmetry the tally honours.
- `packages/itil/skills/work-problems/SKILL.md` Step 5 — the cost-metadata source.
- `packages/itil/skills/manage-problem/SKILL.md` — the 1/2/4/8 divisor + WSJF formula (unchanged by this ADR).
- `/wr-retrospective:run-retro` — the RMS-calibration consumer.
