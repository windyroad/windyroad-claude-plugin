# Problem 235: Briefing Signal-vs-Noise pass backlog — 146 entries across 17 topic files never scored per ADR-026 citation

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 6 (Med) — Impact: 2 (Minor — silent-classification model means scores influence Critical Points promotion + delete-queue surfacing; without scores, the SessionStart hook can't curate the cheap-layer Critical Points roll-up) x Likelihood: 3 (Likely — each retro that omits the pass widens the gap; entries created without scores default to 0 and decay-only)
**Effort**: L (estimated 1-2 hours of focused agent time — 146 entries × ~30s per entry for citation lookup + classification + comment-block update)
**WSJF**: (6 x 1.0) / 4 = **1.5** (L effort divisor; deferred — re-rate at next /wr-itil:review-problems)

> Captured 2026-05-17 by `/wr-retrospective:run-retro` session 3 retro wrap as the SCHEDULED-FUTURE-SURFACE for the Signal-vs-Noise pass defer per P234 fictional-defer remediation. Sibling to [[P105]] (parent — Signal-vs-Noise design), [[P234]] (driver — fictional-defer class-of-behaviour), [[P145]] (recurring-defer pattern at Tier 3 rotation surface).

## Description

`/wr-retrospective:run-retro` Step 1.5 specifies a Signal-vs-Noise pass that scores every briefing entry with an ADR-026 citation per cycle: `+2 signal`, `-1 noise`, `-1 decay` (applied to all). Scores >=+3 promote to Critical Points; scores <=-3 enter the delete queue.

The corpus has accumulated to **146 entries across 17 topic files** (measured 2026-05-17). No retro has performed the per-entry pass since the briefing tree was split into per-topic files (P100 slice 1, 2026-04-22). Retros have either skipped Step 1.5 silently or deferred it with "next retro should run a full pass" notes — the **fictional-defer pattern P234 captures**.

Today's session 3 retro added another fictional defer: *"Deferred this retro per session-length constraint (16+ briefing entries... would require ~30 min of per-entry scoring). Next retro should run a full pass."* The estimate was wrong (146 entries not 16+; ~30s per entry = ~1-2 hours not 30 min). The defer was fictional (no scheduled next retro). User caught the pattern in the Tier 3 rotation defer; the SVN defer remains pending.

This ticket IS the scheduled future surface. By capturing as a WSJF-ranked problem ticket, the work has a real home in the backlog rather than relying on "next retro will get to it."

## Symptoms

- 146 briefing entries with `<!-- signal-score: 0 | last-classified: <date-of-creation> | first-written: <date-of-creation> -->` HTML-comment trailers, all at default 0 score, all overdue for re-classification.
- SessionStart hook Critical Points curation has no data to promote-from / demote-to — Critical Points section in `docs/briefing/README.md` is manually curated by the agent during Step 3 rather than data-driven.
- Delete queue mechanism (entries at score <=-3) has never fired — no entry has accumulated 3 cycles of -1 decay because no cycles have run.

## Workaround

User and agent rely on the existing manually-curated Critical Points section in `docs/briefing/README.md`. Function-of-Critical-Points works without per-entry scores; the SVN data layer is missing but not catastrophic.

## Impact Assessment

- **Who is affected**: every SessionStart hook firing (loses data-driven Critical Points curation); every retro author (loses ability to demote stale entries via delete queue).
- **Frequency**: every retro. Continuously degrades.
- **Severity**: Minor. Silent quality degradation rather than load-bearing breakage.

## Root Cause Analysis

### Investigation Tasks

- [ ] Perform initial baseline pass across all 146 entries — score each per ADR-026 (cite tool invocation / reasoning paraphrase / session position that exercised it).
- [ ] Per-cycle decay (-1 applied to all 146 entries) is mechanical — script-extractable. Worth a `wr-retrospective-apply-decay.sh` helper?
- [ ] Per-entry classification (signal / noise / decay-only) requires session-context judgment — agent-owned per ADR-013 Rule 5 silent classification.
- [ ] After baseline, future retros pay only the per-cycle decay + per-entry classification cost (cheaper).

## Fix Strategy

Three options:

**Option A — Single baseline pass + mechanical decay helper**. Perform the 146-entry baseline pass once (1-2 hours focused work). Ship `packages/retrospective/scripts/apply-signal-decay.sh` to mechanically subtract 1 from every entry's signal-score per cycle. Future retros only need the cycle's signal-classification on entries actually cited this session. Highest-leverage path.

**Option B — Incremental pass per retro (status quo, accelerated)**. Each retro scores N entries (e.g. 20 per retro), starting with the most-recently-cited ones. Baseline emerges after ~8 retros. Lower per-retro cost but slower convergence.

**Option C — Decommission Step 1.5 if SessionStart curation doesn't actually need it**. Investigate whether the SessionStart hook's Critical Points promotion is in fact data-driven OR manually curated. If it's manual, Step 1.5's purpose is unclear and may be deferrable indefinitely (which means it should be amended OUT of run-retro SKILL.md per ADR-040 / P145 dead-step removal).

**Preferred**: Option A first. The baseline pass IS the work; once done, incremental upkeep is cheap.

## Dependencies

- **Composes with**: [[P105]] (parent — Signal-vs-Noise pass design), [[P234]] (parent — fictional-defer class this ticket closes for the SVN surface).
- **Blocked by**: (none — 1-2 hours of focused agent work is the cost).

## Related

- [[P105]] — parent ticket; defines the Signal-vs-Noise scoring mechanism
- [[P234]] — fictional-defer class; this ticket IS the remediation of P234 for the SVN-pass surface (citing a scheduled future surface instead of "next retro")
- [[P145]] — recurring-defer anti-pattern at Tier 3 (sibling surface)

## Change Log

- **2026-05-17** — Captured by `/wr-retrospective:run-retro` session 3 retro wrap as P234 remediation. The retro's earlier "Next retro should run a full pass" entry was a fictional defer; this ticket gives the work a real WSJF-ranked home. Captured via direct write per Step 4b Stage 1 mechanical ticketing + ADR-044 framework-resolution boundary.

## Progress — 2026-05-25 signal-vs-noise decay pass

The ~146 never-decay-scored entries were scored in the 2026-05-25 briefing-curation pass (see P195 Progress). All surviving entries across the topic tree now carry `last-classified: 2026-05-25`; stale entries (CLOSED-ticket issues, superseded mechanisms) removed or collapsed against the closed/verifying ticket-state index. Recurring fix unchanged: the per-entry decay scoring must run each retro (Step 1.5), not accumulate.
