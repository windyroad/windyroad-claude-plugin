# Problem 038: No voice-and-tone gate on external communications

**Status**: Verification Pending
**Reported**: 2026-04-17
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: XL — multi-surface PreToolUse hook (gh, npm, RapidAPI, marketplace) + pre-flight rewrite skill + voice profile integration + ADR for new enforcement surface + regression fixtures; cross-plugin with voice-tone. Marginal at fold-fix time (2026-05-14) was L — canonical hook + composite-marker scheme + sync script already shipped under P064 / ADR-028 amended 2026-04-21; P038 marginal work was per-package wiring (.conf + agent + mark hook + skill + 13 bats).
**WSJF**: 0 — Verification Pending excluded from dev-work ranking per ADR-022 (was 1.5 as Open).
**Type**: technical

## Direction decision (2026-04-20, user — AFK loop stop-condition #2)

**Enforcement surface**: **Both — hook + skill**. PreToolUse hook intercepts `gh issue comment`, `gh pr create`, `gh pr comment`, `npm publish` (with README diff), and RapidAPI/marketplace update calls, firing the gate deterministically. A companion skill provides the rewrite logic (strip AI-tell patterns, apply the voice profile, run age/context check on target issues). The hook invokes the skill before allowing the tool call.

Implication: new ADR needed (extending ADR-009 gate-marker lifecycle and ADR-015 on-demand assessment). Scope: (1) external-comms surface inventory, (2) hook design with gate-marker pattern, (3) rewrite skill with voice profile integration, (4) regression fixtures from historical "FFS" outputs, (5) per-package cross-plugin coordination with `@windyroad/voice-tone`.

## Description

The `wr-voice-tone` plugin and `docs/VOICE-AND-TONE.md` govern voice-and-tone only for in-repo text (READMEs, docs, commit messages). There is no gate on text produced for **external** surfaces: GitHub issue comments, PR descriptions, npm README updates, RapidAPI listings, Shopify/marketplace product pages. Claude's output on these surfaces defaults to generic "AI voice" — em-dashes, hedging phrases, overly-polite closers, and context-blind suggestions like "let's keep this ticket open" on 2-year-old issues.

Observed pattern over the 30-day window covered by `/Users/tomhoward/.claude/usage-data/report.html` (1,464 messages across 86 sessions): voice-and-tone checks were skipped before every external-comms tool call, triggering repeated "FFS" corrections from the user. The insights report identifies this as one of three top friction categories ("Missing voice/risk checks on external output") and recommends a mandatory pre-flight voice/tone check on every external surface.

The gate should:
- Intercept `gh issue comment`, `gh pr create`, `gh pr comment`, `npm publish` (with README diff), RapidAPI/Shopify update calls
- Strip AI-tell patterns (em-dashes, "it seems", "I'd suggest", excessive hedging)
- Rewrite to match the voice profile in `docs/VOICE-AND-TONE.md`
- Run an age/context check on target issues before comments ("keep open" on a 2024 ticket is almost always wrong)
- Block the tool call until rewrite is approved

## Symptoms

- GitHub comments posted with em-dashes, hedging, and generic-AI-voice phrases
- "Keep ticket open" or "happy to help further" suggested on stale (>1yr) issues
- README updates published without tone review
- User frustration ("FFS") surfaces repeatedly as a late-stage correction rather than a pre-flight gate
- Voice-and-tone enforcement is inconsistent — present for in-repo docs, absent for outbound surfaces

## Workaround

The user manually reviews every external-comms output before publishing and rewrites as needed. This is the "manually police AI output" pain point explicitly called out in the solo-developer persona.

## Impact Assessment

- **Who is affected**: Solo-developer persona when Claude posts to external surfaces on their behalf (JTBD-001 — "Enforce Governance Without Slowing Down")
- **Frequency**: Every external-comms tool call; observed dozens of times over 30 days per insights report
- **Severity**: High for the persona — external surfaces are the public face of the user's work; AI-tell patterns damage credibility and compound the "AI slop" concern
- **Analytics**: `/Users/tomhoward/.claude/usage-data/report.html` — friction category "Missing voice/risk checks on external output" is one of three top friction types

## Root Cause Analysis

### Investigation Tasks

- [ ] Inventory the external-comms surfaces Claude uses (`gh` subcommands, `npm` publish paths, RapidAPI CLI/API, any Shopify/marketplace pushes)
- [ ] Decide implementation surface: PreToolUse hook (runs the gate deterministically) vs. skill (author discipline) vs. both
- [ ] Design the voice profile format — reuse `docs/VOICE-AND-TONE.md` or create a tighter rewrite-rules file
- [ ] Build a regression fixture set from past "FFS" outputs captured in session logs
- [ ] Create an ADR if the chosen mechanism is a new hook pattern (per wr-architect advisory — ADR-009 gate-marker lifecycle and ADR-015 on-demand assessment both inform this)
- [ ] Create a reproduction test (feed a known-AI-voice draft, assert the gate rewrites or blocks it)
- [ ] Create INVEST story for permanent fix

## Confirming evidence — 2026-04-25 #52831 retrospective

Concrete instance of the gap: agent posted a substantive comment to anthropics/claude-code#52831 via `gh issue comment` with no PreToolUse gate firing. User asked retrospectively whether voice-and-tone review had run; it had not. Retrospective `wr-voice-tone:agent` invocation returned `FAIL — guide gap` because `docs/VOICE-AND-TONE.md` does not exist in this monorepo (the publishing repo doesn't dogfood the guide it ships — the "advisory-only when absent" branch from line 12-13 of this ticket fired in practice). Comment was defensible against generic norms, but every control intended to govern outbound public copy was bypassed. Confirms: (a) the latch from this ticket is not yet in place for `gh issue comment`; (b) the dogfooding gap (no `docs/VOICE-AND-TONE.md` here) makes this the first project that will hit the auto-create-on-missing pathway when the gate lands; (c) the existing review-gate auto-create-on-missing pattern (which works for file-edit gates per `voice-tone-enforce-edit.sh` line 57-60) should be reused for the outbound-comm gate too — same UX contract.

## Fix Released

- **Released**: 2026-05-14 — `@windyroad/voice-tone` minor + `@windyroad/risk-scorer` patch (fold-fix Open → Verification Pending per ADR-022). Changeset `.changeset/p038-voice-tone-external-comms-gate.md`.
- **Summary**: Voice-tone half of ADR-028 amended external-comms gate ships alongside the existing risk evaluator (P064). When both plugins installed, both gates fire on the same outbound prose call; each denies until its own evaluator emits PASS (per-evaluator markers `external-comms-voice-tone-reviewed-<KEY>` + `external-comms-risk-reviewed-<KEY>`). Composition at firing level — no shared composite marker, no install-detection at runtime. ADR-028 amendment 2026-05-14 ratifies the simplified per-evaluator scheme and supersedes the original combined-marker design (architect + JTBD PASS confirmed 2026-05-14).
- **Architecture**: Per-package config file `external-comms-evaluator.conf` (NOT synced; package-specific by design) declares evaluator id + subagent type + verdict prefix + assess-skill path + policy file + leak-prefilter flag. The byte-identical canonical `packages/shared/hooks/external-comms-gate.sh` sources this .conf at runtime — single canonical executable, per-package data.
- **Surface coverage** (mirrors P064): `gh issue create|comment|edit`, `gh pr create|comment|edit`, `gh api .../security-advisories`, `gh api .../comments`, `npm publish`, `PreToolUse:Write|Edit on .changeset/*.md` (P073 author-time gate).
- **Voice-tone agent**: new `packages/voice-tone/agents/external-comms.md` reviews drafts against `docs/VOICE-AND-TONE.md`. Emits structured `EXTERNAL_COMMS_VOICE_TONE_VERDICT: PASS|FAIL` + `EXTERNAL_COMMS_VOICE_TONE_KEY: <sha256>` consumed by new PostToolUse:Agent hook `packages/voice-tone/hooks/external-comms-mark-reviewed.sh`. Voice-tone evaluator skips leak pre-filter (`EXTERNAL_COMMS_LEAK_PREFILTER=no`) — leak detection is the risk evaluator's concern.
- **On-demand skill**: new `/wr-voice-tone:assess-external-comms` per ADR-015 (peer of `/wr-risk-scorer:assess-external-comms`).
- **Advisory-only fallback**: `docs/VOICE-AND-TONE.md` absent → voice-tone gate is advisory-only on each surface (permits with systemMessage). Same graceful-adoption arc as risk evaluator's RISK-POLICY.md fallback (ADR-008 / ADR-025).
- **Bats coverage**: 13 new in `packages/voice-tone/hooks/test/external-comms-gate.bats` (surface match / clean draft deny+delegate / leak-prefilter skip / BYPASS / per-evaluator marker permit / risk marker does NOT satisfy voice-tone / policy-absent advisory / changeset author-time / non-changeset path bypass / gh api security-advisories / npm publish / skill reference / legacy combined marker rejected); risk-scorer bats extended from 12 to 13 (legacy combined marker rejection added); canonical bats extended from 11 to 12 (.conf-sourcing + per-evaluator marker filename); sync bats extended from 7 to 9 (voice-tone copy + per-package .conf). All 35 new/updated assertions green at commit time.
- **ADR cross-updates landed in same commit**: ADR-028 `## Amendments` section 2026-05-14 (per-evaluator marker scheme; drops `age_bucket` + `evaluator_set` from marker key; documents per-package .conf pattern; Confirmation criteria delta). ADR-015 Scope table gains BOTH `wr-risk-scorer:external-comms` (retroactive — P064's iter never landed it) + `wr-voice-tone:external-comms` (new for P038).
- **Awaiting user verification**: real-world exercise of the voice-tone gate on at least one outbound `gh issue comment` / `gh pr create` / `npm publish` / `.changeset` author event — gate denies with directive to `wr-voice-tone:external-comms`; delegation completes; subsequent retry permits. When both plugins installed, both gates' denials should appear independently (each names its own subagent).

## Decision record

**ADR-028 (amended 2026-04-21)** — "External-comms gate — voice-tone + risk/leak evaluators on shared PreToolUse surface" — records the decision for this ticket AND P064 (risk/leak) AND P073 (changeset authoring). Combined ADR per user direction: one gate shape, two evaluators, ADR-017 duplicate-script distribution so each of `@windyroad/voice-tone` and `@windyroad/risk-scorer` remains independently installable. Composite marker scheme (`evaluator_set` in the key) handles partial-install scenarios. Voice-tone advisory-only when `docs/VOICE-AND-TONE.md` absent; risk advisory-only when `RISK-POLICY.md` absent. This ticket (P038) remains Open as the execution tracker for the voice-tone evaluator half (agent prompt amendment + bats tests + per-package synced hook copy).

## Related

- **ADR-028** (amended 2026-04-21) — decision record for this ticket; closes the design question. Implementation tracks under this ticket.
- **P064** — sibling "risk/leak" half of the combined gate; same ADR-028.
- **P073** — changeset authoring surface; same ADR-028 (surface list now includes `.changeset/*.md`).
- [JTBD-001](../jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md) — "Every edit to a project file is reviewed against relevant policy before it lands" generalises to external-comms policy enforcement
- [ADR-009](../decisions/009-gate-marker-lifecycle.proposed.md) — gate marker patterns apply if this becomes a hook
- [ADR-015](../decisions/015-on-demand-assessment-skills.proposed.md) — on-demand assessment pattern informs the gate design
- `docs/VOICE-AND-TONE.md` — existing voice profile (in-repo text scope)
- `packages/voice-tone/skills/update-guide/SKILL.md` — existing skill scope
- `/Users/tomhoward/.claude/usage-data/report.html` — insights report identifying the pattern (2026-03-17 to 2026-04-16, 1,464 messages across 86 sessions)
- P034 — centralise risk reports (shares cross-project analytics-driven pattern)
- **P073** — No voice-tone or risk gate on changeset authoring. Surface-inventory extension: include `PreToolUse:Write` on `.changeset/*.md` when the shared hook surface lands here. The changeset body populates CHANGELOG.md, the Release PR body, the GitHub Release page, and the published npm tarball — gating at `npm publish` (the current P038 surface row) is too late because the CHANGELOG.md has already been committed to main by then. Add `.changeset/*.md` to the hook's write-path patterns alongside the existing gh / npm publish entries.
