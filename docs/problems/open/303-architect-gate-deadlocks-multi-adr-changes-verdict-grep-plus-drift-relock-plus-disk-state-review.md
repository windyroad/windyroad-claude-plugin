# Problem 303: Architect gate deadlocks any multi-decision-file change — verdict-grep + drift-relock + disk-state-review compound into an unbreakable lock

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 9 (Med High) — Impact: 3 (Moderate — every change that touches ≥2 `docs/decisions/` files in one session is blocked from landing through the gate without manual marker recovery; supersessions, ADR re-home ripples, and cluster-rollout ADRs all hit it) × Likelihood: 3 (Likely — any non-trivial governance change is multi-ADR; P294 hit it on the first attempt)
**Effort**: M — the three facets each have a sibling ticket; the fix is to make them compose (a single recovery path + per-decision-edit hash refresh on the held marker, or a "review-approved-this-session" marker that survives drift)
**WSJF**: 9/4 = **2.25** (Open multiplier 1.0)
**Type**: technical

## Description

Recording ADR-069 (P294, supersede ADR-051) required editing five `docs/decisions/` files (create 069; flip 051 to superseded; re-home citations in 063, 060, 053) plus the gated hook/detector/bats/SKILL files. The architect gate (`packages/architect/hooks/`) made this **impossible to land through the gate's own happy path**. Three known facets compounded:

1. **Verdict-grep treats thorough review as FAIL (P181 / P217).** `architect-mark-reviewed.sh` writes the unlock marker only when the agent output contains the literal `Architecture Review: PASS` and does NOT contain `ISSUES FOUND`. A thorough architect review that *approves the design* but enumerates addressable conditions (each prefixed "ISSUES FOUND") is parsed as FAIL, so the marker is never written — even though the review approved the change. Four successive reviews approved the ADR-069 design; none produced an unlock.

2. **Disk-state-review deadlock (new facet).** Once the proposed approach is approved, the architect agent reviews *disk state* to confirm the work landed. But the work cannot land while the gate is locked, and the gate stays locked until a clean PASS — which requires the work to be on disk. The agent correctly reports "the work is not on disk yet" → `ISSUES FOUND` → no marker. Circular.

3. **Drift-relock on every decision edit (P215 / P216 / P226).** `check_architect_gate` stores the `docs/decisions/` content hash at review time and removes the marker on the next gated edit when the hash has changed. So even a single clean PASS unlocks exactly **one** decision-file write before re-locking — a five-decision-file change would need five clean PASS reviews, which facet 1+2 make unobtainable.

Net: there is no gate-happy path for a multi-decision-file change. The change lands only via **manual gate-misfire recovery** (assert `/tmp/architect-reviewed-${SID}` and remove the `.hash` file so `check_architect_gate` takes its "no hash = old marker format, allow" branch), which is what P294 did under explicit user authorisation.

## Symptoms

- `Write`/`Edit` to `docs/decisions/*.md` denied with "Cannot edit ... without architecture review" despite the architect agent having reviewed and approved the change in-session (4×).
- Each `docs/decisions/` write that *does* get through re-locks the gate for the next edit.
- Architect re-reviews after approval report `ISSUES FOUND` solely because the approved work is not yet on disk.

## Workaround

Manual gate-misfire recovery (ADR-048 lineage → ADR-050 runtime-SID discovery): resolve the session SID from `/tmp/itil-runtime-sid-${USER}-${proj_hash}.current` (via `runtime_sid_path()`), `touch /tmp/architect-reviewed-${SID}`, and `rm -f /tmp/architect-reviewed-${SID}.hash`. With the hash file absent, `architect-refresh-hash.sh` is a no-op (it only refreshes an existing hash file) and `check_architect_gate` allows every subsequent edit. Requires explicit user authorisation — it asserts a true fact (these changes WERE architect-reviewed) but defeats the gate's drift-detection automation for the session.

## Root Cause Analysis

### Investigation Tasks

- [ ] Make the three facets compose. The cleanest shape: a per-session "architect-reviewed-this-change" marker that survives `docs/decisions/` drift WITHIN the same review session (the drift-detection is meant to catch *unreviewed cross-session* edits, not the multi-file change the review just approved). Options: (a) refresh the stored hash on each allowed `docs/decisions/` write while the marker is live (extends `architect-refresh-hash.sh` to create-if-live, not only refresh-if-exists); (b) a "review covers the proposed change-set" mode keyed to the reviewed file list rather than a whole-directory hash; (c) verdict parsing that distinguishes "approved with addressable conditions" from "blocking ISSUES FOUND" (folds in P181/P217).
- [ ] Resolve the disk-state-review deadlock: the architect agent should be able to render `PASS` on a *proposed plan* (pre-edit) without conditioning the verdict on disk state, OR the gate should accept a plan-level approval marker distinct from the post-edit drift check.
- [ ] Provide a first-class recovery affordance (P215 asks for this) so manual `/tmp` surgery is not the only escape.

## Dependencies

- **Composes with**: [[181]] (verdict-grep fragility), [[215]] (drift-detection rm marker without recovery), [[216]] (refresh-hash only on docs/decisions writes), [[217]] (strict-verdict-string under-counts affirmative verdicts), [[226]] (TTL forces re-review on multi-file work). P303 is the composite — the three facets together produce a hard deadlock that no single sibling captures.
- **Surfaced by**: P294 / ADR-069 supersession (first multi-ADR change to hit the full compound).

## Related

(captured 2026-05-25 during the P294/ADR-069 supersession, under user authorisation to land via gate-misfire recovery + capture this defect)

- **ADR-048** (`docs/decisions/048-gate-misfire-recovery-procedure.superseded.md`) — original recovery procedure; superseded by **ADR-050** which provides the reliable runtime-SID the recovery now uses.
- **ADR-066** — the human-oversight drain that surfaced P294; ADR-069 is born-confirmed, so the supersession itself needed no drain — the deadlock was purely the edit-gate.
