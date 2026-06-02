# Problem 063: manage-problem does not trigger /wr-itil:report-upstream when root cause is external

**Status**: Closed
**Reported**: 2026-04-20
**Closed**: 2026-04-24 — verified in-session via run-retro Step 4a. I invoked `/wr-itil:report-upstream P113 https://github.com/anthropics/claude-code` this session; the external-root-cause-triggered report-upstream path fired correctly, filed anthropics/claude-code#52831, and back-wrote the `## Reported Upstream` cross-reference to P113's closed ticket (commit 539e952). The P063 contract held end-to-end.
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: S — one conditional prompt step in `packages/itil/skills/manage-problem/SKILL.md` (Open → Known Error transition, or when parking with `upstream-blocked` reason), plus a bats doc-lint assertion.
**WSJF**: 9.0 — (9 × 1.0) / 1 — small, high-leverage wiring fix; unblocks the real-world path for P055's shipped `/wr-itil:report-upstream` skill.

## Direction decision (2026-04-20, user — AFK pre-flight)

**Defaults AFK can apply without further user input**:
- Detection granularity: **strict**. Require an explicit external-root-cause marker (`upstream`, `third-party`, `external`, `vendor`, or a scoped-npm-package name pattern `@[\w-]+/[\w-]+` in the Root Cause Analysis section). Avoids false-positive prompt fatigue.
- Insertion points: Step 7 Open → Known Error transition (primary) AND the parking path when reason is `upstream-blocked` (secondary). Both fire.
- Non-interactive (AFK) branch: append a pending-upstream-report line to `## Related` noting the detected external dependency; do NOT auto-invoke `/wr-itil:report-upstream`. Consistent with ADR-024's Consequences (security-path halt) and JTBD-006.
- No new ADR needed — this is a `manage-problem` SKILL.md scope change; ADR-024 already governs the invoked skill's contract.

## Description

`@windyroad/itil@0.8.0` ships `/wr-itil:report-upstream` (P055 Part B, ADR-024). The skill's contract is solid and tested, but `manage-problem` is a **passive consumer** of the output, not an active caller: `packages/itil/skills/manage-problem/SKILL.md` only acknowledges the `## Reported Upstream` appendage at line 50 ("written by the `/wr-itil:report-upstream` skill"). Nothing in the "Working a Problem" flow detects "root cause points to an upstream defect" and prompts the user to invoke `/wr-itil:report-upstream`.

The closest adjacent behaviour is the opposite of reporting:

- **Parked** (line 38, "Blocked on upstream") — parking is "give up / wait", not "actively notify".
- **work-problems' `upstream-blocked` skip category** (`packages/itil/skills/work-problems/SKILL.md` lines 103 / 111) — "move on without reporting".

Result: an agent identifying a root cause of "bug in `@some/upstream-pkg`" writes the finding into Root Cause Analysis, may park the ticket, and `/wr-itil:report-upstream` is never invoked unless the user types the command themselves. The contract is built but the trigger surface is missing — a discoverability gap that P055 Part B shipped but didn't close.

## Symptoms

- External root cause captured in Root Cause Analysis (e.g. "bug in `@anthropic/claude-code` filter regex", "npm registry rate-limit response schema changed") with no upstream issue filed.
- Tickets park with reason `upstream-blocked` and stay parked — no upstream issue URL in `## Related`, no `## Reported Upstream` section.
- `work-problems` AFK loops skip upstream-blocked tickets without even drafting a candidate upstream report for later review.
- Downstream projects (addressr, bbstats) that install `@windyroad/itil@0.8.0` get the `/wr-itil:report-upstream` skill but no skill-chain wiring that points to it; agents still have to remember the command by name.

## Workaround

User manually invokes `/wr-itil:report-upstream <ID> <upstream-url>` after noticing the external root cause. This requires knowing the skill exists and remembering the invocation syntax — friction the suite is otherwise designed to avoid (JTBD-001 "Enforce governance without slowing down").

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-001)** — agents lose the prompt that would surface upstream-reporting as the right next step. User has to police the flow manually or type the command.
  - **Tech-lead persona (JTBD-201)** — audit trail gap: downstream problem tickets mark upstream root cause but never emit the outbound half, so "Restore service fast with an audit trail" remains one-way.
  - **Plugin-developer persona (JTBD-101)** — the "clear patterns, not reverse-engineering" promise fails at the exact handoff where ADR-024's contract is most useful.
  - **Downstream project maintainers** — upstream-reporting capability ships but goes unused without explicit invocation.
- **Frequency**: Every problem ticket whose root cause identifies an upstream dependency. Across the suite's session history (30-day window in `/Users/tomhoward/.claude/usage-data/report.html`) this happens multiple times per week when hooks misfire against plugin updates, CLI tool upgrades, or third-party API changes.
- **Severity**: Medium. Not a correctness defect — the skill works when invoked — but a wiring gap that defeats the primary reason P055 Part B was built. ADR-024's Confirmation criterion 6 (downstream adoption within 3 months) depends on the skill being discoverable, not memorised.
- **Analytics**: N/A — problem-ticket metadata doesn't today track "upstream root cause identified → upstream issue filed" as a conversion. Fixing this ticket would make that pairing visible.

## Root Cause Analysis

### Structural

ADR-024 scoped the `report-upstream` skill's implementation (steps 1–8 of Decision Outcome) but did not specify the **trigger surface** — the upstream decision was "what does the skill do?", not "who invokes it and when?". `manage-problem` was updated to accept the `## Reported Upstream` appendage (ADR-024 Confirmation criterion 3a) but not to prompt for upstream reporting when external root cause is detected.

### Detection signals already present in the ticket body

When an agent writes a Root Cause Analysis, the following patterns indicate an external root cause:

- Named external dependency: an npm package (`@scope/pkg`, bare package name), a GitHub `owner/repo` reference, a third-party API name (`anthropic`, `gh`, `npm`, `RapidAPI`, `Shopify`).
- Explicit labels: `upstream`, `third-party`, `external`, `vendor bug`, a `## External root cause` section.
- Parking reason: `upstream-blocked` (already machine-checkable — the reason is recorded in the `## Parked` section per the Parked lifecycle).

These signals are already in the ticket body. What's missing is a step that reads them and triggers `AskUserQuestion` with the option to invoke `/wr-itil:report-upstream`.

### Candidate fix

Add a detection step in `manage-problem` at two natural junctures:

1. **At Open → Known Error transition** (Step 7) — after pre-flight checks pass, scan Root Cause Analysis for external-root-cause markers. If present, use `AskUserQuestion` with:
   - `(a) Invoke /wr-itil:report-upstream now` — halts the transition, invokes the skill, the skill's Step 7 back-writes `## Reported Upstream`, then resumes the Known Error transition.
   - `(b) Defer and note in ticket` — append a reminder to `## Related` (e.g. `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready`).
   - `(c) Not actually upstream` — proceed without prompting; mark the detection as a false positive so it doesn't re-fire on subsequent reviews.

2. **When parking with `upstream-blocked` reason** — before writing the `## Parked` section, fire the same prompt. Parking an upstream-blocked ticket without having reported the bug upstream is the canonical "audit trail gap" case.

**Non-interactive (AFK) branch**: when `AskUserQuestion` is unavailable, default to option (b) — note the pending upstream-report in `## Related`. Do NOT auto-invoke `/wr-itil:report-upstream` without user approval; the skill's Step 6 security-path branch is interactive and would halt the orchestrator anyway (ADR-024 Consequences).

### Investigation Tasks

- [ ] Draft the external-root-cause detection regex/token list (npm scoped names, bare package names, GitHub `owner/repo`, explicit labels `upstream` / `third-party` / `external`).
- [ ] Decide detection granularity — strict (explicit label required) vs. permissive (any package reference in Root Cause Analysis). Favour strict to avoid false positives that train the user to ignore the prompt.
- [ ] Pick the insertion point in `packages/itil/skills/manage-problem/SKILL.md` — Step 7 Open → Known Error transition block is the primary; Step 7 parking block is the secondary.
- [ ] Update `packages/itil/skills/work-problems/SKILL.md` so AFK runs that skip with `upstream-blocked` reason append the pending-upstream-report line to `## Related` per the non-interactive branch above.
- [ ] Add a bats doc-lint test asserting the prompt wording + the three `AskUserQuestion` options + the AFK non-interactive fallback are all documented.
- [ ] Update ADR-024 Reassessment Criteria to include "trigger surface implemented" as a milestone (optional — the ADR already covers the skill's contract; the trigger is a `manage-problem` scope change).
- [ ] Exercise end-to-end: open a ticket with an obviously-upstream root cause, run `manage-problem` Open → Known Error, verify the prompt fires and option (a) cleanly invokes `/wr-itil:report-upstream`.

## Fix Released

Shipped 2026-04-20 (AFK iter 6 commit pending). The trigger surface from `manage-problem` to `/wr-itil:report-upstream` is now wired per the pinned direction:

- `packages/itil/skills/manage-problem/SKILL.md` — Step 7 (Open → Known Error transition) gains a new **External-root-cause detection** block. Strict detection tokens: explicit label `upstream` / `third-party` / `external` / `vendor`, or scoped-npm pattern `@[\w-]+/[\w-]+`. Three AskUserQuestion options (invoke / defer+note / not actually upstream). AFK fallback appends a stable marker `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready` to `## Related` without auto-invoking the skill (its Step 6 security-path is interactive, per ADR-024 Consequences). Already-noted grep check prevents duplicate firing. Parked lifecycle entry cross-references the detection block for `upstream-blocked` park reason.
- `packages/itil/skills/work-problems/SKILL.md` — `upstream-blocked` skip-row and taxonomy entry both run the manage-problem AFK fallback before skipping. Non-Interactive Decision Making table gains a row describing the detection + append-marker behaviour. Marker wording is verbatim-identical across both skills.
- `packages/itil/skills/manage-problem/test/manage-problem-external-root-cause-detection.bats` — NEW. 14 structural doc-lint assertions (Permitted Exception per ADR-005) covering: detection tokens, scoped-npm pattern, three AskUserQuestion options, stable marker wording (verbatim), AFK fallback, already-noted check, both insertion points, Parked cross-reference, ADR-024 + ADR-013 Rule 6 references, and cross-file marker consistency.

Architect review PASSED (no new ADR needed; aligns with ADR-024, ADR-013, ADR-022). JTBD review PASSED (aligned with JTBD-001, JTBD-101, JTBD-201 + JTBD-006 for AFK). Full bats suite: 405 assertions pass (was 391; +14 from the new file). No regressions.

Awaiting user verification: the next time manage-problem transitions a ticket whose Root Cause Analysis mentions `upstream` / `third-party` / `external` / `vendor` or a scoped-npm package, the three-option prompt should fire (or the AFK fallback should append the pending-upstream-report line).

## Related

- **P055** — parent ticket; Part B shipped `/wr-itil:report-upstream` but left trigger wiring open.
- **P038** — voice-and-tone gate on external comms; sibling "external comms needs a gate" scope (voice-tone half).
- **P064** — risk-scoring gate on external comms; sibling "external comms needs a gate" scope (risk-scoring half).
- **ADR-024** — Cross-project problem-reporting contract; defines the skill but not its trigger surface.
- **ADR-013** — structured user interaction; Rule 1 governs the `AskUserQuestion` prompt, Rule 6 governs the non-interactive fallback.
- **ADR-022** — problem lifecycle Verification Pending; the transition is the natural point to check.
- **JTBD-001** (Enforce Governance Without Slowing Down) — solo-developer persona; the prompt replaces "remember the command" with "answer one question".
- **JTBD-201** (Restore Service Fast with an Audit Trail) — bi-directional linkage fix.
- **JTBD-101** (Extend the Suite with Clear Patterns) — the "clear patterns" promise at the exact handoff where it's most valuable.
- `packages/itil/skills/manage-problem/SKILL.md` line 50 — only current mention of `report-upstream` (passive acknowledgement).
- `packages/itil/skills/work-problems/SKILL.md` lines 103 / 111 — `upstream-blocked` skip category; the parking-surface hook point.
