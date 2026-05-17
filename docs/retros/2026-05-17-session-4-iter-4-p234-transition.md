# Iter 4 Retro — session 4, P234 Open → Known Error transition

> Scope: single iter of `/wr-itil:work-problems` AFK orchestrator session 4 (iter 4). Iter task: P234 Open → Known Error transition via `/wr-itil:transition-problem` following the @windyroad/itil@0.30.4 release of P234 Phase 1 hook (release commit 50626e7). Retro invoked per P086 retro-on-exit before ITERATION_SUMMARY emission.

## Briefing Changes

- **Added**: none. No new cross-session learnings emerged this iter beyond what existing tickets already capture (P211 / P233 / P132 — all already-ticketed class-of-behaviour). Per P234's own anti-defer contract, this is not a defer — the briefing-worthy patterns ARE ticketed; tickets ARE the durable surface.
- **Removed**: none.
- **Updated**: none.
- **README index refreshed**: none.

## Signal-vs-Noise Pass (P105)

> Deferred per P234 SCHEDULED-FUTURE-SURFACE citation — the briefing SVN backlog (146 entries across 17 topic files) is captured as **P235** (WSJF 1.5 Low Open). P235 IS the legitimate scheduled-future-surface per P234's worked-example correction pattern. NOT a fictional defer. This iter's scope (single-ticket transition, no source-code change, no new briefing entries) does not produce new entries requiring per-entry signal scoring. Re-evaluation trigger: P235 WSJF re-rank OR R6 noise-accumulation gate (signal scores ≥+3 candidates accumulate to displace Critical Points budget).

## Problems Created/Updated

- **P234** — transitioned Open → Known Error via `/wr-itil:transition-problem` (commit b9f8049). Released-fix detection: Phase 1 hook shipped at @windyroad/itil@0.30.4 per CHANGELOG.md `## 0.30.4`. Verification criterion captured in Change Log iter 4 entry: no analogous fictional-defer recurrence in `docs/retros/*.md` across at least one subsequent retro exercising Tier 3 / Signal-vs-Noise / Step 4b Stage 1 surfaces (mirrors P132 Phase 2b framing).

## Verification Candidates

> None this iter. P234's own transition is to Known Error (not Verifying — that's the next state-advance, requires in-the-wild observation across at least one subsequent retro). Same-iter verifyings are excluded per Step 4a contract; cross-iter same-session verifyings also excluded (verification needs subsequent SESSION, not subsequent ITER).

## Pipeline Instability

> Surfaced per Step 2b AFK fallback (ADR-013 Rule 6 / orchestrator constraint "No capture-* skills (ADR-032)"). User reviews on return; ticketing per accepted detection via `/wr-itil:manage-problem`.

| Signal | Category | Citations | Decision |
|--------|----------|-----------|----------|
| Orchestrator iter-4 dispatch instruction described P132 Phase 2b as "load-bearing structural-enforcement hook to implement" — but Phase 2b ALREADY SHIPPED at commit 841db68 (@windyroad/itil@0.30.3 / iter 3 of session 3 / 2026-05-17). Orchestrator's understanding of P132's actionable scope was based on the ticket title (which still says "Phase 2b structural-enforcement hook load-bearing") rather than the ticket body's Change Log (which records Phase 2b shipped). Iter would have created a duplicate hook if I'd executed the dispatch instruction verbatim. | Skill-contract violations / Subagent-delegation friction | Orchestrator subprocess prompt (this iter's invocation) named P132 Phase 2b as the dispatch target with implementation guidance; ticket body Change Log entry "**2026-05-17 — Phase 2b shipped** by `/wr-itil:work-problems` AFK iter 4 of session 3" + commit 841db68 in git log + CHANGELOG.md `## 0.30.3` entry quoting commit 841db68 contradict that framing. | matches **P211** (work-problems orchestrator carries prior-ticket Fix Strategy verbatim into iter dispatch without re-grounding) — append evidence to RCA. New evidence point: 2026-05-17 session 4 iter 4 dispatch; orchestrator's understanding stale by ~2 hours (Phase 2b shipped earlier same session). |
| P234 Phase 1 hook `packages/itil/hooks/itil-fictional-defer-detect.sh` did NOT fire on this iter's retro file write (THIS file) — despite the file containing defer-rationale phrases (`deferred per` in the SVN Pass section, `defer` in multiple places). Expected behaviour because the just-released @windyroad/itil@0.30.4 is NOT yet in the local plugin cache for this iter subprocess. If the cache had been refreshed (per P233 Option C: orchestrator auto-invokes /install-updates in Step 6.5 post-release-drain), the hook would have fired on this retro write and the advisory would have surfaced the legitimate-defer citations (P235 ticket cite, P132 Phase 2b citation, etc.). | Release-path instability / Repeat-work friction | Bash `cat packages/itil/package.json \| grep version` returned `"version": "0.30.4"` (source); plugin cache at `~/.claude/plugins/cache/windyroad/wr-itil/0.29.0/` shows 0.29.0 (cache stale; 1 minor + 4 patch versions behind). The hook source IS shipped (`packages/itil/hooks/itil-fictional-defer-detect.sh` exists in source tree per session-3 iter-3 commit 9117246) but the cache version 0.29.0 predates it. The retro file write completes cleanly without hook advisory — visible by absence of advisory text in tool result. | matches **P233** (AFK iter subprocess plugin cache stale after release — just-shipped hook does not protect the next iter) — append evidence to RCA. New evidence point: 2026-05-17 session 4 iter 4; P234 Phase 1 hook is the second sibling-hook (after P132 Phase 2b) to demonstrate the cache-stale failure mode same-session. |
| P063 external-root-cause detection in `/wr-itil:transition-problem` Step 5 fired false-positive on the P234 ticket body's `@windyroad/itil` scoped-npm matches + `upstream` / `external` prose tokens. All matches are self-references to our own published packages OR prose-context inverse-correctness/conditional-deferral framing per P179 — not actual external dependencies. The SKILL.md provides a false-positive recovery path (stable marker `- **Upstream report pending** — false positive; detection misfire`), but the agent must derive the false-positive judgment per-ticket. Sibling fix shape candidate: extend P063 detection regex with self-package allowlist (`@<own-org>/<own-package>` derived from package.json workspaces / publish scope). | Skill-contract violations | Step 5 detection scan output (grep -iE pattern matched 6 lines including `@windyroad/itil@0.30.3` / `@windyroad/itil@0.30.4` cites + `upstream` in `## Reported Upstream` template references + `external` in inverse-correctness symmetry prose). False-positive marker appended to ticket `## Related` per SKILL recovery path (verifiable in commit b9f8049 diff). | new ticket candidate — P063 sibling: "P063 external-root-cause detection does not allowlist self-org scoped-npm package self-references — false-positive fires on every P132 / P234 / sibling-ticket transition citing our own @windyroad packages". WSJF estimate: Mod (3) × Possible (3) = 9 / S = 9.0. Defer ticket creation per orchestrator constraint "No capture-* skills (ADR-032)"; user reviews on return. Marker-pattern false-positive cost per occurrence: ~1 agent turn (write marker + verify), so low per-occurrence — but recurs on every governance-skill transition since most reference sibling tickets / own packages. WSJF-worthy if recurrence frequency confirmed (≥3 transitions/session). |

> JTBD currency advisory: clean (12 packages, drift_instances=0 per `wr-retrospective-check-readme-jtbd-currency` output trailing summary line).

## Context Usage (Cheap Layer)

| Bucket | Bytes | % of total | Δ vs prior |
|--------|-------|------------|------------|
| decisions | 1,367,464 | 40.4% | +20,627 (+1.5%) |
| skills | 888,786 | 26.3% | +64,949 (+7.9%) |
| hooks | 371,318 | 11.0% | +33,123 (+9.8%) |
| problems | 367,572 | 10.9% | +60,832 (+19.8%) |
| memory | 217,269 | 6.4% | 0 (0%) |
| briefing | 125,974 | 3.7% | +6,871 (+5.8%) |
| jtbd | 41,931 | 1.2% | +382 (+0.9%) |
| project-claude-md | 4,277 | 0.1% | 0 (0%) |
| framework-injected | not measured | — | not measured — reason=framework-injected-no-on-disk-source |
| **TOTAL** | **3,384,591** | **100%** | **+104,784 (+3.2%)** |

**Top 5 offenders**: `decisions` (1.37 MB, byte-count-on-disk) / `skills` (889 KB, byte-count-on-disk) / `hooks` (371 KB, byte-count-on-disk) / `problems` (368 KB, byte-count-on-disk) / `memory` (217 KB, byte-count-on-disk).

> Per-plugin breakdown available in `/wr-retrospective:analyze-context` (deep layer).

Deep-layer last run: 2026-05-15 (2 days ago — within 14-day window; `problems` bucket +19.8% is just under the +20% deep-analysis trigger; no advisory fires this iter). THRESHOLD bytes=10240 not exceeded by the report itself (this section ~1.2 KB).

## Topic File Rotation Candidates

> 14 OVER files at 1.0×-1.96× ratio (none MUST_SPLIT this iter — session 3 retro's cascade-rotation fix landed 3 deep-archive tier files which dropped all 3 MUST_SPLIT files into Branch B territory). Per Branch B rules: defer permitted; one or two more retros of accumulation will escalate to MUST_SPLIT (Branch A). The scheduled-future-surface is the next `check-briefing-budgets.sh` invocation at next retro (the SKILL Step 3 Branch B's documented "deferred per Branch B" allowlist pattern).

| Topic file | Bytes | Threshold | Proposed rotation | Decision |
|------------|-------|-----------|-------------------|----------|
| `docs/briefing/afk-subprocess-mechanics.md` | 9,093 | 5,120 | leave-as-is (1.78× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/afk-subprocess-recovery.md` | 9,397 | 5,120 | leave-as-is (1.84× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/afk-subprocess.md` | 6,712 | 5,120 | leave-as-is (1.31× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/agent-hook-gate-quirks.md` | 9,434 | 5,120 | leave-as-is (1.84× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/agent-interaction-patterns.md` | 6,684 | 5,120 | leave-as-is (1.31× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/governance-workflow-archive-mid.md` | 5,568 | 5,120 | leave-as-is (1.09× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/governance-workflow-archive-pre-2026-04-23.md` | 5,529 | 5,120 | leave-as-is (1.08× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/governance-workflow-archive.md` | 6,086 | 5,120 | leave-as-is (1.19× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/governance-workflow-surprises.md` | 8,269 | 5,120 | leave-as-is (1.62× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/hooks-and-gates-archive-pre-2026-05-04.md` | 7,615 | 5,120 | leave-as-is (1.49× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/hooks-and-gates-archive.md` | 10,009 | 5,120 | leave-as-is (1.96× ratio; Branch B — close to 2× threshold but still under) | deferred per Branch B |
| `docs/briefing/plugin-distribution.md` | 8,975 | 5,120 | leave-as-is (1.75× ratio; Branch B) | deferred per Branch B |
| `docs/briefing/releases-and-ci-archive.md` | 9,941 | 5,120 | leave-as-is (1.94× ratio; Branch B — close to 2× threshold) | deferred per Branch B |
| `docs/briefing/releases-and-ci.md` | 7,208 | 5,120 | leave-as-is (1.41× ratio; Branch B) | deferred per Branch B |

> SCHEDULED-FUTURE-SURFACE for these 14 OVER files: next retro's Step 3 Tier 3 budget pass invocation of `check-briefing-budgets.sh`. The `deferred per Branch B` decision is in the SKILL.md Step 3 allowlist (Branch B carries the next-retro `check-briefing-budgets.sh` trigger as the scheduled surface inside the SKILL contract itself). Not a fictional defer per P234 contract.

## Ask Hygiene (P135 Phase 5 / ADR-044)

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| (none — 0 AskUserQuestion calls this iter) | — | — | — |

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

> Clean iter for Ask Hygiene. The orchestrator's constraint "No mid-loop AskUserQuestion (P135 / ADR-044) — queue at outstanding_questions" was honoured by both the transition-problem skill (Step 5 P063 detection applied silent-agent-action recovery path per ADR-044 framework-resolution boundary; chose false-positive marker over fictional upstream-report obligation) AND the retro flow (Step 1.5 delete-queue deferred per P235; Step 2b detections surfaced per Pipeline Instability section per ADR-013 Rule 6 AFK fallback; Step 4a no candidates; Step 4b Stage 1 ticketing deferred per orchestrator constraint "No capture-* skills (ADR-032)" — see Tickets Deferred below).

## Tickets Deferred

| Observation | Cause | Citation |
|-------------|-------|----------|
| P211 evidence append: 2026-05-17 session 4 iter 4 — orchestrator stale Fix Strategy in dispatch (assumed P132 Phase 2b not yet shipped; was shipped 2 hours earlier same session at commit 841db68) | `skill_unavailable` | Orchestrator subprocess constraint "No capture-* skills (ADR-032)" — `/wr-itil:capture-problem` is the lightweight aside surface for `manage-problem update`; both deferred per the explicit orchestrator iter constraint. Surface via Pipeline Instability table (Step 2b) for user-review-on-return ticketing. |
| P233 evidence append: 2026-05-17 session 4 iter 4 — P234 Phase 1 hook second-sibling cache-stale demonstration (after P132 Phase 2b cache-stale in session 3) | `skill_unavailable` | Same — orchestrator constraint forbids capture-* skills. Surface via Pipeline Instability table for user-review-on-return ticketing. |
| New P063-sibling ticket candidate: P063 external-root-cause detection should allowlist self-org scoped-npm package self-references — false-positive fires on every governance-skill transition citing our own @windyroad packages or sibling-ticket cross-references | `skill_unavailable` | Same — orchestrator constraint forbids capture-* skills. Surface via Pipeline Instability table for user-review-on-return ticketing. WSJF estimate provided inline. |

> All deferrals carry `cause: skill_unavailable` per the Step 4b Stage 1 allowlist (the orchestrator's "No capture-* skills (ADR-032)" constraint IS a skill-unavailability gate at the orchestrator-iter-boundary level). No non-allowlisted causes (no session-length / context-budget / "I'll capture next session" rationalisations — those would be P148 violations + P234 fictional-defer recurrences).

## Codification Candidates

| Kind | Shape | Suggested name / Target file | Scope / Flaw | Triggers / Evidence | Decision |
|------|-------|------------------------------|--------------|---------------------|----------|
| improve | hook | `packages/itil/skills/transition-problem/SKILL.md` Step 5 + sibling P063 detection scripts | P063 external-root-cause detection misfires on `@<own-org>/<own-package>` self-references and on prose tokens (`upstream` / `external` / `vendor`) used in inverse-correctness / conditional-deferral framing prose, not as actual external-dependency citations | (1) This iter's P234 transition fired false-positive on `@windyroad/itil@0.30.3` / `@windyroad/itil@0.30.4` + `upstream` (in `## Reported Upstream` section template reference) + `external` (in inverse-correctness P132/P234 symmetry prose); (2) plausibly recurs on every governance-skill transition citing sibling tickets or own packages — recurrence frequency ≥3/session would justify WSJF >= Mod | deferred per `skill_unavailable` (orchestrator capture-* constraint) — Stage 2 fix-strategy stub: extend P063 detection regex with self-org allowlist derived from `package.json` workspaces / publish scope + named-section context guard (exclude `## Reported Upstream` template section + `inverse-correctness` prose patterns) |
| improve | skill | `packages/itil/skills/work-problems/SKILL.md` Step 3 (iter dispatch composition) | Orchestrator carries prior-ticket Fix Strategy verbatim into iter dispatch without re-grounding against ticket-body Change Log (P211). This iter's dispatch told me to "apply Phase 2b implementation" but Phase 2b was shipped 2 hours earlier same session — orchestrator's understanding stale. Verified in P211 existing ticket. | (1) This iter's dispatch; (2) P211 existing ticket has prior evidence | deferred per `skill_unavailable` (orchestrator capture-* constraint) — Stage 2 fix-strategy stub: extend Step 3 dispatch composition to grep ticket-body Change Log for ship-marker patterns (`Phase N shipped` / `commit <SHA>`) within last 24h before composing dispatch instruction; warn on dispatch-vs-actual-state mismatch |
| improve | skill | `packages/itil/skills/work-problems/SKILL.md` Step 6.5 (release-drain) | P233 cache-stale: just-shipped hooks/SKILLs don't protect next iter because cache isn't refreshed post-release. P234 Phase 1 hook is the second sibling-hook (after P132 Phase 2b) to demonstrate this same session. Preferred fix in P233 ticket body: Option C (orchestrator auto-invokes `/install-updates` in Step 6.5 post-release-drain). | (1) This iter's retro write didn't trigger the just-released hook; (2) P233 existing ticket has prior evidence | deferred per `skill_unavailable` (orchestrator capture-* constraint); Phase implementation tracked in existing P233 ticket — no new Codification stub needed beyond evidence append |

## No Action Needed

- P234 Phase 1 hook shipped + transitioned — full ITIL state-advance loop closed for the iter (Open → Known Error; Verifying transition gated on subsequent-session observation).
- Ask Hygiene clean (0 lazy calls).
- JTBD currency clean (drift_instances=0).
- Briefing budgets all in Branch B (no MUST_SPLIT this iter; cascade-rotation fix from session 3 holding).
- Context-usage `problems` bucket +19.8% just under the +20% deep-analysis trigger — no advisory fires.
- Risk-scorer pipeline gate PASS at all three layers (commit=3 Low / push=1 Very Low / release=1 Very Low — within Low-4 appetite).

## Iter Meta-Observations (P086 reflection prose)

- **Meta-validation of P234's `## Scheduled Future Surface for Fix Shipping` discipline**: the orchestrator WSJF queue's deterministic re-selection of P234 for the post-release transition is exactly the path the ticket's section described. The named mechanism worked; the ticket's anti-meta-recursion framing held. This is the first iter where a ticket transitioned via its own self-described scheduled-future-surface, validating the pattern's mechanical applicability.

- **Single-iter-scope retro shape**: scope-bounded retro (one ticket, one transition, one commit) produced a tight ~150-line retro file vs ~600-line session retros. Iter-scoped retros are appropriate for single-ticket iters; session-scope retros remain appropriate for session-wrap. No P086 contract change needed — the contract is invocation-frequency, not scope-bounded.

- **No agent self-discipline regressions** observed this iter: zero AskUserQuestion calls (orchestrator forbade them); zero fictional defers (all deferrals cite `skill_unavailable` per allowlist OR `Branch B` per SKILL allowlist OR P235-style scheduled-future-surface); zero P063 false-positive prompt fires (silent-agent-action recovery applied per ADR-044 + SKILL false-positive recovery path).

<!-- iter-meta: scope=p234-open-to-known-error transition-commit=b9f8049 release-commit=50626e7 release-version=@windyroad/itil@0.30.4 askuserquestion-count=0 lazy-count=0 fictional-defer-count=0 ticket-creates=0 ticket-updates=1 commit-count=1 -->
