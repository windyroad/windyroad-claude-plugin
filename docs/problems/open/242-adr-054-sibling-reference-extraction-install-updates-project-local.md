# Problem 242: ADR-054 sibling-REFERENCE.md extraction — `install-updates` (project-local)

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 6 (Medium) — Impact: 2 x Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 3.0 — (6 × 1.0) / 2 — re-rated 2026-05-23: P081 verifying→0; transitive = marginal M (was 1.5)

## Description

P097 Phase 3 named target: project-local `.claude/skills/install-updates/SKILL.md` (currently 16,872 bytes — MUST_SPLIT). Per architect verdict (2026-05-17 work-problems iter 8 Q6), the project-local skill warrants its own follow-on ticket — separate from the plugin-published MUST_SPLIT cohort umbrella (P241) — because:

1. Project-local bats coupling differs from plugin-published bats; the `.claude/skills/install-updates/test/*.bats` files may unblock independently of P081 Layer B's plugin-published harness primitives.
2. `install-updates` is the canonical adopter-marketplace refresh skill; its size pressure has a different audience than the governance ITIL skills (every windyroad-plugin adopter session vs the project's own maintainers).
3. P098 (sibling of P097) covers project-owned context contributors generally; `install-updates` sits at the boundary — included in P097 Phase 3 per the ticket's original framing.

Per ADR-054 § "Phase 2-3 sequencing": opportunistic-as-touched. Extract when the skill is next edited.

## Symptoms

- Every adopter session loading the windyroad marketplace via `install-updates` pays the full 16,872-byte runtime cost.
- The skill's structure (sibling cap fallback bats; consent-gate bats) couples some structural-grep assertions to specific SKILL.md prose (see P081 / P011 reference example in P097 history: commit `c106e62` triggered remediation `84c920e` when semantics-preserving compression broke verbatim greps).

## Workaround

None for end-users. Maintainer-side: extract `[reference]` content opportunistically per ADR-054 when next editing.

## Impact Assessment

- **Who is affected**: every windyroad-plugin adopter on session-start / `/install-updates` invocation.
- **Frequency**: at least once per adopter session (cross-project loop end-of-session per `install-updates` SKILL.md description).
- **Severity**: Medium (smaller per-invocation than MUST_SPLIT cohort top-3; broader audience).
- **Analytics**: `wr-retrospective-check-skill-md-budgets` includes `.claude/skills/*/SKILL.md` in its walk per ADR-054.

## Root Cause Analysis

### Confirmed

Same root cause class as the rest of P097: mixed `[runtime]` + `[reference]` content within a single file. P097 history (2026-04-22 trim attempt) measured `install-updates` SKILL.md at 13,524 bytes; current (2026-05-17) at 16,872 bytes — same accumulation pressure as the plugin-published cohort.

### Hypothesised on fix path

`install-updates` bats coupling needs to be enumerated:
- `.claude/skills/install-updates/test/install-updates-consent-gate-sibling-cap.bats` — historic source of the P011 example regression; coupling acknowledged
- Other bats in `.claude/skills/install-updates/test/` — coupling not yet enumerated

If coupling is low enough that simple `grep` retargeting to SKILL.md + REFERENCE.md is acceptable (Path A per P097 Phase 1 § "Deferred-design questions" 2026-04-27), the extraction may unblock independently of P081 Layer B. Otherwise, blocks behind P081 Layer B same as P241.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Enumerate `.claude/skills/install-updates/test/` bats coupling — list each `*.bats` file by structural-grep count + asserted phrases
- [ ] Decide Path A (bats-grep-update) vs Path B (behavioural retrofit) per architect review at the touch-point
- [ ] Apply ADR-054 sibling-REFERENCE.md pattern: extract `[reference]`-tagged content; add lazy-load pointers per ADR-054 § 84; verify SKILL.md drops below MUST_SPLIT (16,384 bytes)
- [ ] Re-run `wr-retrospective-check-skill-md-budgets` and confirm `.claude/install-updates` row drops from MUST_SPLIT to OVER-only (or below WARN)

## Fix Strategy

Per-touch opportunistic per ADR-054 + ADR-052 § Migration. When `.claude/skills/install-updates/SKILL.md` is next edited:
1. Enumerate bats coupling
2. Pick Path A or Path B per architect review
3. Extract `[reference]` sections to sibling `.claude/skills/install-updates/REFERENCE.md`
4. Verify size drops below MUST_SPLIT
5. Single commit per ADR-014

## Dependencies

- **Blocks**: (none — descendant of P097)
- **Blocked by**: (conditional) P081 Layer B IF coupling enumeration reveals Path A is insufficient; otherwise unblocked
- **Composes with**: P097 (parent driver), P241 (plugin-published cohort sibling), P243 (WARN-band sibling), P098 (project-owned context contributors), ADR-054, ADR-052

## Related

- **P097** — driver / parent ticket.
- **P098** — sibling: project-owned context contributors (CLAUDE.md, memory, local skills) — `install-updates` is the project-local skill instance of this concern.
- **P081** — Layer B conditional blocker.
- **ADR-054** — governing decision; project-local `install-updates` is explicitly named in Phase 3 scope (ADR-054 line 107).
- **ADR-052** — behavioural-default test discipline.
- **P011** — historic example of structural-grep bats blocking semantics-preserving compression on `install-updates-consent-gate-sibling-cap.bats`.
