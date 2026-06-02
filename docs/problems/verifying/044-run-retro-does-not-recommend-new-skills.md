# Problem 044: run-retro does not recommend new skills when it should

**Status**: Verification Pending
**Reported**: 2026-04-18
**Priority**: 8 (Med) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: 8.0 (8 × 2.0 / 2)  — transitioned 2026-04-19 after root cause confirmed and fix strategy documented

## Description

The `wr-retrospective:run-retro` skill is the right tool for capturing
session learnings — it correctly identifies friction, failures, and
automation opportunities, and routes each to either BRIEFING.md updates
or new problem tickets. But it does NOT recommend creating a **new
skill** in cases where that would be the better output.

Some kinds of friction are best solved by codifying the workflow as a
new skill (so future sessions can invoke it via `/skill-name`), not by
filing a problem ticket. The retrospective skill currently has no branch
for that decision — every observed friction is funneled into a problem
ticket.

User feedback (2026-04-18): "the run-retro skill is good, but I noticed
that it fails to recommend new skills when it should".

## Symptoms

- Sessions where the assistant performed a repeated multi-step workflow
  (e.g., "fetch origin → check changesets → score risk → commit → push →
  release → sync manifest → mark Fix Released") complete the
  retrospective with a problem ticket like "this is tedious" instead of
  a recommendation like "consider a `/sync-and-release` skill"
- Workflows that obviously belong in a skill (canonical action sequence,
  reusable across projects, executed multiple times in one session) get
  no skill-recommendation prompt
- The skill output format (step 5) only has slots for BRIEFING.md
  changes and problem tickets — no slot for "skill candidates"

## Workaround

Operator vigilance: after running `/wr-retrospective:run-retro`, the
user (or assistant) reviews the friction list and manually identifies
candidates that should be skills rather than problem tickets, then files
them as `/wr-itil:manage-problem` tickets with a "this should be a
skill" recommendation in the description. This is what currently happens
ad-hoc; the skill itself does not prompt the analysis.

## Impact Assessment

- **Who is affected**: Every user running session retrospectives. Solo
  developer persona (JTBD-001, JTBD-006) loses opportunities to codify
  recurring workflows. Plugin developer persona (JTBD-101) loses signal
  about which skills the suite should grow.
- **Frequency**: Every retrospective session that includes a recurring
  multi-step workflow — typically one or more per long session
- **Severity**: Minor per occurrence (a missed skill opportunity is not
  user-visible breakage), but Likely per session — the cumulative effect
  is that the skill suite grows slower than it could
- **Analytics**: No persistent tally yet; would need a separate "skill
  candidates" log to measure

## Root Cause Analysis

### Confirmed Root Cause (2026-04-18)

Source-code evidence from `packages/retrospective/skills/run-retro/SKILL.md`:

- **Step 2 — Reflect on this session** lists five categories: "What you
  wish you'd been told", "What surprised you", "What was harder than it
  should have been", "What failed", "What should we make easier or
  automate". None of these explicitly trigger a "new skill" branch. The
  closest is "What should we make easier or automate" — but that
  category routes to a problem ticket, not a skill recommendation.
- **Step 4 — Create or update problem tickets** is the only output
  branch for friction items. There is no parallel "Step 4b — Recommend
  new skills" or equivalent.
- **Step 5 — Summary** template has slots for "BRIEFING.md Changes",
  "Problems Created/Updated", and "No Action Needed". No slot for
  "Skill Candidates".

The skill is structurally complete for what it does, but the universe
of valid outputs is missing one category (skill recommendations).

### Fix Strategy

1. **Add a new reflection category to Step 2**: "What recurring
   workflow did I (or the assistant) perform that would be better as a
   skill?" Criteria: multiple invocations in one session, deterministic
   sequence, reusable across projects.
2. **Add Step 4b — Recommend new skills**: walk the candidates from
   step 2; for each, present an `AskUserQuestion` with options:
   - `Create a new skill` — proceed to skill scaffolding (may need a new
     dedicated `wr-retrospective:scaffold-skill` skill, or invoke an
     existing meta-skill if one exists)
   - `Track as a problem ticket instead` — file via
     `/wr-itil:manage-problem` so the work can be planned later
   - `Skip — not skill-worthy` — neither create nor track
3. **Add a "Skill Candidates" slot to Step 5 summary** so the user sees
   the recommendations alongside BRIEFING and problems.
4. **Add a bats test** asserting the SKILL.md mentions the skill-
   recommendation branch.

### Decisions resolved (2026-04-19)

- **Skill scaffolding**: deferred to a future scaffolding flow. The retrospective skill **records candidates only** — suggested name, scope, triggers, prior uses — so a future scaffolder (or the user) can pick them up. This keeps P044 additive and reversible; architect confirmed scaffolding would warrant its own ADR when it lands.
- **Candidate record content**: the recommendation includes suggested skill name (kebab-case, plugin-namespaced), scope sentence, example triggers, and prior uses from the session. The extra content is near-zero cost to include and makes the candidate actionable later.
- **P012 overlap**: no hard dependency. The fix notes that once skill scaffolding lands, it should produce harness-ready tests, but P044 does not block on P012.
- **ADR requirement**: none. The change is additive to Step 2/4/5 content only (new reflection category, new output branch, new summary slot); it does not change commit sequencing, so ADR-014 is unaffected. `run-retro` remains out of ADR-014 scope until a future ADR brings it in.
- **ADR-013 compliance**: Step 4b uses `AskUserQuestion` with three structured options and a non-interactive fallback (flagged — not actioned). Architect review flagged that prose `(a)/(b)/(c)` enumeration in the skill output would violate ADR-013; implementation uses AskUserQuestion option descriptions only.

### Investigation Tasks

- [x] Confirm the gap (run-retro SKILL.md has no skill-recommendation
      branch — verified 2026-04-18)
- [x] Check whether other plugin marketplaces have a pattern for
      "skill-from-friction" recommendations — none found in-project;
      the candidate-record approach mirrors the problem-ticket record
      pattern which is the closest available precedent.
- [x] Decide whether skill scaffolding is in scope — no; candidates
      are recorded only, scaffolding is a future concern.
- [x] Architect review — pass; no new ADR needed.
- [x] Implement the SKILL.md changes.
- [x] Add bats test (`packages/retrospective/skills/run-retro/test/run-retro-skill-candidates.bats` — 10 assertions).
- [ ] Update P012 (skill testing harness) to note that any future
      skill-scaffolding flow should produce harness-ready tests —
      deferred to P012's own fix commit.

## Fix Released

Fix implemented on 2026-04-19:
- `packages/retrospective/skills/run-retro/SKILL.md` — added skill-candidate reflection category to Step 2, added Step 4b (Recommend new skills) using `AskUserQuestion` per ADR-013 Rule 1, added Skill Candidates slot to Step 5 summary.
- `packages/retrospective/skills/run-retro/test/run-retro-skill-candidates.bats` — 10-assertion doc-lint test covering Step 2 category, Step 4b branch, ADR-013 compliance (AskUserQuestion + absence of prose option prompts), Rule 6 fallback, and Step 5 summary slot.

Released in: _pending release cadence check (this iteration)_.

Awaiting user verification that `/wr-retrospective:run-retro` now recommends skills for recurring workflows observed in session.

## Related

- `packages/retrospective/skills/run-retro/SKILL.md` — the skill being
  amended; specifically Step 2 (reflection categories), Step 4 (output
  routing), and Step 5 (summary slots)
- P012: `docs/problems/012-skill-testing-harness.open.md` — adjacent;
  any new skill-scaffolding workflow should produce harness-ready tests
- P028: `docs/problems/028-governance-skills-should-auto-release-and-install.known-error.md`
  — the recurring "commit + push:watch + release:watch + plugin.json
  sync + Fix Released" sequence shipped 4 times in this session and is
  a canonical example of a workflow that probably belongs in a new
  skill (e.g., `wr-itil:ship-fix`)
- ADR-014: `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`
  — establishes the lean-release principle; codifying the
  ship-fix-after-commit sequence in a skill would extend it
