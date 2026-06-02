# Problem 185: `/wr-itil:capture-problem` asks a classification question (technical vs user-business) that it can answer itself from the description's observable evidence

**Status**: Verification Pending
**Reported**: 2026-05-12
**Priority**: 10 (High) — Impact: 2 (Minor — dev tooling friction in installed SKILL; published packages unaffected) x Likelihood: 5 (Almost certain — every interactive `/wr-itil:capture-problem` invocation deterministically fires the AskUserQuestion; observed today on the P185 capture itself)
**Effort**: M (Step 1.5 derive-first refactor + lexical-signal classifier in `packages/itil/skills/capture-problem/SKILL.md` + behavioural bats covering signal classes + stderr-advisory contract; sibling capture-* skills "title taste" investigation is conditional follow-up not in marginal scope)
**WSJF**: 5.0 = (Severity 10 × Status Multiplier 1.0 Open) / Effort divisor 2 (M)

## Description

`/wr-itil:capture-problem` Step 1.5 currently fires an `AskUserQuestion` for `type` ∈ {`technical`, `user-business`} unless `--type=<value>` or `--no-prompt` is passed. This is "taste authority per ADR-044 category 5" per the SKILL contract.

The user observation 2026-05-12: this question is **derivable from the description's observable evidence in nearly every real capture**. When the description says "the SKILL asks useless questions" or "the build fails on Linux" or "the cache invalidates on every commit", the type is unambiguously `technical` — the description names code / behaviour / mechanism. When the description says "JTBD-007 is missing a desired outcome" or "the README confuses adopter X" or "atomic-fix adopters can't use feature Y", the type is unambiguously `user-business` — the description names persona / experience / journey.

Asking the user to classify a problem they have already classified by the words they chose is **friction-add without information gain**. The agent reads the description and can derive `type` deterministically from a small set of lexical signals (presence of code identifiers, error messages, file paths, mechanism words ↔ presence of persona names, journey words, user-experience words). Cases where the signal is genuinely ambiguous are rare; for those, the question is justified — but the framework should derive-first, ask-on-ambiguity-only.

This is the **inverse-P078 / P132 trap applied to a SKILL contract surface**: the SKILL re-introduces friction the framework's broader design (CLAUDE.md "act on obvious, AskUserQuestion for ambiguous, NEVER prose-ask", memory `feedback_dont_subcontract_declaration_fields.md`) explicitly forbids. The SKILL was written when the type-tag schema was new (P170 Phase 1 Slice 4 B7.T3); the load-bearing concern was that I2 invariant enforcement be visible at capture-time. The visible enforcement can be preserved via derived classification with stderr advisory ("classified as `technical` from description signals X, Y; re-invoke with `--type=user-business` to override").

This ticket is itself a meta-recursive example: the user invoked `/wr-itil:capture-problem` with a description that names "asks useless questions that it can answer itself, like 'is this a technical or business problem'" — the answer is `technical` (the description names a skill defect; root cause sits in skill prose). The agent answered the type question from context rather than firing the AskUserQuestion, applying the user's correction inline.

## Symptoms

- Every interactive `/wr-itil:capture-problem` invocation fires the type AskUserQuestion (1 prompt per capture).
- Cumulative friction across an AFK orchestrator that captures N mid-iter sibling-findings = N redundant prompts (mitigated currently by AFK callers passing `--no-prompt` per the SKILL contract; the mitigation IS the design defect — the SKILL has to be told "don't ask").
- The friction compounds with the prose-ask anti-pattern documented at P085 — "AskUserQuestion for ambiguous, NEVER prose-ask, act on obvious" is the load-bearing rule the SKILL violates by asking for the obvious.

## Workaround

Pass `--type=technical` or `--type=user-business` on every interactive invocation. AFK orchestrators MUST pass `--no-prompt` per the SKILL contract. This works but the workaround IS the design defect.

## Impact Assessment

- **Who is affected**: maintainers using interactive `/wr-itil:capture-problem`; AFK orchestrators (mitigated via `--no-prompt`).
- **Frequency**: every interactive capture (N=1 prompt per invocation).
- **Severity**: low — friction-add, not a correctness defect. The type field ends up correct either way.
- **Analytics**: count of interactive `capture-problem` invocations that fire the type AskUserQuestion vs the count that pre-resolve via `--type=` flag. Ratio close to 1.0 indicates the friction-add is universal.

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems (re-rated 2026-05-12 — Priority 10 High / Severity 10, Effort M, WSJF 5.0)
- [x] Investigate the lexical signals that reliably distinguish `technical` from `user-business` descriptions. **Result (2026-05-13)**: classifier ships in `packages/itil/skills/capture-problem/SKILL.md` Step 1.5 with five technical signal classes (camelCase / kebab-case / snake_case identifiers; file paths; command-name patterns; mechanism words; error-message patterns) and three user-business signal classes (persona names; journey words; JTBD-shaped need words). Patterns documented inline at Step 1.5 with case-sensitivity notes. Behavioural validation via `packages/itil/skills/capture-problem/test/capture-problem.bats` exercises pure-technical, pure-user-business, mixed, and no-signal fixtures.
- [x] Design the derive-first, ask-on-ambiguity-only Step 1.5 replacement. **Result (2026-05-13)**: dispatch order is `--type=<value>` (highest priority caller flag) → `--no-prompt` (AFK contract default to `technical`) → lexical-signal classifier (unambiguous one-sided signal → silent classification + stderr advisory) → AskUserQuestion fallback (mixed or zero signals). Stderr advisory contract: SINGLE line of the form `"capture-problem: classified type=<value> from description signals: <s1>, <s2>; re-invoke with --type=<other> to override"` — to stderr only, never stdout, never in ticket body. I2-isomorphic sentence structure across both classifications.
- [x] Create a reproduction test. **Result**: 17 new bats tests in `packages/itil/skills/capture-problem/test/capture-problem.bats` — 8 classifier-decision tests across pure-technical / pure-user-business / mixed / no-signal fixtures; 3 stderr-advisory shape tests for I2 isomorphism; 5 dispatch-precedence tests for flag short-circuit + derive-first dispatch + ambiguous fallback; 1 meta-recursive test against a representative slice of P185's own body. All 32 tests in the suite (15 pre-existing + 17 new) pass.
- [ ] Investigate whether the same derive-first pattern applies to other capture skills (`capture-rfc`, `capture-story`, `capture-story-map`). They don't currently fire a type classification AskUserQuestion, but they DO fire a "title taste" prompt; same derivability question applies. **Deferred** per the Effort M bound — this is the conditional follow-up named in the ticket's Effort field and tracked as a separate observation if the sibling skills exhibit the same friction in real captures.

## Fix Released

Fixed in AFK iter 2 of 2026-05-13 `/wr-itil:work-problems` session. Implementation surfaces:

- `packages/itil/skills/capture-problem/SKILL.md` Step 1.5 — derive-first dispatch + lexical-signal classifier + stderr advisory contract.
- `packages/itil/skills/capture-problem/SKILL.md` Rule 6 audit table — recategorised type-tag dispatch from "taste authority per ADR-044 category 5" to "silent-framework per category 4 on unambiguous; taste fallback per category 5 on ambiguous". Architect verdict 2026-05-13: in-scope under ADR-044 Reassessment Criteria; no ADR amendment needed.
- `packages/itil/skills/capture-problem/SKILL.md` Composition table — Type-tag row + AskUserQuestion authority row updated to reflect derive-first dispatch.
- `packages/itil/skills/capture-problem/SKILL.md` JTBD-301 scope guard — extended with explicit "classifier NOT invoked from manage-problem ingestion-of-plugin-user-reports path" guard per architect rider.
- `packages/itil/skills/capture-problem/test/capture-problem.bats` — 17 new behavioural bats tests (classifier outcomes + stderr advisory isomorphism + dispatch precedence + meta-recursive corpus validation).

Visible-enforcement preservation (the original P170 Phase 1 Slice 4 B7.T3 design intent for visible I2 enforcement at capture-time): stderr advisory on every derived classification makes the resolver's decision observable, with a single-flag override path.

Memory file `feedback_derive_classification_dont_ask.md` already captures this principle as a class-of-behaviour rule (sibling to `feedback_dont_subcontract_declaration_fields.md` and `feedback_act_on_obvious_decisions.md`).

Awaiting user verification that (1) interactive `/wr-itil:capture-problem "..."` on a description with clear technical signals classifies silently (with stderr advisory) instead of firing the AskUserQuestion; (2) on a description with clear user-business signals, same silent classification; (3) on a genuinely-ambiguous description (mixed or zero signals), the AskUserQuestion still fires; (4) `--type=<value>` and `--no-prompt` still short-circuit per the pre-existing contract.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none)
- **Composes with**: P132 (inverse-P078 — agents over-ask in interactive sessions; this ticket is a specific instance), P085 (act on obvious / AskUserQuestion for ambiguous / NEVER prose-ask — the canonical rule this SKILL violates at Step 1.5), P170 / ADR-060 (the SKILL contract was written under the type-tag schema introduction; the SKILL's `type` field semantics carry over but the AskUserQuestion firing condition needs revision), memory `feedback_dont_subcontract_declaration_fields.md` (sibling user-direction on derive-from-evidence not ask).

## Related

- **P132** — agents over-ask in interactive sessions; this ticket is a specific instance at a specific SKILL surface.
- **P085** — act on obvious, AskUserQuestion for ambiguous, NEVER prose-ask.
- **P170** / **ADR-060** — type-tag schema; Phase 1 Slice 4 B7.T3 introduced the Step 1.5 AskUserQuestion. The schema stays; the firing condition changes.
- **memory `feedback_dont_subcontract_declaration_fields.md`** — "For incident/problem/ADR declarations, derive title/severity/start-time from observable evidence; only AskUserQuestion for genuinely-direction-setting fields (e.g. scope)."
- **`packages/itil/skills/capture-problem/SKILL.md`** — the SKILL surface this ticket fixes; Step 1.5 needs the derive-first refactor.
- **ADR-044** — decision-delegation contract; `type` classification was Phase 1 declared "taste authority per category 5" — this ticket asks whether that classification was correct, or whether `type` is actually "silent-mechanical with stderr advisory on derived classification" per the framework-resolution boundary (category 4 / silent-framework).

(captured via /wr-itil:capture-problem; expand at next investigation)
