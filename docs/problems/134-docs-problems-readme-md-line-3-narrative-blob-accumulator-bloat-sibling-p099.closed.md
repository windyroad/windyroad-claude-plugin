# Problem 134: `docs/problems/README.md` line 3 narrative-blob accumulator bloat — sibling to P099 (briefing tier 3) on a different surface

**Status**: Closed (verified 2026-05-05)
**Reported**: 2026-04-27
**Priority**: 10 (High) — Impact: Minor (2) x Likelihood: Almost certain (5) <!-- re-rated 2026-04-28 — user-surfaced + iter-2-retro-corroborated + architect-Read-failure; corrected mislabel "Likely (3)" → policy-verbatim "Almost certain (5)"; Impact dropped Moderate→Minor since RISK-POLICY Impact-3 ("npm publish disrupted") doesn't apply to internal-tooling friction -->
**Effort**: M — likely combination of (a) `manage-problem` Step 5 P094 and Step 7 P062 README-refresh contracts to **truncate** the "Last reviewed" parenthetical to a fixed bound (e.g. 1 KB or 200 chars per session-summary fragment), (b) per-iter retro-class entries archive themselves to `docs/problems/README-history.md` (or similar archive sibling), (c) optional advisory script `packages/itil/scripts/check-problems-readme-budget.sh` mirroring P099's `check-briefing-budgets.sh` triplet (script + bats + ADR-tier-budget amendment).

**WSJF**: (10 × 1.0) / 2 = **5.0**
**Type**: technical

> Surfaced 2026-04-27 across multiple sessions. The "Last reviewed" line on `docs/problems/README.md` (line 3) accumulates session-summary fragments unbounded — every `manage-problem` Step 5 / Step 7 README refresh prepends a new "Prior:" segment without trimming any older segment. Current size: ~62 KB on a single line. Symptoms: breaks the Read tool at every offset/limit combination tested (file content exceeds 25K-token limit). Forces awk/grep workarounds to inspect any other section.

## Description

`manage-problem` Step 5 (P094 — README refresh on new ticket) and Step 7 (P062 — README refresh on every transition) both regenerate `docs/problems/README.md` and update its "Last reviewed" line:

> Update the "Last reviewed" line's parenthetical to name the new ticket (e.g. `P<NNN> opened — <one-line title>`) so the next session's fast-path check has a human-readable audit marker.

The intent: a short audit marker the next session can read without re-scanning all tickets. The reality: every retro / iter / transition appends a multi-paragraph session-summary fragment (commit details, architect verdicts, file lists, JTBD claims, full-prose rationales) **without trimming** any prior fragment. The line accumulates unbounded.

Current state: line 3 is a **single line** containing ~62,000 characters. `wc -L docs/problems/README.md` reports the longest line at ~62K. The Read tool's 25K-token limit is exceeded on every read attempt covering line 3 — `Read` returns `File content (NNNNN tokens) exceeds maximum allowed tokens (25000)` regardless of `offset` / `limit` combination (because the tool counts tokens in the *entire* file, not just the requested slice — verified this session).

Workaround pattern observed across multiple sessions: `awk` or `grep -n` with the line range bracketed to skip line 3 entirely. Forces 2-3 extra tool calls for any inspection task that touches `README.md`.

This is the **sibling pattern** of P099 (`docs/BRIEFING.md` grows unbounded via `run-retro` appends — violates progressive disclosure). P099 closed the briefing-side accumulator with the per-topic-file split + 5120-byte tier 3 budget per `check-briefing-budgets.sh`. The `docs/problems/README.md` "Last reviewed" line is the same accumulator pattern on a different surface. P099's fix triplet (advisory script + bats + ADR-tier-budget amendment) is the documented reusable shape (per `run-retro` Step 3 Tier 3 reusable-pattern note for JTBD-101).

## Symptoms

- `Read docs/problems/README.md` returns `File content (NNNNN tokens) exceeds maximum allowed tokens (25000)` on every offset/limit combination. Verified this session: `offset=1 limit=15` → 25558 tokens; `offset=2 limit=10` → same; `offset=14 limit=4` → 25558 tokens (the line-3 token count dominates regardless of slice).
- Workaround: `awk` or `grep -n | head` to read sections without touching line 3. Adds ~2-3 tool calls per inspection task.
- Observed across multiple sessions:
  - 2026-04-25 — flagged by AFK iter (work-problems retro)
  - 2026-04-26 — flagged by AFK iter 5 retro Step 2b ("docs/problems/README.md exceeds Read tool 25K-token limit — sibling to P099 / candidate for extension")
  - 2026-04-26 — flagged by AFK iter 7 retro
  - 2026-04-27 — hit twice this session: (a) finding P130 row position for insertion, (b) finding P124 row position for VQ-removal during retro
  - **2026-04-28 — user personally surfaced concern** during a `/wr-itil:work-problems` AFK loop, mid-iter-2: *"@docs/problems/README.md has a very large blob of text at the start of the file. I don't know why this is here and what value it provides. It makes the README not very readable, and I'm worried that it might be consuming token unnecessarily."* This is the first **user-facing** signal (prior hits were agent-internal Read-tool failures); the user is now reading the file and finds line 3 makes it un-skimmable.
  - 2026-04-28 — convergent independent evidence: iter 2 (P096 Phase 3) retro Step 2b flagged the same line-3 reload thrash — *"`Read` tool refused `docs/problems/README.md` (28k–36k tokens) — required four reload attempts at decreasing limits before falling back to `Grep` for line locations + `Bash head` for prefix preview"* — and explicitly recommended *"append new evidence to P134's symptoms via `/wr-itil:manage-problem` on next interactive session"*. The iter agent and the user surfaced the same problem within minutes, independently.
  - 2026-04-28 — architect-agent reviewing THIS very re-rate also hit a Read-tool failure: *"26.7k-token-exceeds-25k-limit error, even at offset=1, limit=5"*. Line 3 has crossed the threshold where the Read tool **cannot window-read the file at all** — this is a stronger symptom than reload-thrash. It is a hard tool failure on every offset/limit combination. Workaround paths (`awk`, `grep`, `Bash head`) are now mandatory; the Read tool is no longer usable for this file.
- The line content is genuinely useful audit history — names recent tickets, recent transitions, recent releases, recent decisions — but the accumulation pattern means the same audit history that's useful at 5KB is useless at 62KB because no tool can read it.
- The longer this goes, the worse it gets — every new ticket, every transition, every retro adds a new prepended fragment.

## Workaround

Per-session: `awk 'NR==1 || NR>=4'` to skip line 3 when reading the README. `grep -n "<token>" | head` to find specific row positions without loading the line. Both add tool-call overhead.

Cross-session: hand-edit line 3 occasionally to trim older fragments. No automated pruning.

## Impact Assessment

- **Who is affected**: every agent session that reads `docs/problems/README.md` (every `/wr-itil:work-problems` invocation, every `/wr-itil:manage-problem review`, every retro that updates the README, every fast-path freshness check). Solo-developer (JTBD-001) primarily; AFK orchestrator (JTBD-006) also impacted because every iter's manage-problem call triggers the friction.
- **Frequency**: every Read of the README. Workaround required every time; manage-problem's own Step 5/7 refresh contributes to the bloat.
- **Severity**: Moderate — degrades agent efficiency on a load-bearing surface. Not blocking (workarounds exist) but compounds: every session adds more bloat, making the workarounds slower over time.
- **Likelihood**: Likely — every session that touches the README hits this. Currently ~62KB; without intervention will continue to grow ~5-10KB per active session.
- **Analytics**: 2026-04-27 session — Read tool failed on `docs/problems/README.md` 4 times (P130 row insertion, P131 row insertion, P124 row find, P132 row insertion). Each required `awk` or `grep` workaround. Cumulative session cost ~$0 in subprocess (no extra subprocess fired) but ~4 extra tool calls.

## Root Cause Analysis

### Investigation Tasks

- [ ] **Decide whether the line 3 narrative carries enough audit value to justify any retention at all.** *2026-04-28 user signal*: "I don't know what value it provides" — open question whether aggressive truncation (drop, not archive) is acceptable. If the line 3 audit history is NOT load-bearing for any contract (the `manage-problem` SKILL.md Step 9 fast-path freshness check uses git-commit timestamp on README.md, not its prose contents — so line 3's content is purely human-readable audit), then **Option C-aggressive** (drop with no archive on every refresh) becomes viable and simplifies Phase 1 to a one-liner: regeneration always writes the most-recent fragment ONLY, no archive sibling needed. This direction-deciding question gates the truncation-strategy choice below — answer it before picking Option A/B/C.
- [ ] Decide truncation strategy (gated on the value-question above):
  - Option A: hard byte cap on the "Last reviewed" parenthetical (e.g. 1 KB). Older fragments overflow into archive sibling.
  - Option B: hard count cap on session-summary fragments (e.g. last 5 sessions). Older fragments overflow into archive.
  - Option C: rotate the entire "Last reviewed" line to a sibling `docs/problems/README-history.md` archive whenever a new fragment is added — keep README's line 3 to ONLY the most-recent fragment.
  - **Option C-aggressive** *(newly viable per the value-question)*: regeneration writes the most-recent fragment only; nothing archived. Simplest fix path; load-bearing only if the value-question's answer is "the line 3 prose has no consumer".
- [ ] Update `manage-problem` Step 5 P094 + Step 7 P062 README-refresh contracts to apply the chosen truncation.
- [ ] Optional: create `packages/itil/scripts/check-problems-readme-budget.sh` advisory diagnostic mirroring P099's `check-briefing-budgets.sh`. Threshold default: 5120 bytes for line 3 (matches P099's tier 3 envelope).
- [ ] Behavioural bats per ADR-005 + ADR-044 (once landed): fixture write a multi-segment line 3 → assert the truncation contract bounds it.
- [ ] Consider whether "Last reviewed" should be **structured** (frontmatter / YAML / multi-line) rather than free-prose so trimming can be deterministic per-segment rather than ad-hoc text-cut.
- [ ] Hand-trim the current line 3 once the contract lands (one-shot remediation of the existing bloat).

### Preliminary hypothesis

The "Last reviewed" parenthetical was designed to be **short** (one ticket name + transition reason) but became **unbounded** because:

1. Every retro / iter / transition adds detail-rich session-summary fragments instead of one-line ticket references.
2. No truncation mechanism exists in the manage-problem refresh contract — fragments only accrete.
3. The "Prior:" prefix convention encourages stacking rather than rotating (each new fragment cites the prior one as "Prior: <full prior fragment>", which then gets prepended-with-Prior again).

The same accumulator pattern that P099 closed for briefing topic files. The fix triplet is documented (advisory script + bats + ADR-tier-budget amendment); just needs application to the new surface.

## Fix Strategy

**Phase 1 — `manage-problem` truncation contract**:

- Update `manage-problem` Step 5 P094 README refresh contract: when authoring the "Last reviewed" parenthetical, **truncate** to the last N session fragments OR M bytes, whichever is smaller. Older fragments overflow into a sibling archive file or are dropped (contract decides).
- Same change to Step 7 P062.
- Document the truncation in both step prose so the next session's manage-problem call honours the cap.

**Phase 2 — advisory script**:

- New `packages/itil/scripts/check-problems-readme-budget.sh` mirroring `packages/retrospective/scripts/check-briefing-budgets.sh`. Reads `docs/problems/README.md`, measures line 3 byte count + total file size, emits `OVER` lines on exceedance. Threshold default: 5120 bytes for line 3 (matches P099 tier 3 envelope).
- Behavioural bats per ADR-005 / ADR-044.

**Phase 3 — ADR-040 amendment** (optional, if Phase 1+2 prove insufficient):

- Amend ADR-040 (progressive disclosure tier policy) to extend the Tier 3 advisory enforcement from briefing-only to "any accumulator-doc surface in `docs/`" — covering both `docs/briefing/<topic>.md` (P099) and `docs/problems/README.md` line 3 (P134) under one umbrella policy. Optional because Phase 1's truncation contract may be sufficient on its own; ADR-040 amendment is the formalising layer.

**Phase 4 — one-shot remediation** (manual user task, not automated):

- Hand-trim the current 62KB line 3 down to the most-recent N fragments. Move displaced content to `docs/problems/README-history.md` archive sibling (or accept the truncation as data loss).

**Out of scope**: re-architecting README.md as multi-file (e.g. WSJF.md / verifying.md / closed.md split). The single-file shape is load-bearing for the manage-problem fast-path check; splitting would require contract changes across multiple skills.

## Dependencies

- **Blocks**: (none — P134 is an accumulator-bloat gap; nothing strictly waits on it)
- **Blocked by**: (none — Phase 1 truncation contract can proceed standalone; Phase 2/3/4 follow)
- **Composes with**: P099 (closed — briefing-side sibling; reusable triplet documented in `run-retro` Step 3 Tier 3 reusable-pattern note for JTBD-101), P132 (this-session inverse-P078 over-asks — the topic-file rotation prompt fires 6 times because P099's tier 3 ask-per-file design is itself an over-ask; P134's truncation should follow the silent-classification model not the ask-per-overflow model), P094 + P062 (manage-problem refresh contracts both updated by Phase 1), P130 + P131 (this-session captures of agent-discipline gaps, same family).

## Related

- **P099** (`docs/problems/099-briefing-md-grows-unbounded-via-run-retro-appends-violating-progressive-disclosure.verifying.md`) — briefing-side sibling. Closed via per-topic-file split + 5120-byte tier 3 advisory + `check-briefing-budgets.sh` triplet. P134 mirrors the triplet on a different surface.
- **P094** (`docs/problems/094-...closed.md`) — `manage-problem` README refresh on creation. Phase 1 amends the refresh contract.
- **P062** (`docs/problems/062-...closed.md`) — `manage-problem` README refresh on transition. Phase 1 amends the refresh contract.
- **P118** (`docs/problems/118-...closed.md`) — `reconcile-readme.sh` cross-session drift catcher. Adjacent surface; doesn't fix line-3 bloat directly but composes with the manage-problem refresh contracts.
- **P130** (`docs/problems/130-...open.md`) — orchestrator presence-aware dispatch; this-session capture.
- **P131** (`docs/problems/131-...open.md`) — `.claude/` user-space writes; this-session capture.
- **P132** (`docs/problems/132-...open.md`) — inverse-P078 over-asks; this-session capture. Direct relevance: P134's truncation MUST be silent (no ask-per-overflow) per P132's mechanical-zone discipline.
- **ADR-040** (`docs/decisions/040-progressive-disclosure-tier-policy.proposed.md`) — tier policy. Phase 3 (optional) amends to cover `docs/problems/README.md` line 3 alongside briefing topic files.
- **`packages/itil/skills/manage-problem/SKILL.md`** Step 5 P094 + Step 7 P062 — refresh contracts updated by Phase 1.
- **`packages/retrospective/scripts/check-briefing-budgets.sh`** — pattern to mirror for Phase 2's advisory script.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance-without-slowing-down.proposed.md`) — primary persona served. README friction is exactly the "slowing down" half this JTBD targets.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — composes; AFK orchestrator's manage-problem calls in iters all hit the friction.
- 2026-04-27 session evidence: `Read docs/problems/README.md` failed 4 times this retro session (P130 row insertion, P131 row insertion, P124 row find, P132 row insertion); each required `awk` or `grep` workaround. Cumulative cross-session evidence: flagged by AFK iters 4, 5, 7 retros (2026-04-25 through 2026-04-26).

## Fix Released

**Released**: 2026-04-28 (AFK iter; pending `@windyroad/itil` patch — orchestrator's Step 6.5 owns the release cadence).

**Architecture verdict**: PASS no new ADR required. ADR-040 line 92 reusable-pattern note explicitly names "problems index" as a candidate surface for the advisory-script + bats + ADR-tier-budget triplet — clean instantiation of the documented pattern, not an extension. Forward-chronology archive (newest at the bottom of `docs/problems/README-history.md`) is the correct log-tier convention; divergence from the README's reverse-chrono surface convention is documented in the SKILL.md amendments. Bound choice (5120-byte hard ceiling on line 3) preserves consistency with ADR-040 Tier 3 envelope; the soft 1024-byte per-fragment cap is the granular authoring control. Risk within Low-4 appetite per RISK-POLICY.md; ADR-014 single-commit rule satisfied (one commit covers script + bats + 5 SKILL.md amendments + archive sibling + trimmed README + ticket transition).

**JTBD verdict**: PASS. JTBD-001 primary fit (Read-tool affordance restored on the highest-traffic problems-management surface — every agent session that previously paid 2-3 awk/grep/head workaround tool calls now reads `docs/problems/README.md` natively at any offset/limit). JTBD-006 composes (AFK orchestrator iters no longer pay the inspection tax). JTBD-101 composes (P099 advisory-triplet pattern re-applied at a new surface — the reusable-pattern promise from ADR-040 line 92 honoured for the first time post-P099).

**Phase 1 — `manage-problem` truncation contract** (canonical site):

- New "Last-reviewed line discipline (P134)" subsection in `packages/itil/skills/manage-problem/SKILL.md` Step 5, codifying:
  1. Single most-recent fragment only on line 3 — no `Prior:` stacking, no multi-paragraph rationale, no inline history carry-forward.
  2. Soft cap ≤ 1024 bytes per fragment (authoring guidance; multi-paragraph rationale belongs in retros / ticket bodies / ADR amendments).
  3. Forward-chronology archive at `docs/problems/README-history.md` (newest fragment at the bottom under `## YYYY-MM-DD` headings; same-day appends nest under existing heading).
  4. Hard ceiling 5120 bytes on line 3 (matches ADR-040 Tier 3 envelope; advisory-only via the new `check-problems-readme-budget.sh` script).
- Step 5 P094 (line 410), Step 6 P094 update (line 444), Step 7 P062 (line 555) refresh blocks all reference the canonical subsection inline; each call site stages both `docs/problems/README.md` AND `docs/problems/README-history.md` per ADR-014 single-commit grain.

**Phase 1 — sibling skills updated**:

- `packages/itil/skills/transition-problem/SKILL.md` line 178 — references the canonical discipline.
- `packages/itil/skills/transition-problems/SKILL.md` line 187 — single batch fragment (no per-pair stacking); soft cap ≤ 1024 bytes; one rotation per batch.
- `packages/itil/skills/review-problems/SKILL.md` line 146 — references the canonical discipline.
- `packages/itil/skills/reconcile-readme/SKILL.md` Step 4 + Step 5 — load-bearing inversion: the prior "ever-growing prose paragraph" convention (line 106) was the source-of-bloat surface; the new contract makes reconcile-readme parity-with-manage-problem instead of bloat-reintroducer.

**Phase 2 — advisory script + bats**:

- New `packages/itil/scripts/check-problems-readme-budget.sh` — diagnose-only advisory script; reads `docs/problems/README.md` (or supplied path); measures byte size of line 3; emits `OVER <readme-path> line=3 bytes=<N> threshold=<N>` when line 3 ≥ threshold (default 5120 bytes; overridable via `PROBLEMS_README_LINE3_MAX_BYTES`); always exits 0 (advisory; overflow is signal, not failure); exit 2 only on missing-file parse error; read-only.
- New `packages/itil/scripts/test/check-problems-readme-budget.bats` — 13 behavioural assertions per ADR-005 + ADR-037 + P081 covering existence + executable + threshold + boundary + env-var-override + missing-file-exit-2 + no-line-3 + empty-line-3 + read-only contract — 13/13 green.

**Phase 3 — ADR amendment**: NOT required. ADR-040 line 92 already documents the reusable-pattern note for "any accumulator-doc surface in `docs/`" with explicit naming of "problems index" as a candidate — application here is the documented future-surface honouring, not an extension. Architect verdict skipped the amendment unless future surfaces (risk-register per P102, ADR index) introduce divergent archive shapes that warrant generalising.

**Phase 4 — one-shot remediation**:

- `docs/problems/README-history.md` archive sibling created with the 76,582-byte legacy line-3 content preserved under `## 2026-04-28 (pre-P134 truncation contract — bulk legacy archive)` heading. Future refreshes append per-day fragments at the bottom; the legacy entry is the seed of the forward-chronology log.
- Current line 3 of `docs/problems/README.md` trimmed from 76,582 bytes to 800 bytes (95× reduction; well under both the 1024-byte soft cap and the 5120-byte hard ceiling).
- Total README size reduced from 129,928 bytes to 56,711 bytes (56% reduction). Read-tool 25K-token symptom verified closed in this same session: `Read docs/problems/README.md` (offset=1, limit=12) returned cleanly without `tokens exceeds maximum allowed tokens` error.

**Verification path** (user-side):

1. Read `docs/problems/README.md` at any offset/limit — should succeed without the prior 25K-token error.
2. Run `packages/itil/scripts/check-problems-readme-budget.sh` — should return empty output, exit 0.
3. Confirm `docs/problems/README-history.md` exists with the legacy bulk preserved verbatim under the `## 2026-04-28 (pre-P134 truncation contract — bulk legacy archive)` heading.
4. After future `manage-problem` / `transition-problem` / `review-problems` invocations, confirm line 3 of README continues to carry only the most-recent fragment AND `README-history.md` accretes per-day archive entries at the bottom (forward chronology).
5. Spot-check next 3 retros for line-3 size — should remain under 1024 bytes per refresh; if any fragment trips the 5120-byte ceiling, the advisory script surfaces it for follow-up curation.
