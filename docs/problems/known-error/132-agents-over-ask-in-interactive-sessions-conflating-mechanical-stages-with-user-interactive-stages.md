# Problem 132: Agents over-ask in interactive sessions — conflating mechanical-stages with user-interactive-stages of multi-stage skill contracts (inverse-P078)

**Status**: Known Error
**Reported**: 2026-04-27
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M — likely combination of (a) new UserPromptSubmit / Stop hook that detects AskUserQuestion calls firing in SKILL-explicit no-ask zones, (b) project CLAUDE.md rule reinforcing "when SKILL contract says mechanical, do not ask", (c) targeted in-skill reminders in run-retro Step 1.5 / Step 4b Stage 1 / Step 4a / wherever a skill explicitly carves out a no-ask zone. The detection hook is the load-bearing piece; CLAUDE.md + per-skill reinforcement are supporting layers.
**WSJF**: (9 × 1.0) / 2 = **4.5**
**Type**: technical

## Reopened

**2026-05-06 — REGRESSION OBSERVED.** During /wr-itil:manage-incident I001 declaration, agent asked 4 questions in one AskUserQuestion call (Severity / Start time / Scope / Title). 3 of 4 sub-questions were lazy classifications per ADR-044 Step 2d Ask Hygiene Pass:

- **Title**: derivable from user prose (kebab-case the description) — agent asked anyway with 3 candidate options.
- **Severity**: ratable from RISK-POLICY.md matrix + observable evidence (held-cluster age 12 days, scorer state push=2/release=1 within appetite, no service disruption) — agent asked anyway with 4 severity options.
- **Start time**: pullable from `git log --diff-filter=A --follow -- docs/changesets-holding/` (first hold = 2026-04-24) — agent asked anyway with 3 candidate options.
- **Scope** (1 of 4 was non-lazy): genuine direction-setting (downstream-adopter-risk inclusion was user-judgment).

User correction: `"why are you asking me this???"` — strong-signal P078. The Phase 2c CLAUDE.md MANDATORY rule shipped 2026-04-28 ("when SKILL contract says mechanical, do not ask") was bypassed because manage-incident Step 4 says "Use AskUserQuestion for anything not in args" without distinguishing derivable-vs-judgment fields — a SKILL-contract carve-out the Phase 2c rule didn't anticipate.

Captured as `feedback_dont_subcontract_declaration_fields.md` memory (project-scoped) extending the existing `feedback_act_on_obvious_decisions.md` pattern. The new shape: declaration-skill argument-backfill is NOT mechanical-stage classification but IS framework-resolvable from observable evidence.

**Why reopen instead of new ticket**: this IS the same class P132 tracks — agent over-asking in interactive sessions when framework can resolve. The verification path documented in Fix Released ("direct observation in subsequent interactive sessions") empirically failed. Phase 2b deferral was contingent on R6 gate not firing; this regression is one data point toward R6 (lazy=3 in this retro). Two more retros at lazy ≥ 2 trigger Phase 2b.

**Updated Fix Strategy refinement**: extend Phase 2a (per-skill SKILL.md reinforcement) to declaration skills (manage-incident Step 4, manage-problem create flow, create-adr argument-collection): rewrite "Use AskUserQuestion for anything not in args" to "Derive every observable field; use AskUserQuestion only for genuinely-direction-setting fields". Composes with P136 ADR-044 alignment audit (this is one of the audit's worked-example shapes).

**Phase 2a-i: manage-incident Step 4 (shipped 2026-05-15)** — `/wr-itil:work-problems` iter 3 of 2026-05-15 (commit `<TBD>`). Rewrote `packages/itil/skills/manage-incident/SKILL.md` Step 4 from a single "Use AskUserQuestion for anything not in $ARGUMENTS" instruction to a derive-first dispatch table mirroring `/wr-itil:capture-problem` Step 1.5 (P185 worked example):
- **Title**: silent kebab-case-from-prose derivation + stderr advisory citing source tokens.
- **Symptoms**: pulled verbatim from prose into Step 5's `## Observations` section.
- **Start time**: three-source dispatch (description timestamp regex → `git log --diff-filter=A --follow` first-touch → wall-clock UTC default) + stderr advisory citing the source.
- **Severity**: RISK-POLICY matrix lookup against description signals + named anchors; clear-cell maps silently; ambiguous evidence falls back to AskUserQuestion as the genuine ADR-044 cat-5 (taste) surface.
- **Scope**: retained as AskUserQuestion ADR-044 cat-1 (direction-setting) — the genuine user-judgment surface (semantic blast radius the framework cannot infer).

Closes the 2026-05-06 I001 regression on the manage-incident surface (3 of 4 lazy sub-questions become 0 of 1 lazy sub-question; Scope alone is the surviving genuine cat-1 surface). Bats coverage extended in `manage-incident-adr-044-contract.bats` with 7 new Surface 2 assertions (cat-4 cross-ref, Title derive-from-prose, Start time derive-from-evidence, Severity derive-from-matrix, Scope-retains-Ask negative-of-negative guard, P132 traceability, ADR-026 stderr advisory contract). All 53 manage-incident bats green.

**Phase 2a-ii: manage-problem Step 4 (shipped 2026-05-15)** — `/wr-itil:work-problems` iter 4 of 2026-05-15. Rewrote `packages/itil/skills/manage-problem/SKILL.md` Step 4 from "Use AskUserQuestion for anything not in args" to a derive-first dispatch table mirroring iter 3's manage-incident Step 4 refactor (commit b7cc645) and capture-problem Step 1.5 worked example (P185):
- **Title**: silent kebab-case-from-prose derivation + stderr advisory citing source tokens (cat-4 silent-framework).
- **Priority** (Impact × Likelihood): RISK-POLICY matrix lookup against description signals (impact / likelihood / named anchors); clear-cell maps silently; ambiguous evidence falls back to AskUserQuestion as the genuine cat-5 (taste) surface.
- **Description**: retained as AskUserQuestion ADR-044 cat-1 (direction-setting) fallback ONLY when `$ARGUMENTS` carries no prose at all — without prose there is literally nothing to capture.
- **Reported / Status / Symptoms / Workaround**: already inferred, unchanged.

Three declaration-skill surfaces now ship the I2-isomorphic derive-first dispatch (`/wr-itil:capture-problem` Step 1.5, `/wr-itil:manage-incident` Step 4, `/wr-itil:manage-problem` Step 4). Architect verdict PASS (no new ADR — ADR-044/013/026/052 already authorise + P132 Phase 2a explicit fix strategy). JTBD verdict PASS (JTBD-001 primary; JTBD-006 + JTBD-101 compose). Bats coverage in new file `packages/itil/skills/manage-problem/test/manage-problem-adr-044-step4-derive-first.bats` (10 assertions: cat-4 cross-ref, cat-1 fallback cross-ref, Title derive-from-prose, Priority derive-from-RISK-POLICY, Description-retains-Ask negative-of-negative, P132 traceability, ADR-026 stderr advisory contract, cross-skill consistency cross-ref, Step 4b multi-concern preservation guard, Step 2 duplicate-check preservation guard). 168/168 manage-problem suite green.

**Phase 2a-iii-A (shared helper extraction + 3-surface retrofit) — shipped 2026-05-16** by `/wr-itil:work-problems` AFK iter 3. New `packages/itil/lib/derive-first-dispatch.sh` helper centralised slug derivation, two-sided lexical classifier, RISK-POLICY matrix lookup, and the I2-isomorphic stderr advisory format. All three existing declaration-skill surfaces (capture-problem Step 1.5, manage-incident Step 4, manage-problem Step 4) retrofitted to invoke the helper. See Change Log 2026-05-16 entry.

**Phase 2a-iii-B (create-adr as 4th adopter) — shipped 2026-05-16** by `/wr-itil:work-problems` AFK iter 4 of 2026-05-16. The fourth declaration-skill surface (`/wr-architect:create-adr` Step 2 argument-collection) now invokes the shared helper. Architect verdict ISSUES FOUND → resolved: cross-package source from `packages/itil/lib/` would violate ADR-017 (Shared code duplicated into per-package lib/ kept in sync) because architect-package skills published as `@windyroad/architect` cannot depend on itil-package files at runtime. Resolution: canonical helper moved from `packages/itil/lib/derive-first-dispatch.sh` to `packages/shared/derive-first-dispatch.sh`; synced per-package copies at `packages/itil/lib/derive-first-dispatch.sh` AND `packages/architect/lib/derive-first-dispatch.sh`; sync script `scripts/sync-derive-first-dispatch.sh` (with `--check` mode) + npm scripts `sync:derive-first-dispatch` + `check:derive-first-dispatch` + CI step in `.github/workflows/ci.yml` + drift-test in `packages/shared/test/sync-derive-first-dispatch.bats`. Mirrors the P026 / ADR-017 pattern for `install-utils.mjs`. Architect verdict 2026-05-16: PASS subject to ADR-017 resolution (now applied); confirmed cat-1 retention for `decision-makers` (no silent derive from `git config user.name` — multi-party-decision mis-attribution risk); confirmed cat-1 for `Considered Options` (framework cannot generate the alternative space). JTBD verdict PASS (JTBD-001 primary; JTBD-006 + JTBD-101 compose).

create-adr SKILL.md Step 2 rewritten from a single instruction (*"You MUST use the AskUserQuestion tool to collect the decision context"*) to a derive-first dispatch table covering 12 fields:
- **Derivable silently (cat-4)**: Title (kebab from prose), status=`proposed`, date=today, reassessment-date=today+3mo, Context-and-Problem-Statement (verbatim from `$ARGUMENTS` prose), consulted/informed (default empty).
- **User-judgment fallback (cat-1)**: Context-when-no-prose, decision-makers, Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation.

The full Phase 2a 4-surface scope is now SHIPPED: `/wr-itil:capture-problem` Step 1.5 (P185 worked example), `/wr-itil:manage-incident` Step 4, `/wr-itil:manage-problem` Step 4, `/wr-architect:create-adr` Step 2 — all four sourcing the helper from their own per-package `lib/` copy via `packages/shared/` canonical + sync. The I2-isomorphic stderr advisory shape is locked-in across the 4-surface set. Phase 2b (load-bearing detection hook) remains DEFERRED — the R6 gate (lazy-AskUserQuestion ≥2 across 3 retros) has NOT fired since Phase 2a shipped, so the framework's anti-BUFD discipline continues to apply.

**Reassessment trigger**: if a regression analogous to I001 fires on any of the 4 declaration-skill surfaces, escalate priority via WSJF re-rank and trigger Phase 2b detection-hook work.

## Fix Released

Declarative-layer fix shipped 2026-04-28 in this commit. Phases:

- **Phase 2c (CLAUDE.md MANDATORY rule)** — shipped this iter. Added a fourth MANDATORY discipline-rule entry to project `CLAUDE.md` mirroring the P085 / P078 / P131 entry shape. Rule text: when a SKILL contract names a stage as mechanical / no user decision / policy-authorised silent proceed / agent owns silent classification / silent agent action, do NOT call `AskUserQuestion` in that stage. Cites ADR-044's 6-class authority taxonomy and the worked-example list already in-skill (`run-retro` Step 1.5 / Step 3 / Step 4a / Step 4b; `/wr-itil:work-problems` Step 6.5 + ADR-042 auto-apply; `/install-updates` Step 6a). Authority: `docs/decisions/044-decision-delegation-contract.proposed.md`.
- **Phase 2a (per-skill SKILL.md reinforcement)** — already shipped via P135 Phase 2 (commit fae42aa, 2026-04-28). The two specific 2026-04-27 user-corrections this ticket called out (Step 3 briefing **removals** and Step 3 Tier 3 topic-file **rotations** in `packages/retrospective/skills/run-retro/SKILL.md`) are now silent agent action with explicit `P135 / ADR-044` citations at SKILL.md lines 285-287 and 303-312. No further SKILL.md edits required this iter — the fix shape is complete via P135 composition.
- **Phase 2b (load-bearing detection hook)** — DEFERRED. Composes with the P135 R6 numeric gate (lazy-AskUserQuestion count ≥2 across 3 consecutive retros per ADR-044 Reassessment Trigger). The R6 gate has NOT fired per current `docs/retros/<date>-ask-hygiene.md` trail. Phase 2b will be triggered by the framework when reality demands it; deferring is the project's anti-BUFD discipline, not unfinished obligation. Precedent: P131 Phase 1 (CLAUDE.md rule) shipped first; Phase 2 enforcement hook landed in a follow-on after observation.

**Verification path**: direct observation in subsequent interactive sessions. The Step 2d Ask Hygiene Pass (`packages/retrospective/scripts/check-ask-hygiene.sh`) is the cross-session regression metric; lazy count remaining ≥2 across 3 consecutive retros fires the R6 gate and re-opens the question of Phase 2b.

**Recovery path**: declarative rules are reversible — edit the CLAUDE.md MANDATORY entry directly to amend / soften / supersede. Ticket flips back to Open via `/wr-itil:transition-problem 132 open` if the rule itself proves wrong.

> Surfaced 2026-04-27 by direct user observation during `/wr-retrospective:run-retro` execution: *"As part of the retro, there is friction with you asking me if you should update the briefing and/or create tickets. Why do you feel you need to ask me?"*. P078 contradiction-signal pattern (the "you" + "why" pattern that signals a class-of-behaviour correction). The agent then traced the cause back to a defensive over-asking habit accumulated across the session: the user had corrected multiple upstream decisions (subprocess dispatch in iter 9, grep approach for P081, `.claude/` writes for the Plan output, retro cascade scope), and the agent began treating EVERY decision as user-confirmable instead of trusting SKILL contracts that explicitly carved out no-ask zones for mechanical actions.

## Description

Several SKILL contracts in this project explicitly distinguish **mechanical stages** (no user decision required — agent acts directly) from **user-interactive stages** (AskUserQuestion fires per ADR-013 Rule 1). The canonical example is `run-retro` Step 4b's two-stage codification flow:

- **Stage 1**: ticket every codify-worthy observation. *Mechanical — no user decision*. The skill text is explicit: *"Stage 1 fires regardless — ticketing is mechanical and does not require user input"*.
- **Stage 2**: record proposed fix strategy on each ticket. *User-interactive — per ticket*.

Similar mechanical-vs-interactive splits exist in:

- **`run-retro` Step 1.5 signal-vs-noise pass** — *"Classification ownership (policy-authorised per ADR-013 Rule 5): the agent owns silent classification. No AskUserQuestion is fired for individual entry promotions, demotions, or keep decisions"*. Only the **delete queue** (score ≤ -3) requires user confirmation.

### Two SKILL-text gaps the user surfaced 2026-04-27

The user identified two **additional** mechanical-zones the SKILL.md text currently mis-classifies as ask-zones, and which inflate the over-ask count further:

1. **`run-retro` Step 3 briefing REMOVALS** — current SKILL text reads *"Use the AskUserQuestion tool to confirm any removals"*. User direction 2026-04-27: *"removals shouldn't be an ask"*. The remove-on-signal-decay decision should follow the same silent-classification model as Step 1.5 — agent applies the signal-vs-noise heuristic and removes (or trims, or compresses) without asking. The SKILL contract change: `Step 3 removals → no-ask, agent owns silent removal decisions per Step 1.5 ownership rules`.

2. **`run-retro` Step 3 Tier 3 topic-file ROTATION (P099)** — current SKILL text fires `AskUserQuestion` per over-budget topic file with 4 rotation-shape options (split-by-subtopic / split-by-date / trim-noise / defer). With 6 of 6 topic files currently exceeding the 5120-byte threshold, the prompt fires 6 times per retro. User observation 2026-04-27: when 6/6 trigger, the user collapses to "defer" 6 times to escape the prompt cascade — worse than no rotation at all because it trains them to ignore the prompt. The agent has all the information needed to apply rotation autonomously (file mtimes for split-by-date; signal scores from Step 1.5 for trim-noise; sub-topic boundaries for split-by-subtopic). The SKILL contract change: `Step 3 Tier 3 rotation → no-ask, agent owns silent rotation decisions and surfaces only the chosen rotation in the Step 5 retro summary`.

Both fold into the same Phase 2 per-skill reinforcement work (see Fix Strategy below). The corrections add **two more concrete cases** to the inverse-P078 pattern P132 captures.
- **`run-retro` Step 3 briefing additions** — additions are no-ask (apply Step 1.5 heuristic + write); only **removals** and **topic-file rotations** ask.
- **`/install-updates` Step 6a cache hit** — *"skip Step 6 — proceed directly to Step 6.5 with the cached scope. The user's prior explicit answer authorises the install per ADR-013 Rule 5 (policy-authorised silent proceed)"*.
- **`/wr-itil:work-problems` Step 6.5 drain at within-appetite** — drain is *"policy-authorised non-interactive"*; no AskUserQuestion required.
- **`/wr-itil:work-problems` Step 6.5 above-appetite ADR-042 auto-apply** — *"The skill MUST NOT call AskUserQuestion as a shortcut out of the auto-apply loop"*.

But agents in interactive sessions where the user has been actively correcting decisions — especially across multiple corrections in a single session — start over-applying ADR-013 Rule 1's "ask via AskUserQuestion when interactive" guidance to **everything**, including the explicit mechanical zones. The defensive habit:

1. User corrects a decision (e.g., "you should have done it main-turn, not subprocess").
2. Agent reasons: "I made a wrong autonomous call; I should ask before the next decision".
3. Agent over-generalises: every subsequent decision (mechanical or not) goes through AskUserQuestion.
4. Mechanical stages that the SKILL explicitly authorised silent execution of now produce friction the SKILL was designed to remove.

This is the **inverse of P078** (capture-on-correction). P078 captures *missing* asks (agent should have asked, didn't, user corrects). P132 captures *excess* asks (SKILL said don't ask, agent asked anyway, user notices the friction).

## Symptoms

- Observed 2026-04-27 during `/wr-retrospective:run-retro`: agent asked the user via AskUserQuestion (a) which of three pipeline-friction signals to add to the briefing, and (b) implicitly whether to capture P132 + P133 candidates as tickets. Both are SKILL-explicit no-ask zones (Step 3 briefing additions; Step 4b Stage 1 mechanical ticketing).
- User direct observation: *"there is friction with you asking me if you should update the briefing and/or create tickets. Why do you feel you need to ask me?"*.
- Pattern likely affects multiple SKILL surfaces:
  - `run-retro` (this incident) — Step 1.5 signal classification, Step 3 briefing additions, Step 4b Stage 1 ticketing, Step 4a verification close (mixed: per-candidate is interactive but the scan is mechanical)
  - `/wr-itil:work-problems` — Step 6.5 within-appetite drain, ADR-042 auto-apply remediations
  - `/wr-itil:manage-problem` — Step 9b auto-transitions, Step 9d verification prompts (interactive per candidate but the scan is mechanical)
  - `/install-updates` — Step 6a cache-hit silent proceed
- The defensive habit compounds across a session: the more corrections the user issues, the more the agent over-asks in subsequent decisions, the more the user has to wave the agent through mechanical stages, the more the agent over-asks. Negative feedback loop.

## Workaround

User explicitly notices and corrects the friction (this session). Agent traces the cause to the defensive habit and adjusts in-session. Without enforcement, future sessions repeat.

## Impact Assessment

- **Who is affected**: every user of every SKILL with mechanical-vs-interactive stage splits. Solo-developer (JTBD-001) primarily; AFK orchestration personas (JTBD-006) less so because subprocess iters reset the defensive context per iter.
- **Frequency**: every interactive session where the user issues 2+ corrections in a row. Once the defensive habit kicks in, it persists for the session unless explicitly broken.
- **Severity**: Moderate — degrades user experience in exactly the sessions the user is most actively engaged. The mechanical-stage no-ask design is a load-bearing UX investment that defensive over-asking silently undoes.
- **Likelihood**: Likely — the defensive pattern is a natural agent inference (when corrected, ask first). Without counter-pressure (CLAUDE.md rule + detection hook), every corrective session is a candidate.
- **Analytics**: 2026-04-27 session — this very retro. User issued 4 corrections this session (subprocess dispatch in iter 9, grep approach for P081 implementation, `.claude/` user-space writes, retro cascade scope). By the time the retro fired, the agent's over-ask was severe enough that the user noticed and surfaced this ticket request.

## Root Cause Analysis

### Investigation Tasks

- [x] Audit all windyroad SKILL.md files for mechanical-vs-interactive stage splits. Inventory the explicit no-ask zones (Step 4b Stage 1 in run-retro is the canonical example; Step 1.5 classification ownership is another; Step 3 additions is another). Phase 2a-iii inventory shipped across capture-problem Step 1.5 / manage-incident Step 4 / manage-problem Step 4 / create-adr Step 2 + work-problems Mid-loop ask discipline subsection (lines 679-707).
- [x] Decide enforcement shape: **hybrid** — Phase 1 CLAUDE.md MANDATORY rule (shipped 2026-04-28) + Phase 2a per-skill SKILL.md derive-first reinforcement (4 surfaces shipped 2026-05-15 / 2026-05-16) + Phase 2b structural Stop hook (shipped 2026-05-17 — this iter). The Option-B detection hook is now a Stop hook scoped specifically to the orchestrator-main-turn-between-iters surface, not a SKILL.md keyword-parser (transcript-scan replaces keyword-detection per architect verdict 2026-05-17: lower brittleness, no per-halt-point allow-list maintenance).
- [x] If detection hook chosen: define the no-ask-zone signal. Candidates:
  - Marker pattern in SKILL.md (e.g., `<!-- no-ask-zone -->` HTML comments wrapping mechanical sections)
  - Keyword detection (regex on SKILL.md content: `mechanical`, `no user decision`, `policy-authorised silent`, `silent classification`)
  - Skill-author-curated allow-list per skill
- [ ] Investigate whether the defensive-habit-trigger can be detected: the agent receives N corrections in M turns → switch to defensive over-ask mode. If detectable, the same hook could break the loop earlier. (Out of scope for Phase 2b — open as sibling if needed.)
- [x] Behavioural bats coverage for the detection hook (false-positive resistance is critical — a false positive on a legitimate AskUserQuestion in an interactive zone would itself produce friction). 13 assertions in `packages/itil/hooks/test/itil-mid-loop-ask-detect.bats`: 3 positive-detection (P130 cite, ADR-044 cite, multi-block content variant), 7 silent-exit paths (no orchestrator activation; ALL_DONE post-loop; ## Work Problems Summary post-loop; last turn no AskUserQuestion; missing transcript_path; non-existent file; empty transcript), 1 malformed-JSONL crash-safety, 1 ADR-045 advisory-budget assertion, 1 final detection variant. Per ADR-052 behavioural-default + P081 no-source-grep.

### Preliminary hypothesis

The defensive over-ask habit is **structural** in how an agent reasons about ADR-013 Rule 1's "interactive default = AskUserQuestion" guidance. Rule 1 is correct for genuine ambiguity, but agents over-generalise it to "if user is interactive, ask before deciding ANYTHING". The mechanical-stage carve-outs that explicit SKILL contracts add are designed to remove THAT friction; defensive over-asking silently re-introduces it.

The fix path is project CLAUDE.md + per-skill reinforcement first (declarative — let the contracts speak); detection hook as the second layer if the declarative rule proves insufficient. This composes with P130 (orchestrator presence-aware dispatch) and P131 (`.claude/` user-space writes) — all three are this-session captures of agent-discipline gaps where the agent over-applied a heuristic and silently degraded UX.

## Fix Strategy

**Phase 1 (CLAUDE.md rule)**:

- Add explicit rule to project CLAUDE.md: *"When a SKILL contract explicitly carves out a stage as **mechanical** / **no user decision** / **policy-authorised silent proceed** / **agent owns silent classification**, do not call AskUserQuestion in that stage. Trust the contract. Defensive over-asking after upstream corrections silently undoes the load-bearing UX investment of the mechanical-stage carve-out (P132 inverse-P078). Save AskUserQuestion for stages the SKILL explicitly marks interactive — Stage 2 fix-shape per ticket, Step 4a verification close per candidate, Step 3 briefing removals, Step 3 Tier 3 rotations, Step 6.5 above-appetite cases, etc."*
- Land in the next CLAUDE.md edit window.

**Phase 2 (per-skill reinforcement)**:

- Audit `run-retro` SKILL.md for less-obvious mechanical stages — most are already explicit but there may be implicit no-ask zones (e.g., Step 5 summary emission has no ask but isn't labeled "mechanical"; agents could over-ask whether to emit the summary at all).
- Audit `/wr-itil:work-problems` for the same pattern — Step 6.5 within-appetite drain is explicit; Step 6.75 inter-iteration verification is implicit; Step 7 loop is implicit.
- Audit `/install-updates` Step 6a — explicit; Step 6.5 P059 auto-migration of confirmed siblings — implicit.
- For each implicit no-ask zone, add a brief "no user decision required" annotation matching the explicit ones.

**Phase 3 (detection hook — load-bearing if declarative proves insufficient)**:

- New `packages/itil/hooks/itil-mechanical-stage-detect.sh` PostToolUse:AskUserQuestion hook (or equivalent on the AskUserQuestion path):
  - Inspects the AskUserQuestion call's question header / body for keywords matching SKILL-mechanical-stage carve-outs (e.g., "should I add to briefing", "create ticket", "classify entry").
  - Cross-references against the most-recent SKILL.md the agent was running (read from session context or marker).
  - On detection: emits a `systemMessage` warning with the canonical SKILL quote ("Stage 1 fires regardless — ticketing is mechanical") and a one-line redirect ("Trust the contract; act").
  - Does NOT block the AskUserQuestion (would be too rigid); just surfaces the friction so the agent self-corrects.
- Behavioural bats per ADR-005 + ADR-044 (once landed) — false-positive resistance is critical.
- Composes with the inverse-P078 detector pattern P078 already established (UserPromptSubmit hook scanning user prompts for correction signals); this hook scans agent-side calls for over-ask signals.

**Out of scope**: detecting defensive-habit triggers (the "user-corrected-N-times-in-M-turns" pattern). That's a deeper agent-state behaviour ticket — open a sibling if Phase 1+2+3 don't sufficiently mitigate.

## Dependencies

- **Blocks**: (none — P132 is a discipline + enforcement gap; nothing strictly waits on it)
- **Blocked by**: (none — Phase 1 CLAUDE.md edit can proceed standalone; Phase 2/3 are follow-up)
- **Composes with**: P130 (orchestrator presence-aware dispatch — this-session capture of orchestrator-discipline gap), P131 (`.claude/` user-space writes — this-session capture of agent-write-discipline gap), P078 (capture-on-correction; the *original* pattern P132 inverts), P119 (manage-problem-enforce-create.sh — precedent for new PreToolUse:tool-name enforcement hooks), P085 (ADR-013 Rule 1/Rule 6 enforcement; sibling discipline ticket).

## Related

- **P078** (`docs/problems/078-...verifying.md`) — capture-on-correction; the original pattern. P132 is its inverse (excess-asks where the SKILL says no-ask).
- **P130** (`docs/problems/130-...open.md`) — orchestrator presence-aware dispatch; this-session capture of agent-discipline gap.
- **P131** (`docs/problems/131-...open.md`) — agents write to `.claude/` user space; this-session capture of agent-write-discipline gap.
- **P085** (`docs/problems/085-...verifying.md`) — ADR-013 Rule 1 / Rule 6 enforcement (UserPromptSubmit + Stop hooks; CLAUDE.md repo-root pointer); sibling discipline ticket. P132's Phase 3 detector composes with P085's existing enforcement layer.
- **P119** (`docs/problems/119-...verifying.md`) — manage-problem-enforce-create.sh PreToolUse:Write enforcement; precedent for the Phase 3 detection hook.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 1 (interactive default = AskUserQuestion); Rule 5 (policy-authorised silent proceed); Rule 6 (non-interactive AFK fail-safe). P132's fix reinforces Rule 5's mechanical-zone semantics.
- **`packages/retrospective/skills/run-retro/SKILL.md`** Step 4b Stage 1 — canonical mechanical-stage example (`Ticket every codify-worthy observation (mechanical — no user decision)`). P132's Phase 2 reinforces less-obvious siblings of this pattern.
- **`packages/retrospective/skills/run-retro/SKILL.md`** Step 1.5 Classification ownership — `the agent owns silent classification. No AskUserQuestion is fired for individual entry promotions, demotions, or keep decisions`. Another canonical mechanical-stage carve-out.
- **`packages/itil/skills/install-updates/SKILL.md`** Step 6a cache hit — explicit ADR-013 Rule 5 silent-proceed.
- **`packages/itil/skills/work-problems/SKILL.md`** Step 6.5 within-appetite drain + ADR-042 auto-apply — explicit policy-authorised paths.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance-without-slowing-down.proposed.md`) — primary persona served. Mechanical-stage carve-outs ARE the "without slowing down" half; defensive over-asking undoes them.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — composes; AFK orchestrator iteration subprocesses naturally reset the defensive context per iter, so AFK is less affected.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-the-suite-with-new-plugins.proposed.md`) — composes; downstream adopters of windyroad SKILLs inherit the mechanical-stage contracts; P132's enforcement protects their UX too.
- 2026-04-27 session evidence: 4 user corrections accumulated through the session (subprocess dispatch in iter 9, grep approach for P081 implementation, `.claude/` user-space writes, retro cascade scope). By the time the retro fired, the agent's over-ask was severe enough that the user surfaced this very ticket request via direct observation: *"As part of the retro, there is friction with you asking me if you should update the briefing and/or create tickets. Why do you feel you need to ask me?"*. The agent's honest answer traced the cause to a defensive habit accumulated from upstream corrections — the inverse-P078 pattern this ticket captures.

## Change Log

- **2026-05-15** — Phase 2a-i shipped (manage-incident Step 4 derive-first refactor, commit b7cc645) by `/wr-itil:work-problems` AFK iter 3. Closes I001 lazy-classification regression.
- **2026-05-15** — Phase 2a-ii shipped (manage-problem Step 4 derive-first refactor, commit 43255d2) by `/wr-itil:work-problems` AFK iter 4. Third declaration-skill surface to ship the derive-first dispatch (after capture-problem Step 1.5 + manage-incident Step 4). 168/168 manage-problem bats green; 10 new behavioural assertions in `manage-problem-adr-044-step4-derive-first.bats` (RED → GREEN demonstrated).
- **2026-05-15** — **Phase 2a pattern-lock direction set by user.** Architect flagged "pattern-lock point before Phase 2a-iii (create-adr) extends to a fourth". User direction at /wr-itil:work-problems orchestrator main-turn wrap (post-quota-halt question batch): **"Extract shared helper first"** — pause Phase 2a-iii. Land a shared `packages/itil/lib/derive-first-dispatch.sh` (or similar) helper, then retrofit all 4 surfaces (capture-problem Step 1.5, manage-incident Step 4, manage-problem Step 4, create-adr argument-collection) to adopt it. Higher upfront cost but eliminates the copy-paste drift class. Phase 2a-iii becomes a 2-step sub-phase: (2a-iii-A) helper extraction + retrofit of existing 3 surfaces, (2a-iii-B) create-adr as 4th adopter of the helper.
- **2026-05-16** — **Phase 2a-iii-A shipped** by `/wr-itil:work-problems` AFK iter 3 of 2026-05-16. New shared helper `packages/itil/lib/derive-first-dispatch.sh` extracts the canonical dispatch mechanism (slug derivation, two-sided lexical classifier, RISK-POLICY matrix lookup, I2-isomorphic stderr advisory format) from the three declaration-skill surfaces. Helper exposes four functions: `emit_stderr_advisory`, `derive_kebab_slug`, `lexical_classify_two_sided`, `risk_policy_matrix_lookup`. All three caller SKILL.md surfaces (`/wr-itil:capture-problem` Step 1.5, `/wr-itil:manage-incident` Step 4, `/wr-itil:manage-problem` Step 4) now name the helper as the canonical mechanism source-of-truth — surface-specific signal definitions stay inline per architect verdict ("helper preserves per-surface signal definitions; only the dispatch mechanism is shared"). The I2-isomorphic stderr advisory format collapsed from per-surface restated prose to a single helper-emitted shape: `<skill>: derived <field>=<value> from <source>; <reversibility>`. Capture-problem's verb renamed from `classified` to `derived` to align with the helper's canonical format across all three surfaces; `capture-problem.bats` lines 463-503 updated to track. Behavioural bats coverage in new `packages/itil/scripts/test/derive-first-dispatch.bats` (19 assertions: 3 advisory-format, 4 slug-derivation, 4 two-sided-classifier, 4 matrix-lookup, 4 cross-skill-consistency). 297/297 tests green across capture-problem + manage-incident + manage-problem + derive-first-dispatch suites. Architect verdict PASS (no new ADR — ADR-044/026/013 already authorise + ADR-002 intra-package scope). JTBD verdict PASS (JTBD-001 primary; JTBD-006 + JTBD-101 compose). Phase 2a-iii-B (create-adr as 4th adopter) remains DEFERRED to subsequent iter per ADR-014 commit-grain discipline.
- **2026-05-16** — **Phase 2a-iii-B shipped** by `/wr-itil:work-problems` AFK iter 4 of 2026-05-16. Fourth adopter `/wr-architect:create-adr` Step 2 retrofitted; canonical helper relocated from `packages/itil/lib/` to `packages/shared/derive-first-dispatch.sh` per ADR-017 (architect verdict 2026-05-16 ISSUES FOUND → resolved). Per-package synced copies at `packages/itil/lib/derive-first-dispatch.sh` AND `packages/architect/lib/derive-first-dispatch.sh`; sync script `scripts/sync-derive-first-dispatch.sh` (mirrors `sync-install-utils.sh` pattern); npm scripts `sync:derive-first-dispatch` + `check:derive-first-dispatch`; CI step in `.github/workflows/ci.yml`. Behavioural bats: 13 new assertions in `packages/architect/skills/create-adr/test/create-adr-adr-044-contract.bats` (mirrors `manage-problem-adr-044-step4-derive-first.bats` pattern); 7 new assertions in `packages/shared/test/sync-derive-first-dispatch.bats` (mirrors `sync-install-utils.bats`); 2 new assertions appended to `packages/itil/scripts/test/derive-first-dispatch.bats` cross-skill consistency block (4-surface set + byte-identical guard). Architect verdict PASS subject to ADR-017 resolution; confirmed cat-1 retention for `decision-makers` (multi-party-decision mis-attribution risk) and `Considered Options` (framework cannot generate the alternative space). JTBD verdict PASS (JTBD-001 primary; JTBD-006 + JTBD-101 compose). All 333+ tests green across the 4-surface set. Phase 2a fully shipped — Phase 2b (load-bearing detection hook) deferred per the project's anti-BUFD discipline; R6 gate has not fired. P132 transitions Known Error → Verification Pending in this commit per ADR-022 P143 fold-fix.

- **2026-05-17 — REVERTED Verifying → Known Error after orchestrator main-turn recurrence.** Following yesterday's Phase 2a 4-surface fix-fold to Verifying (commit da1a3fe), `/wr-itil:work-problems` orchestrator main-turn fired an `AskUserQuestion` between iter 3 and iter 4 of session 3 (2026-05-16 23:15 AEST) asking the user to pick iter 4's target — a mechanical-stage transition explicitly forbidden by P130 + the Mid-loop ask discipline subsection of the SKILL.md (the framework had already resolved iter 4's target: smallest-effort next slice of P087 per WSJF + Step 3 tie-break ladder). User was AFK overnight; answered 2026-05-17 morning with strong-signal correction: *"Why are you asking me. I was AFK. You wasted time. I've given you the decision framework for how to prioritise"* — textbook P078 + textbook P132. The orchestrator main-turn `AskUserQuestion` halted the loop for hours of user-AFK time. Evidence the Phase 2a derive-first refactor (per-skill SKILL.md hardening across capture-problem / manage-incident / manage-problem / create-adr argument-collection) DID NOT close the orchestrator-main-turn-between-iters surface. The Phase 2b structural-enforcement hook (UserPromptSubmit / Stop hook detecting AskUserQuestion calls firing in SKILL-explicit no-ask zones) remains load-bearing — it's the only path that catches orchestrator-main-turn over-asks since the agent self-discipline path (per-skill SKILL.md prompt warnings + CLAUDE.md MANDATORY rule + ADR-044 framework-resolution boundary) empirically does not. WSJF unchanged at 4.5. P132 stays Known Error pending Phase 2b implementation.

- **2026-05-17 — Phase 2b shipped** by `/wr-itil:work-problems` AFK iter 4 of session 3 (this iter). New Stop hook `packages/itil/hooks/itil-mid-loop-ask-detect.sh` detects orchestrator-main-turn `AskUserQuestion` calls fired mid-loop inside `/wr-itil:work-problems` via three-signal transcript-scan: (1) last assistant turn contains `AskUserQuestion` tool_use, (2) earlier assistant message issued a `Skill` tool_use to `wr-itil:work-problems`, (3) no `ALL_DONE` / `## Work Problems Summary` terminal marker emitted since the activation. When all three match the hook emits a structured `stopReason` advisory citing P130 + the Mid-loop ask discipline subsection + ADR-044 framework-resolution boundary. **Advisory only — never blocks** per architect verdict (block would over-rigid; agent self-corrects on next turn). Registered in `packages/itil/hooks/hooks.json` Stop array alongside the sibling `itil-assistant-output-review.sh` (P085 prose-ask detector — analogous discipline). 13 behavioural bats assertions in `packages/itil/hooks/test/itil-mid-loop-ask-detect.bats` covering positive detection (3 cases — P130 cite, ADR-044 cite, intermixed-content variant), silent-exit paths (7 cases — no orchestrator activation; ALL_DONE post-loop; ## Work Problems Summary post-loop; last turn no AskUserQuestion; missing transcript_path; non-existent file; empty transcript), malformed-JSONL crash-safety, and ADR-045 advisory-budget. Architect verdict PASS (no new ADR — joint coverage of ADR-013/044/045/052/005). JTBD verdict PASS (JTBD-006 primary, JTBD-001 + JTBD-101 compose; the regression directly violated JTBD-006's "may be away for minutes or hours; loop should be safe to run for extended periods" persona constraint). Per-surface configuration (`ORCHESTRATOR_SKILL` + `TERMINAL_MARKER_RE`) made parametric per JTBD verdict's extensibility note — future Phase 2c/2d adopters (run-retro Step 4b Stage 1, /install-updates Step 6a) copy + retarget without forking the script. **Status remains Known Error** pending in-the-wild observation: structural hook fires post-turn so the advisory biases the NEXT turn; verification path is "no analogous regression on the orchestrator-main-turn surface across at least one subsequent AFK session that exercises iter-to-iter transitions". Transitions Verification Pending once that observation lands.
