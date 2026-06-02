# Problem 336: packages/itil/skills/transition-problems/SKILL.md frontmatter has YAML Parse error — `claude plugin validate packages/itil` fails on this file

**Status**: Closed
**Reported**: 2026-05-30
**Priority**: 12 (High) — Impact: 3 (Moderate — `claude plugin validate packages/itil` hard-fails for adopters; npm publish path disrupted) × Likelihood: 4 (Likely — already hit on dogfood; persistent on `@windyroad/itil@0.39.0`)
**Origin**: internal
**Effort**: S (one-line frontmatter quoting fix; shipped session 9)
**WSJF**: 12.0 (re-rated 2026-05-31; fix shipped session 9, awaiting K→V transition on next `@windyroad/itil` release)

## Description

Surfaced 2026-05-30 by P263 iter 6 empirical probe. Running `claude plugin validate packages/itil` (Claude Code CLI 2.1.150) reports:

```
frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token
```

Specifically against `packages/itil/skills/transition-problems/SKILL.md`. Blocks `validate`-clean state for `@windyroad/itil`. Once the P263 Phase 1 CI gate (non-strict `claude plugin validate` per plugin pre-publish) is shipped, this YAML error will fail CI with the wrong signal — the gate would report a real frontmatter defect, not a regression introduced by Phase 1.

Reporter: iter 6 of `/wr-itil:work-problems` session 9 (2026-05-30 work-problems AFK loop, dispatched by orchestrator after iter 5 deferred P082 on JTBD ratification).

## Symptoms

- `claude plugin validate packages/itil` exits non-zero with `frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token`.
- Other SKILL.md frontmatters in `@windyroad/itil` parse clean — defect is scoped to `packages/itil/skills/transition-problems/SKILL.md`.

## Workaround

Wrap the SKILL.md `description:` scalar in double quotes when its prose contains a colon + space sequence (`: `) — YAML treats unquoted `: ` as a mapping-key boundary. For maximum robustness, also substitute internal colons with em-dashes so the value renders cleanly raw or parsed.

## Impact Assessment

- **Who is affected**: maintainer + future P263 Phase 1 CI gate
- **Frequency**: every `claude plugin validate packages/itil` invocation (manual or CI)
- **Severity**: Moderate — `validate` exits non-zero; npm publish path disrupted for adopters
- **Analytics**: surfaced once on dogfood (P263 iter 6 empirical probe); persistent on `@windyroad/itil@0.39.0` until fix shipped session 9

## Root Cause Analysis

The unquoted `description:` scalar in `packages/itil/skills/transition-problems/SKILL.md` contained the substring `Singular sibling: \`/wr-itil:transition-problem\` (one ticket per invocation).` At column 796 the unquoted YAML parser hit `: ` (colon + space) inside the value and treated it as a mapping-key boundary, raising `YAML Parse error: Unexpected token`. Other SKILL.md frontmatters in `@windyroad/itil` had their multi-sentence descriptions wrapped in double quotes, so they parsed clean — defect was scoped to the one unquoted block.

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — done (re-rated 2026-05-31, WSJF=12.0, Effort S)
- [x] Locate the exact malformed token in the SKILL.md frontmatter — column 796, the `: ` inside `Singular sibling: \`/wr-itil:...`
- [x] Repair frontmatter so `claude plugin validate packages/itil` exits 0 — fixed in commit `bd80077` (2026-05-31 session 9): wrapped description in double quotes + substituted internal colon with em-dash
- [ ] Add a behavioural test (bats) that runs `claude plugin validate` on all `@windyroad/*` plugins and fails on parse errors — composes with P263 Phase 1 (the CI gate itself catches this class going forward; this ticket is the one-off cleanup, the bats is P263's responsibility)

## Reproduction

```bash
claude plugin validate packages/itil
# Before fix (HEAD ≤ bd80077^): frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token
# After fix (HEAD ≥ bd80077):    ✔ Validation passed with warnings (exit 0)
```

## Dependencies

- **Blocks**: P263 Phase 1 CI gate (`claude plugin validate` per plugin pre-publish) — once Phase 1 lands, this YAML error fails CI on every push of `@windyroad/itil` until repaired.
- **Blocked by**: (none)
- **Composes with**: P263 (CI gate provides ongoing protection against this class of defect once repaired)

## Fix Released

<!-- no-changeset-reference: changeset .changeset/p336-transition-problems-yaml-frontmatter.md consumed pre-ticket-update; release vehicle derived from git log --diff-filter=D walk -->

Released in `@windyroad/itil@0.39.0` (merge commit `64afd0d`, PR #182, version-packages commit `1d1d6a8`, released 2026-05-31). Fix: wrapped the `description:` scalar in double quotes and substituted the internal colon with an em-dash so YAML no longer mis-parses the value as a mapping-key boundary at column 796.

**Verified** — `yes — observed: claude plugin validate packages/itil exits 0 ("✔ Validation passed with warnings") on HEAD post-bd80077; @windyroad/itil@0.39.0 published to npm with the fix; close-on-evidence per ADR-044 by /wr-itil:work-problems iter-2 orchestrator authorisation 2026-05-31`.

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P263** — surfaced this defect during iter 6 empirical probe; P263 Phase 1 CI gate would catch similar future regressions.
