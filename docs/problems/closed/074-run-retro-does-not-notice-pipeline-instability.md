# Problem 074: run-retro does not notice pipeline instability and record corresponding problem tickets

**Status**: Closed — verified in post-AFK-iter-7 retrospective 2026-04-21 (Step 2b fired and produced 3 specific pipeline-instability citations: claude -p stdin warning + cost-metadata edge case + risk-scorer TTL expiry)
**Reported**: 2026-04-20
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M — extend `packages/retrospective/skills/run-retro/SKILL.md` with a new step (between Step 2 reflection and Step 4 problem-ticket creation) that scans session activity for pipeline-instability signals and routes each detected instability through Step 4 as an auto-populated problem-ticket candidate. Includes bats doc-lint assertions for the detection categories, the signal heuristics, and the auto-population contract. Cross-reference to P068's Step 4a Verification-close pattern (same-shape evidence-scan step). Effort held at M on implementation (2026-04-21, iter 4 AFK): SKILL.md edit (~90 new lines) + one new bats test file (12 assertions), no new ADR, no cross-package migration.
**WSJF**: 0 — Verification Pending (excluded from ranking per ADR-022 / SKILL.md WSJF table).

## Fix Released

Shipped in the commit that renames this file to `.verifying.md` (AFK iter 4, 2026-04-21). Awaiting release to `@windyroad/retrospective@0.6.0` via the orchestrator's release queue.

- **SKILL.md edit**: added Step 2b `Pipeline-instability scan (P074)` between the existing Step 2 (reflection) and Step 3 (BRIEFING.md update), placed before Step 4 (ticket creation) so detections feed the ticketing flow. Six signal categories enumerated (hook-protocol friction / skill-contract violations / release-path instability / subagent-delegation friction / repeat-work friction / session-wrap silent drops). Each detection requires specific-citation grounding per ADR-026 (tool invocation + session position + observable outcome). Four-option AskUserQuestion (Create new ticket / Append to P<NNN> / Record in retro report only / Skip — false positive) per ADR-013 Rule 1; AFK fallback records in a new Pipeline Instability section of the retro summary per ADR-013 Rule 6. Ownership boundary matches Step 4a: run-retro surfaces, manage-problem commits.
- **Step 5 summary**: added a `### Pipeline Instability` section with the four-column table `| Signal | Category | Citations | Decision |` so AFK runs have a structured record of detections.
- **Bats test**: `packages/retrospective/skills/run-retro/test/run-retro-pipeline-instability-scan.bats` — 12 assertions covering step header, six-category enumeration, ADR-026 grounding, AskUserQuestion contract, AFK fallback, manage-problem delegation, dedup against existing tickets, ADR-027 compat note, section placement (between Step 2 and Step 4), Step 5 summary integration, table schema, and P068 shape cross-reference.
- **Verification evidence**: `npx bats packages/retrospective/skills/run-retro/test/` — 64/64 pass (52 pre-existing + 12 new). No changes to `.ts/.tsx/.js/.jsx` so TDD red-green not required beyond the doc-lint shape ADR-005 permits.

Awaiting user verification.

## Description

`/wr-retrospective:run-retro` Step 2 asks the agent to reflect on "what failed", "what was harder than it should have been", and "what should we make easier or automate". In practice agents under-report **pipeline-level instability** — bugs, regressions, or friction in the tools the session itself relied on (hooks, skills, subagent protocols, release scripts, TTL / marker contracts). The agent treats these as "incidental friction I worked around" instead of as first-class problem tickets the way it would treat a product-code defect.

Pipeline instability is exactly what problem management is designed to capture: it's durable friction that hits every subsequent session until a ticket exists. Missing it in run-retro means the same incident recurs every session, the audit trail has no record of the recurrence rate, and the WSJF queue never reflects the aggregate cost. The user notices the recurrence (because they hit it again) and has to manually re-raise the ticket — defeating the "run-retro captures learnings so they are not lost" outcome.

The 2026-04-20 post-AFK interactive session produced several concrete instances that a run-retro pass today would silently drop:

- **Architect hook TTL expired mid-iteration** — 1800s TTL (per ADR-009) ran out while I was drafting long files (ADR-031 specifically), forcing a marker-refresh round-trip in the middle of a Write operation.
- **Architect-hook marker-vs-file deadlock** — the hook demands a PASS marker before the Write can happen; the architect agent refuses to issue PASS on a file that doesn't exist yet. Resolved by a narrower marker-refresh prompt pattern, but the deadlock is a real hook-protocol bug.
- **push:watch misbehaviour (P060)** — the sanctioned push path was itself broken and reported success on the PRIOR sha's workflow run. Required a mid-session fix before the drain cycle could proceed honestly.
- **ADR-027 Step-0 collision with auto-migration** — surfaced only by architect review of ADR-031, NOT by the skill itself. If architect review hadn't caught it, the auto-migration contract would have conflicted with Step 0 delegation at implementation time.
- **work-problems false-zero-bail on adopter repos** — same architect review catch; the orchestrator's Step 1 scan would silently exit without triggering any migration in a flat-layout adopter repo.
- **The JTBD / architect hooks' "mandatory check on every UserPromptSubmit" even when we're ONLY editing `docs/problems/` or `docs/jtbd/` (excluded from scope)** — the hook fires the same boilerplate REQUIRED ACTIONS message on every prompt regardless of whether it applies, which adds noise to every turn and makes it easier to miss the real signals.

None of the above would have been captured as problem tickets by a standard run-retro pass today. They are exactly the class of durable friction problem management exists to track.

## Symptoms

- After a session full of pipeline workarounds, run-retro produces a BRIEFING.md update + codification candidates but zero new problem tickets for the tool-level friction that forced those workarounds.
- Recurring hook-protocol friction (TTL expiries, marker-vs-file deadlocks, hook-scope overreach) never gets a ticket, so the recurrence rate stays invisible in the WSJF queue.
- User-observed instances of "this tool didn't work right this session" don't produce problem tickets unless the user manually types `/wr-itil:manage-problem` after run-retro runs.
- `docs/problems/` grows only in proportion to user-raised tickets + product-code defects; tool-level friction accumulates off-ledger.
- The WSJF prioritisation lens never sees pipeline cost, so decisions like "fix this hook defect vs ship this new skill" are made on partial information.

## Workaround

User manually notices the friction and invokes `/wr-itil:manage-problem` after run-retro runs to file a ticket. That's exactly the "manually police AI output" pain pattern JTBD-001 is designed against — run-retro should be doing this.

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-001)** — "Enforce governance without slowing down" fails when the governance surface itself has friction that never gets tracked. Every session pays the instability cost again.
  - **Plugin-developer persona (JTBD-101)** — "clear patterns, not reverse-engineering" is violated when the patterns themselves are unstable but the instability never hits the audit trail.
  - **Tech-lead persona (JTBD-201)** — "audit trail of AI-assisted work" is incomplete; tool friction is absent from the record.
  - **AFK orchestrators (JTBD-006)** — loops that hit hook TTL expiries or marker deadlocks mid-iteration waste iterations without the failure appearing in the backlog.
- **Frequency**: Every session. The 2026-04-20 session alone produced 6+ distinct pipeline-instability events (listed above).
- **Severity**: High. The cost compounds across sessions: untracked friction recurs; the WSJF queue cannot prioritise fixes that never become tickets; the audit trail lies about what sessions actually cost.
- **Analytics**: A longitudinal count of "session produced ≥ 1 tool-friction event" would quantify the recurrence rate. Currently none — the analytics don't exist because the tickets don't exist.

## Root Cause Analysis

### Structural

`packages/retrospective/skills/run-retro/SKILL.md` Step 2 lists five reflection prompts ("what you wish you'd been told up front", "what surprised you", "what was harder than it should have been", "what failed", "what should we make easier or automate"). Four of those could in principle capture pipeline instability, but they are framed around **the work the session was trying to do**, not the tools the session was trying to do it with. Agents read the prompts and list product-code friction (what I was trying to build) instead of meta-level friction (what was in the way of building it).

Step 4 handles problem-ticket creation but only for items already in the reflection output. If Step 2 didn't surface the pipeline event, Step 4 never sees it.

P068's Step 4a Verification-close housekeeping (just shipped this session, `@windyroad/retrospective@0.4.0`) is the shape the fix wants — a dedicated evidence-scan step with specific-citation grounding (ADR-026) that categorises what was observed in the session. The same shape applies here: scan session activity for a defined set of pipeline-instability signals, categorise each detection, route each confirmed signal to Step 4's problem-ticket creation flow with an auto-populated template.

### Pipeline-instability signal categories (initial inventory)

This list is the starting point for the detection heuristic. Implementation at Step 4a-style time will refine it.

1. **Hook-protocol friction** — gate-marker TTL expiries mid-work, marker-vs-file deadlocks, hook-exemption scope gaps, hooks firing on paths they shouldn't, hooks silently skipping paths they should.
2. **Skill-contract violations** — skill steps that collide (e.g. ADR-027 Step 0 vs ADR-031 auto-migration Step 0), skills that return empty on paths they should handle (e.g. work-problems false-zero-bail), skills whose AskUserQuestion options exceed the 4-option cap (per P061).
3. **Release-path instability** — push:watch / release:watch misbehaviour (P054, P060 class), changeset authoring defects (P073), release-PR body issues.
4. **Subagent-delegation friction** — architect / jtbd / risk-scorer agents returning DEFERRED, ISSUES FOUND that block progress, PASS markers failing to write, or agent prompts timing out.
5. **Repeat-work friction** — the same workaround applied ≥ 3 times in one session (each application is signal; the third triggers a ticket candidate).
6. **Session-wrap silent drops** — cases where run-retro itself under-reports (the meta case this ticket fixes).

### Candidate fix

Add a new **Step 2b: Pipeline-instability scan** to `packages/retrospective/skills/run-retro/SKILL.md`, placed between the existing Step 2 (reflection) and Step 4 (problem-ticket creation). Shape mirrors P068's Step 4a:

1. **Glob / scan**: walk session history for signal matches from each category above. Specific patterns:
   - Hook TTL expiry → log lines containing `review expired (Ns old, TTL Ms)`, `marker refresh`, `PreToolUse hook blocking error`.
   - Marker-vs-file deadlock → sequences where a Write was blocked, an agent was invoked for a marker, and the agent returned "DEFERRED" or similar non-PASS.
   - push:watch / release:watch failures → non-zero exits on those scripts, or observable sha-mismatch in `gh run list` output.
   - Subagent DEFERRED / ISSUES FOUND that blocked progress → architect / jtbd agent outputs matching those markers.
   - Repeat workaround → same `Bash` command pattern appearing ≥ 3 times with the same outcome.
2. **Evidence-scan grounding (ADR-026)**: every detected signal MUST cite the specific tool invocation, timestamp/position, and observable outcome. Bare "pipeline was flaky this session" does not qualify; "architect hook TTL expired at turn N while drafting `docs/decisions/031-…proposed.md` (log line `review expired (1814s old, TTL 1800s)`), forcing a marker-refresh round-trip" does.
3. **Categorise**: each detection falls into one of the 6 categories above. A detection can match multiple categories; pick the primary.
4. **Dedup against existing tickets**: for each detection, search `docs/problems/*.open.md` and `*.known-error.md` for matching keywords (category + signal pattern). If a matching ticket exists: append new evidence to its `## Symptoms` or `## Root Cause Analysis` section via Step 4's update path. If not: create a new ticket via Step 4's creation path with the detection's category, citations, and a suggested title.
5. **Interactive path (ADR-013 Rule 1)**: for each detection, `AskUserQuestion` with the detection summary + evidence inline; options: `Create new ticket`, `Append to P<NNN>`, `Record in retro report only (not ticket-worthy)`, `Skip — false positive`.
6. **Non-interactive / AFK fallback (ADR-013 Rule 6)**: record each detection in the retro report's new "Pipeline Instability" section with its category, citations, and dedup status. Do NOT auto-create tickets in AFK — user explicitly confirms on return. Same trust-boundary shape as P068's Verification Candidates pattern.
7. **Ownership**: run-retro surfaces the detection; delegates ticket creation / update to `/wr-itil:manage-problem` via the Skill tool. Same cross-plugin ownership boundary the P068 fix established.

### Architect review requirements (at implementation time)

- Interaction with **ADR-027** (governance skill auto-delegation) — Step 2b must run inside the subagent context (main agent delegates to run-retro subagent, subagent reads session history). Same constraint P068's Step 4a documented.
- Interaction with **ADR-026** (agent output grounding) — signal detection citations are the concrete test surface; specific invocation + observable outcome required, no bare counts.
- Interaction with **ADR-018** (retrospective session cadence) — Step 2b fires at every retro run; is the detection budget proportional to session length, or is there a cap?
- **Dedup contract** — the matching heuristic against existing tickets needs a defined similarity threshold. Lean: exact category + signal-pattern match only (keyword overlap on title is too loose; the same-problem-classifier shape in P070's candidate fix is overkill for dedup against local tickets). Architect call at implementation time.

### Investigation Tasks

- [ ] Finalise the pipeline-instability signal inventory — current 6-category list is a starting point; audit one-month session logs to confirm coverage.
- [ ] Draft the Step 2b SKILL.md content following P068's Step 4a pattern.
- [ ] Decide the dedup contract — keyword match, category + signal-pattern match, or LLM-based dup classifier (ties to P070's same-problem-classifier shape).
- [ ] Add bats doc-lint assertions: Step 2b present, 6 categories enumerated, ADR-026 grounding cited, AskUserQuestion 4-option contract, AFK fallback cited, ownership-delegation to manage-problem.
- [ ] Cross-reference from P068's Step 4a (both steps share the evidence-scan + citation-required + interactive/AFK-branch shape).
- [ ] Update `feedback_verify_from_own_observation.md` memory (or a sibling) to note that run-retro is now the enforcement point for in-session tool-friction observations.
- [ ] Exercise end-to-end: run run-retro at the end of a session known to contain pipeline-instability events (e.g. this session, 2026-04-20); confirm at least 4 of the 6+ known events are detected.

## Related

- **P068** (run-retro Step 4a verification-close housekeeping) — immediate sibling; same evidence-scan shape applied to a different surface. Cross-reference at implementation time.
- **P044** (run-retro does not recommend new skills) — adjacent retro-extension ticket. This ticket's signals also feed P044's skill-candidate recommendations when pipeline friction indicates a new skill would help.
- **P050** (run-retro does not recommend other codifiable outputs) — adjacent. A pipeline-instability signal may indicate a hook fix or ADR rather than a skill; codification axis still applies.
- **P051** (run-retro improvement axis for existing codifiables) — adjacent. Most pipeline-instability tickets will be "improve existing hook / SKILL.md / ADR" not "create new".
- **P060** (push:watch anchor) — concrete example of a release-path instability ticket that was raised manually this session; run-retro should have caught it.
- **P061** (install-updates Step 6 4-option cap) — concrete example of skill-contract instability; user raised after the fact.
- **P073** (changeset authoring not gated) — concrete example of release-path instability surfaced during this session.
- **P068** Step 4a contract — the evidence-scan + grounding + AFK-fallback pattern this ticket's Step 2b follows.
- **ADR-026** (agent output grounding) — citations-required enforcement.
- **ADR-027** (governance skill auto-delegation) — run-retro's Step-0 delegation constraints apply to Step 2b too.
- **ADR-013** (structured user interaction) — Rule 1 for the interactive AskUserQuestion; Rule 6 for the AFK fallback.
- **JTBD-001** (Enforce Governance Without Slowing Down) — solo-developer persona; the whole point of this ticket is that instability cost never reaches the WSJF queue.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — tech-lead persona; audit trail currently lies about session cost.
- **JTBD-006** (Progress the Backlog While I'm Away) — AFK persona; orchestrators hitting pipeline friction mid-loop produce untracked cost today.
- `packages/retrospective/skills/run-retro/SKILL.md` — the target of the amendment; Step 2b sits between Step 2 and Step 4.
- `packages/retrospective/skills/run-retro/test/` — where the new bats doc-lint test lands.
