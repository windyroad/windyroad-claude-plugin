# Problem 279: ADR-017 § Consequences documents flat layout under `packages/shared/`, but hook-helpers cluster under nested `hooks/lib/` — housekeeping clarification

**Status**: Verification Pending
**Reported**: 2026-05-19
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)

## Description

Session 8 iter 6 (P273+P274+P275 batched sibling sweep) shipped the `command_invokes_git_commit` shared helper at `packages/shared/hooks/lib/command-detect.sh` per architect verdict 2026-05-19. The architect cited existing precedent — `session-marker.sh` / `leak-detect.sh` / `external-comms-key.sh` already live under nested `packages/shared/hooks/lib/`. So nested-under-hooks/lib/ is the established pattern for hook helpers.

But ADR-017 § Consequences currently documents the flat layout under `packages/shared/` per the `derive-first-dispatch.sh` precedent (which lives at `packages/itil/lib/derive-first-dispatch.sh`, not under `packages/shared/`). The two coexisting conventions are:

- **Cross-cutting libs** (e.g. `derive-first-dispatch.sh`) — flat under each package's `lib/` directory; sync'd across packages via ADR-017's sync script + CI gate.
- **Hook helpers** (e.g. `session-marker.sh`, `leak-detect.sh`, `external-comms-key.sh`, now `command-detect.sh`) — clustered under `packages/shared/hooks/lib/`; each package's hooks source from there directly.

**Proposed fix**: amend ADR-017 § Consequences with a one-line note acknowledging both clustering patterns. Hook helpers cluster under `packages/shared/hooks/lib/` for proximity to their consumers; cross-cutting libs stay flat per the existing convention. Architect flagged this as "useful housekeeping but not gate-required" — defer-friendly.

## Symptoms

(deferred to investigation)

- ADR-017 § Consequences description doesn't fully match the on-disk shape of `packages/shared/`.
- Future contributors reading ADR-017 may not know about the hook-helper sub-convention.

## Workaround

None needed currently — the iter-6 commit message + architect verdict both document the verdict shape inline. Future contributors who need the convention should be able to derive it from the on-disk pattern.

## Impact Assessment

- **Who is affected**: future contributors reading ADR-017 to author new shared helpers.
- **Frequency**: per-author one-off; once read, the convention is internalised.
- **Severity**: (deferred to investigation) — initial: low. Housekeeping only.

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — Priority 3 (Med) / Effort S confirmed accurate; ticket now excluded from WSJF (verifying, multiplier 0 per ADR-022)
- [x] Investigate root cause — ADR-017 § Consequences documented only the flat layout; the hook-helper `hooks/lib/` destination subpath was undocumented. Verified on-disk: BOTH conventions use the same ADR-017 sync mechanism (sync-*.sh + check:* CI gates exist for session-marker, command-detect, derive-first-dispatch, migrate-problems-layout); only the per-package destination subpath differs by helper role (`lib/` vs `hooks/lib/`). The ticket's earlier "hooks source from there directly" framing was imprecise — hook helpers ARE synced per-package (8 copies of session-marker.sh across packages), preserving self-containment.
- [x] Amend ADR-017 § Consequences with the hook-helper nested-clustering convention — added Neutral bullet "Two destination-path conventions, one sync mechanism"
- [x] Consider whether to add a `packages/shared/README.md` listing the conventions inline — added a concise pointer-doc (packages/shared/ was the lone package without a README); it defers to ADR-017 as authoritative rather than restating the decision (drift-safe per architect + JTBD verdicts)

## Fix Released

Docs-only housekeeping, committed this session (2026-05-26 AFK `/wr-itil:work-problems` iter). **No npm publish / no changeset** — `packages/shared/` is not a published plugin and ADR-017 is repo-internal, so there is no release vehicle; the fix is live on `main` once committed.

Changes:
- `docs/decisions/017-shared-code-sync-pattern.proposed.md` § Consequences § Neutral — new bullet "Two destination-path conventions, one sync mechanism" documenting that cross-cutting libs sync into each package's `lib/` and hook helpers sync into each package's `hooks/lib/`, both under the same `sync-<name>.sh` + `check:<name>` CI drift gate; only the destination subpath differs by helper role.
- `packages/shared/README.md` (new) — concise contributor-facing pointer-doc mapping the directory layout → role→subpath rule → ADR-017 (authoritative).

Gates: architect PASS (no new ADR — housekeeping carve-out, consistent with iter-6 verdict), JTBD PASS (serves JTBD-101 plugin-developer "undocumented conventions requiring reverse-engineering" pain point). Voice-tone + style-guide gates non-applicable (extension-scoped to `.css`/`.html`/`.jsx`/UI; this change is pure markdown).

Awaiting user verification: read the amended ADR-017 § Consequences + `packages/shared/README.md` and confirm the two-convention documentation is accurate and useful.

## Dependencies

- **Composes with**: ADR-017 (cross-package sync convention parent), P268 (helper that triggered the layout decision), P273+P274+P275 (siblings that landed Option B)

## Related

(captured 2026-05-19 from /wr-itil:work-problems session 8 iter 6 (P273+P274+P275 batched sibling sweep) deviation-approval queue, user-directed via AskUserQuestion at Step 2.5)

- ADR-017 — cross-package sync convention parent
- `packages/shared/hooks/lib/` — actual nested-cluster location
- iter 6 architect verdict — "Option B at packages/shared/hooks/lib/ matching the existing session-marker.sh / leak-detect.sh / external-comms-key.sh precedent there. ADR-017 covers the shape; no new ADR required"
