# Problem 160: Ship quota-pacing surface to prevent weekly-quota exhaustion — advisory or blocking nudge when burn rate exceeds sustainable pace, so users retain Claude tokens for non-Claude-Code surfaces (chat, cowork) for the full week

**Status**: Open
**Reported**: 2026-05-03
**Priority**: 10 (High) — Impact: Minor (2) x Likelihood: Almost certain (5)
**Effort**: XL — new plugin or sibling surface; ADR required for policy semantics (advisory vs blocking, scope boundary against existing statusline read-surface, AFK-orchestrator interaction); cross-cutting with hooks (PreToolUse cadence gate?), statusline (already reads quota state — see `~/.claude/statusline-command.sh`), and a quota-policy schema analogous to `RISK-POLICY.md`. Multi-day, cross-package work.

**WSJF**: (10 × 1.0) / 8 = **1.25**
**Type**: technical

> Surfaced 2026-05-03 by user direction citing live status-line evidence: `5h: 23% ahead (resets 45m)` and `7d: 36% behind (resets 5d 17h)` — burning weekly quota at ~1.5x sustainable pace. Confirmed by James Nowland (cross-user) reporting same pain class: "blown through my AI with code" leaving no tokens for important text-based emails. Quota exhaustion is a cross-surface failure (Claude Code consumes; chat + cowork starve) that the existing statusline diagnostic surface measures but does not regulate.

## Description

Claude's weekly token quota is shared across **all** Claude surfaces the user has authenticated to from a single account — Claude Code, claude.ai chat, Anthropic Cowork, and any custom API-backed tools. The Windy Road plugin suite includes governance surfaces that intentionally drive up agent verbosity (architect review, JTBD review, risk-scorer pipeline, retrospective passes, hook injection on every prompt — see ADR-038 progressive-disclosure context budget) which is correct for **per-session** quality but accumulates **per-week** quota burn that the user cannot see ahead-of-time.

The status-line surface (already wired via `statusLine.command` in `~/.claude/settings.json` → `~/.claude/statusline-command.sh`) **measures** the burn rate against the 5-hour window and the 7-day window — the screenshot evidence shows the format `5h: <bar> <pct> ahead/behind (resets <N>) | 7d: <bar> <pct> ahead/behind (resets <N>)`. This is a **diagnostic** surface — it tells the user what already happened. It does **not** regulate, advise, or constrain future tool-call cadence to keep the weekly burn within the sustainable pace.

The gap: a **prescriptive** layer that converts the existing diagnostic data into governance — analogous to how `RISK-POLICY.md` converts pipeline impact/likelihood into commit gates, this surface would convert quota burn rate into operational guidance ("you're burning at 1.5x sustainable; defer the AFK loop / switch to a smaller model / batch the work tomorrow"). Critically, the surface must be **cross-tool aware** — the regulation must reflect that the user wants to preserve quota for chat + cowork, not just for the next Claude Code session.

This is a **product capability gap**, not a bug. There is no existing plugin in the `@windyroad/*` suite addressing it, and no upstream Claude Code feature (per current release notes) provides it. It is captured here as a problem ticket per the project's pattern (problems = capability gaps + bugs together; see siblings P155 / P156 / P157 for the "ship X" backlog framing).

**Why this matters now** (load-bearing on existing JTBDs):

- **JTBD-001 (enforce governance without slowing down)** — running out of tokens mid-week is the maximum form of "slowed down": the agent stops working at all. Governance gates that drive quota burn (architect, JTBD, risk-scorer running on every edit + every commit) MUST be tunable against weekly cadence, otherwise the governance itself starves the user out of the workflow it is supposed to protect.
- **JTBD-006 (progress the backlog while AFK)** — AFK orchestrators (`/wr-itil:work-problems`, `/loop`) are the heaviest single class of quota consumer. An overnight AFK loop can consume the user's weekly quota in one run if uncapped. Without a pacing surface, the user can't safely set an AFK loop and walk away — the loop might land them at zero tokens for the rest of the week.
- **Cross-user evidence** — James Nowland (different solo-developer persona instance) reports the same pain class independently. This is not a single-user idiosyncrasy.

## Symptoms

- Status-line shows `7d: <pct>% behind` reaching double-digits early in the week with no surfacing of the implication (will run out before reset).
- Mid-week token exhaustion forcing the user to abandon non-Claude-Code surfaces (chat, cowork) for which they had not budgeted the burn.
- AFK orchestrator runs (e.g. `/wr-itil:work-problems` 16-hour overnight loops) silently consume large fractions of weekly quota with no in-loop pacing check.
- User cannot ask "if I run this loop overnight, will I have tokens left for chat tomorrow?" — no policy surface answers this question.
- Cross-user pain (James Nowland's report) shows this is a class-of-user problem, not a one-off.

## Workaround

Current state — manual self-pacing:

1. User glances at the status-line periodically and self-throttles by stopping high-cost work (AFK loops, expensive reviews) when the 7-day bar shows behind.
2. User chooses model manually (Opus → Sonnet → Haiku) to trade quality for tokens when burn rate is high.
3. User defers non-essential governance work (retrospectives, audits) to early in the week when quota headroom is high.
4. User accepts running out of tokens as a recoverable failure mode (wait until reset).

All four sub-workarounds depend on the user remembering to check and being present to act. They fail completely during AFK loops (no human in the loop to see the status-line; no `/loop` mechanism to halt-on-budget). They also fail on shared accounts where multiple humans + multiple agents draw from the same quota pool.

## Impact Assessment

- **Who is affected**: Solo-developer (primary — manages own quota across CC + chat + cowork); AFK orchestrator class (primary failure mode — long-running unattended loops); plugin-user (indirect — adopters of `@windyroad/*` plugins inherit governance surfaces that drive quota burn without a counter-balancing pacing surface, so adopters experience the same exhaustion class without being able to tune it independently).
- **Frequency**: Continuous — present every week; failure mode (mid-week exhaustion) appears multiple weeks per month based on observed status-line data.
- **Severity**: Minor (per RISK-POLICY.md impact 2 — "dev tooling affected; published packages and installed plugins unaffected") — this is a missing-feature framing; nothing in the shipped plugin suite is broken. Re-rate to Significant (4) if the gap blocks an adopter from using `@windyroad/*` plugins because their governance surfaces consume too much quota.
- **Likelihood**: Almost certain (per RISK-POLICY.md likelihood 5 — "Known gap, no controls in place") — explicitly observed, no plugin or upstream feature regulates this today.
- **Analytics**: Live status-line snapshot 2026-05-03 — `5h: 23% ahead (resets 45m)`, `7d: 36% behind (resets 5d 17h)`. Cross-user corroboration: James Nowland message attached to ticket creation — independently observed, same pain class.

## Root Cause Analysis

### Preliminary Hypothesis (fix-shape sketch — design questions deferred to architect review)

The fix is a new pacing surface, not a tweak to an existing one. Open design questions the architect review must resolve:

**Q1 — Plugin home**: new dedicated plugin (`@windyroad/quota-pacing`?) vs sibling skill / hook in an existing plugin (`@windyroad/itil` since it owns the policy-pattern; `@windyroad/risk-scorer` since it owns the gate-pattern; or nowhere — surface as a global hook bundled with `accessibility-agents`-style global config). New plugin is the cleanest separation but adds release surface; sibling skill is cheaper but couples concerns.

**Q2 — Read surface**: what does the pacing layer read for burn-rate state? The existing statusline reads quota state (it must — it renders the bars). Either:
- (a) The pacing surface re-implements the read (duplicates the statusline's source-of-truth lookup).
- (b) The pacing surface reads a shared cache that the statusline writes (introduces a coupling).
- (c) The statusline becomes the single source of truth and the pacing surface reads its rendered output (parses the bar text — brittle).

**Q3 — Enforcement mode**: advisory (warn + continue) vs blocking (gate + require ack) vs adaptive (auto-throttle: switch model, defer expensive ops). Likely tiered like RISK-POLICY.md appetite bands:
- Within sustainable pace (≤ 100% of weekly): silent.
- Approaching limit (100–115%): advisory message in agent output.
- Above limit (115–130%): blocking gate analogous to risk-scorer commit-gate; requires explicit user ack to proceed with high-cost ops (AFK loops, expensive reviews).
- Critical (> 130% with > 2 days until reset): hard halt — refuse to start new AFK loops; advise switch to smaller model.

**Q4 — Policy schema**: a `QUOTA-POLICY.md` analogous to `RISK-POLICY.md`? Per-user customisable thresholds (some users only ever use Claude Code; others split across 3 surfaces and need stricter pacing)? Per-org / per-account schema for shared accounts?

**Q5 — AFK-orchestrator integration**: how does `/wr-itil:work-problems` Step 6.5 (release cadence) interact with quota pacing? Likely a sibling Step 6.6 (or a fold into 6.5) that checks the pacing surface before starting another iteration. If pacing says "above appetite", halt the loop and emit a halt-with-report per ADR-013 Rule 6.

**Q6 — Cross-tool awareness**: does the pacing surface read state for chat + cowork burn, or only Claude Code? If only CC, the user must self-budget the chat+cowork share. If cross-tool, the surface needs an account-wide quota reader (likely an Anthropic API call against the user's account — non-trivial auth surface).

**Q7 — Upstream coordination**: should this be reported upstream to Claude Code as a feature request (per `/wr-itil:report-upstream`) before building? The existing statusline is already an upstream-supplied surface; quota pacing might be on the Anthropic roadmap. External-root-cause detection in Step 7 of this skill should fire the upstream-report prompt when this ticket transitions to Known Error.

### Investigation Tasks

- [ ] Architect review — resolve Q1 (plugin home), Q2 (read surface), Q3 (enforcement mode), Q4 (policy schema). Decide whether a new ADR is warranted (likely yes — policy semantics + cross-plugin coupling).
- [ ] JTBD review — confirm impact on JTBD-001 + JTBD-006 + plugin-user persona JTBD-302 (trust README describes installed behaviour — installed plugins must not silently exhaust quota).
- [ ] Investigate `~/.claude/statusline-command.sh` to understand the quota-state read surface. Document the API / file / IPC the statusline uses; this is the candidate read source for Q2 option (b).
- [ ] Investigate Anthropic upstream surface — is there an `Anthropic-Account-Quota` HTTP header on responses? A `claude usage` CLI command? An account-API endpoint? This drives Q6 + Q7.
- [ ] `/wr-itil:report-upstream` to Claude Code with feature request shape, per Q7. Defer until architect review confirms the gap is downstream-buildable rather than a missing upstream surface.
- [ ] Implement the agreed design — either as a new plugin (with full release surface: `package.json`, hooks, skills, ADRs, bats, install-updates wiring) or as a sibling addition to `@windyroad/itil` / `@windyroad/risk-scorer`.
- [ ] Wire AFK orchestrator integration (Q5) — `/wr-itil:work-problems` Step 6.5 / 6.6 quota-pacing check.
- [ ] Behavioural bats per ADR-026 grounding + P081 behavioural-test discipline — exercise the pacing surface against a synthetic burn-rate fixture; assert advisory / blocking / hard-halt thresholds fire correctly.
- [ ] Document in BRIEFING.md as a session-wide unifying constraint (sibling to ADR-038 progressive disclosure for context budget — this is progressive disclosure for **token budget**).

## Dependencies

- **Blocks**: (none directly — but every governance surface that drives token burn (architect, JTBD, risk-scorer, retrospective) is **regulated by** this surface once shipped, so all of those would have a cross-reference once the policy schema lands)
- **Blocked by**: (none — the gap is independently buildable; statusline surface already exists as a read source)
- **Composes with**: P027 (closed — manage-problem work-flow expensive; that solution reduced per-invocation cost but didn't introduce weekly-cadence regulation); P091 (open — session-wide context budget from plugin hook stack; sibling concern at the per-session axis vs P160's per-week axis); P099 (verifying — BRIEFING.md unbounded-grow; sibling progressive-disclosure pattern); ADR-038 (progressive-disclosure context budget — P160 is the token-budget analogue).

## Related

- `~/.claude/settings.json` → `statusLine.command` → `~/.claude/statusline-command.sh` — existing diagnostic read surface.
- Status-line evidence (2026-05-03): `5h: 23% ahead (resets 45m) | 7d: 36% behind (resets 5d 17h)`.
- Cross-user corroboration: James Nowland message attached to ticket creation (independently observed pain class).
- `RISK-POLICY.md` — pattern template for the proposed `QUOTA-POLICY.md` schema (Q4).
- ADR-038 (progressive-disclosure context budget) — the per-session analogue of the per-week regulation P160 proposes.
- ADR-013 (six-rule AskUserQuestion + AFK-fail-safe contract) — Rule 6 (AFK fail-safe) is the canonical halt-with-report pattern the AFK-orchestrator integration (Q5) would reuse.
- ADR-042 (auto-apply scorer remediations) — pattern template for the adaptive-enforcement mode in Q3 (auto-throttle = scorer-style auto-apply).
- P155 / P156 / P157 — sibling "ship X" backlog framing for new plugin capability gaps.
- JTBD-001 (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — load-bearing dependency.
- JTBD-006 (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — load-bearing dependency.
- JTBD-302 (`docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md`) — adopter-side concern (installed governance surfaces must not silently exhaust user quota).
