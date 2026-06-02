# Problem 030: manage-problem verification prompts omit fix summary, forcing clarifying rounds

**Status**: Closed
**Reported**: 2026-04-16
**Priority**: 10 (High) — Impact: Minor (2) x Likelihood: Almost Certain (5)
**Effort**: S
**WSJF**: 10.0 — (10 × 1.0) / 1

## Description

When `manage-problem work` presents pending-verification questions (step 9d), it includes only the problem ID, title, and release version — e.g. "Has P020 (No on-demand assessment skills) been verified working in production? (Released in v0.3.2)". This is not enough context for the user to answer confidently. The user can't remember what a problem's fix actually did without reading the problem file themselves.

**Observed this session (2026-04-16):** Asked about P020, P021, and P027 in a single `AskUserQuestion` call. The user answered "remind me what P020 is" and "remind me what P021 is" — requiring two extra clarifying exchanges before any verification could be collected.

**What should happen instead:** Each verification question should include a one-line summary of what the fix changed, drawn from the `## Fix Released` section of the problem file. The user can then answer yes/no from the question itself without reading the full problem.

## Symptoms

- User receives verification questions with only a problem ID, title, and version number — no description of what to test.
- User must answer "remind me what PXxx is" or navigate to the problem file before answering.
- Extra clarifying rounds add latency and break the `manage-problem work` flow.
- The verification AskUserQuestion is wasted if the user cannot interpret it — the conversation has to backtrack.

## Workaround

Ask "remind me what P0XX is" — the agent reads the file and gives a summary, then the user can answer.

## Impact Assessment

- **Who is affected**: Every user of `manage-problem work` who has pending-verification known-errors in the backlog.
- **Frequency**: Every `work` invocation where `## Fix Released` sections exist. Expected on every session after a release cycle.
- **Severity**: High — verification prompts are how problems get closed. If they require extra rounds to interpret, they block the closure flow and accumulate open known-errors.
- **Analytics**: Observed this session — P020, P021, P027 verification prompts all produced "remind me" replies.

## Root Cause Analysis

Step 9d of the SKILL.md says "use `AskUserQuestion` to ask the user if the fix has been verified in production" but does not specify what content the question must include. The question format is left to the agent's discretion, and the agent defaults to a minimal ID + title + version format without reading the `## Fix Released` section to extract a fix summary.

### Fix Strategy

In SKILL.md step 9d, require that verification questions include the first sentence of the `## Fix Released` section (or a compact bullet list of what changed) as the `description` of the `AskUserQuestion` option, or as inline text in the question body. The agent already reads the problem file to detect the `## Fix Released` section — extracting the summary is no additional I/O.

**Example target format:**
> Has P020 been verified in production?
> *What was fixed: four new on-demand assessment skills added — `/wr-risk-scorer:assess-release`, `/wr-risk-scorer:assess-wip`, `/wr-architect:review-design`, `/wr-jtbd:review-jobs`. Released in v0.3.2.*

### Investigation Tasks

- [x] Update step 9d in `packages/itil/skills/manage-problem/SKILL.md` to require fix summary in verification questions
- [x] Extend `packages/itil/skills/manage-problem/test/manage-problem-no-prose-options.bats` with a test asserting the verification AskUserQuestion includes fix content (not just ID + title)

## Fix Released

Step 9d in `packages/itil/skills/manage-problem/SKILL.md` updated to require fix summary extracted from `## Fix Released` section in all verification AskUserQuestion calls. Regression guard added to `manage-problem-no-prose-options.bats` (test 7, all 7 GREEN). Both architect and JTBD reviews PASS.

Fix verified immediately in this session — the next invocation of `manage-problem work` used fix summaries in all three pending verification prompts.

## Related

- `packages/itil/skills/manage-problem/SKILL.md` — step 9d is the fix location
- `packages/itil/skills/manage-problem/test/manage-problem-no-prose-options.bats` — test coverage for SKILL.md structural assertions
- P021 (`docs/problems/021-governance-skill-structured-prompts.known-error.md`) — sibling: structured prompts pattern; this problem is about prompt *content*, not prompt *structure*
- ADR-013 (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — mandates AskUserQuestion at decision branches; does not specify what content questions must include
