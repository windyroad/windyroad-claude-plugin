# Problem 343: `/install-updates` refreshes the global plugin cache but does NOT fix PATH ordering — stale plugin-version shims stay first on PATH, so subsequent shim invocations run old code

**Status**: Known Error
**Reported**: 2026-05-31
**Promoted to Known Error**: 2026-06-01
**Priority**: 12 (High) — Impact: 3 (Moderate — directly blocked ~10 commits across session 9 from being shippable; caused entire CI test 2145 saga) × Likelihood: 4 (Likely — fires every session after a plugin release where the user does not also restart the shell to refresh PATH)
**Origin**: internal
**Effort**: M (install-updates amendment to reorder PATH OR shim-resolution to always pick highest-version OR session-start refresh mechanism)
**WSJF**: 6.0 (re-rated 2026-05-31; was placeholder I=3×L=1; session-9 blast-radius warrants honest S12/L4/M scoring)
**Type**: technical

## Description

Surfaced 2026-05-31 by direct empirical investigation during session 9 CI test 2145 fix.

Symptom: after `/install-updates` ran successfully and verified `~/.claude/plugins/cache/windyroad/wr-architect/0.12.2/` existed (alongside older 0.7.0 → 0.12.1 + new 0.13.0), the `wr-architect-generate-decisions-compendium` shim resolved to:

```
/Users/tomhoward/.claude/plugins/cache/windyroad/wr-architect/0.11.0/bin/wr-architect-generate-decisions-compendium
```

NOT 0.12.2 (or 0.13.0) — the latest installed version. The 0.11.0 shim dispatches to its sibling `0.11.0/scripts/generate-decisions-compendium.sh` which is the pre-P334 version (uses Unicode `…`).

`echo "$PATH" | tr ':' '\n' | grep wr-architect` showed:

```
/Users/tomhoward/.claude/plugins/cache/windyroad/wr-architect/0.11.0/bin
```

Only the 0.11.0 path on PATH. The newer versions (0.12.2, 0.13.0) were in cache but not on PATH.

Result: every `wr-architect-generate-decisions-compendium` invocation during session 9 ran the stale 0.11.0 script producing Unicode `…` in the compendium. CI test 2145 (which compares committed vs fresh-script regen on Linux which uses the in-repo script producing ASCII `...`) failed on every push for the entire session.

Root cause: `/install-updates` refreshes the plugin cache (uninstall + reinstall to defeat P106 silent-no-op) but does NOT mutate the user's PATH. Claude Code's session-init populated PATH with `0.11.0/bin` (likely the version that was current at the time of the first session start that enabled architect). Subsequent /install-updates calls added 0.12.0/0.12.1/0.12.2/0.13.0 to the cache but didn't update PATH, so shim lookups continue to find 0.11.0 first.

## Symptoms

- `/install-updates` reports `installed` for plugin (and verifies cache version matches npm latest) but shim invocations continue running OLD plugin code.
- `which <shim>` returns a stale-version path even though newer versions are in cache.
- Any work that depends on the shim running new code is silently using old code.
- User restart of Claude Code IS the documented workaround per `/install-updates` Step 5 ("Restart Claude Code to pick up the new plugin code"), but the restart-cost-of-shim-update is high during active work — friction conflicts with /install-updates' "safe to run any time" claim.
- Sibling AFK iter subprocesses spawn fresh processes which presumably DO pick up new PATH, so the bug doesn't manifest in iters — only in the long-lived main session.

## Workaround

Bypass PATH and invoke the shim by absolute path of the desired version:

```bash
~/.claude/plugins/cache/windyroad/wr-architect/0.13.0/bin/wr-architect-generate-decisions-compendium
```

This is what unblocked test 2145 in session 9. But this is per-invocation; no SKILL-side automation.

## Impact Assessment

- **Who is affected**: every user who runs `/install-updates` mid-session and continues to use plugin shims in the same main turn afterward.
- **Frequency**: every release-loop session that ships a plugin and continues working in the same session.
- **Severity**: HIGH in practice — session 9 lost ~3hr of release blocking + 1hr of user push-back AND $130+ in agent budget chasing the CI red.
- **Analytics**: session 9 alone — entire AFK exchange accumulated 7 commits un-shippable; user had to push back twice ("Don't leave shit broken!!").

## Root Cause Analysis

`/install-updates` Step 4 invokes `claude plugin uninstall` + `claude plugin install`. This advances the cache version but does NOT mutate the parent shell's PATH. The PATH was populated at Claude Code's session-init from the cache state at that time; PATH stays frozen for the lifetime of the session.

The shim search order is whatever PATH dictates. If `0.11.0/bin` is earlier on PATH than `0.13.0/bin`, the 0.11.0 shim is found first.

Possible structural fixes:

1. **Restart-on-/install-updates** — make `/install-updates` Step 5 trigger an explicit Claude Code restart. This breaks the "safe to run any time" claim and is high-friction; rejected by user direction 2026-04-20 per P045.

2. **Single-versioned shim path** — change the shim layout so only the LATEST version of each plugin is on PATH. `claude plugin install` should re-symlink `<plugin>/bin → <plugin>/<latest>/bin` (or equivalent) so PATH entry is version-agnostic. Requires Claude Code's plugin-install internals change — upstream concern.

3. **Highest-version-wins shim wrapper** — replace each shim with a wrapper script that always dispatches to the highest-version sibling in its parent cache directory. Adopter-portable; bounded change in plugin scaffold templates.

4. **Session-start PATH refresh hook** — a new SessionStart hook (per ADR-040) that recomputes PATH from current cache state at every session start. Doesn't help mid-session refreshes but eliminates the stale-PATH-on-next-session pattern.

5. **Document the limitation** — amend `/install-updates` Step 5 prose to be explicit: "Restart REQUIRED to use the refreshed plugin code via shims in the same session. Without restart, shim invocations may still run the previous version." This is documentation-only; doesn't fix the structural gap but prevents the wasted-effort failure mode.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next `/wr-itil:review-problems` — likely HIGH given session-9 cost
- [ ] Investigate Claude Code's plugin-install internals — is the PATH-update path documented? Is there an API to refresh PATH from cache state?
- [ ] If option 3 (highest-version-wins wrapper) is viable, prototype on `@windyroad/architect` shim and dogfood for a session
- [ ] Document option 5 (explicit Step 5 amendment) as the immediate stopgap regardless of which long-term fix lands
- [ ] Sibling-check: does `/install-updates` Step 5 mention the PATH issue explicitly? If not, amend.
- [ ] Compose with P233 (post-release cache refresh in `/wr-itil:work-problems` Step 6.5) — same friction class manifests there

## Dependencies

- **Blocks**: trustworthy `/install-updates` semantics. Until PATH-refresh is part of the contract, "installed" doesn't mean "shims will run the new code in the current session".
- **Blocked by**: (none — workaround exists; structural fix is one of several SKILL/internal-tooling amendments).
- **Composes with**: P045 (auto plugin install after governance release; same install/PATH coupling), P106 (claude plugin install silent no-op when already installed; same plugin-cache-management surface), P233 (post-release cache refresh; same shim-recency assumption), P139 / `feedback_if_you_see_something_broken_fix_it` (this defect is exactly the class the rule catches).

## Related

(captured via /wr-itil:capture-problem 2026-05-31 during session 9 release drain after the test 2145 saga was diagnosed and resolved by bypassing PATH)

- **P045** — auto plugin install after governance release; sibling.
- **P106** — claude plugin install no-op when already installed; same surface.
- **P112** — non-atomic uninstall+install; same skill surface.
- **P233** — post-release cache refresh in work-problems Step 6.5; same shim-recency assumption.
- **P334** — sibling fix that introduced the ASCII vs Unicode divergence which exposed this defect.
- **P336** — sibling fix that exposed the same divergence at the YAML-parse surface.
- `scripts/repo-local-skills/install-updates/SKILL.md` Step 4 + Step 5 — amendment locus.
- `scripts/repo-local-skills/install-updates/REFERENCE.md` — additional context.

## Fix (2026-06-01 — Option 5 shipped; Known Error)

**Shipped: Option 5 (documentation amendment)** — `scripts/repo-local-skills/install-updates/SKILL.md` Step 5 "Next step" prose amended to explicitly name the PATH-stale-shim mechanism, make "Restart REQUIRED" non-optional language, document the absolute-path workaround for the current session without restart, and link this ticket as the captured-defect anchor. References section also gained a P343 entry.

Architect verdict: APPROVE — prose-only amendment is within ADR-030 (repo-local skills) and preserves P045 direction (no auto-restart); no new ADR required. JTBD-007 (keep-plugins-current) alignment confirmed — the post-refresh "Next step" prose is the maintainer's only signal that their refresh is incomplete without restart, so sharpening the prose closes the silent-failure-mode gap.

### Why Option 5 only, this iter

The ticket enumerated 5 candidates (lines 66–76 of original). Three are out:

- **Option 1 (restart-on-/install-updates)** — REJECTED per P045 direction 2026-04-20.
- **Option 2 (single-versioned shim path)** — upstream concern (Claude Code plugin-install internals); not in this repo's purview.
- **Option 5 (document the limitation)** — mechanical, in-scope, ships this iter.

Two remain as **direction-class outstanding questions** queued for the next human-attended planning surface:

1. **Option 3: highest-version-wins shim wrapper** — adopter-portable; replace each scaffold-template shim with a wrapper that resolves to the highest-version sibling in its parent cache directory. Bounded change in plugin scaffold templates (ADR-049 surface) but requires a new ADR because it adds runtime resolution logic to a contract that currently delegates resolution to PATH order.
2. **Option 4: SessionStart PATH refresh hook** — bounded but new hook; would recompute PATH from current cache state at every session start. Doesn't help mid-session refreshes but eliminates the stale-PATH-on-next-session pattern. Requires ADR for hook scope + per-plugin PATH-mutation semantics.

Either (or both) of 3/4 would close the structural gap fully; Option 5 documents the constraint so the user is no longer silently bitten. Re-rate at `/wr-itil:review-problems` once a structural fix lands; until then, the ticket stays at Known Error.

### Resolution Path Update (2026-06-02)

- **Option 3 (highest-version-wins shim wrapper)** — captured as **ADR-080** and substance-ratified 2026-06-02 via AskUserQuestion across 6 sub-decisions (SQ-080-1 through SQ-080-6: semver-sort resolution; fail-loud exit-127 on no cached versions; skip non-semver and use highest semver on malformed dir names; scaffold-template + retroactive patch all `@windyroad/*` plugins; synthetic-cache bats fixtures; ADR-080 STANDALONE per SQ-080-6). This is the structural fix path. Implementation has not yet shipped — ADR is `human-oversight: confirmed` substance lock only; implementation will follow via separate iterations.
- **Option 4 (SessionStart PATH refresh hook)** — captured as ADR-081 and **SUPERSEDED 2026-06-02** at the SQ-080-6 ratification surface. ADR-081 rejected before implementation; superseded by ADR-080. Reasoning: ADR-080's invoke-time wrapper resolves to the highest-version sibling regardless of PATH order, which makes the cache-state authoritative for shim binaries — the first shim invocation in a new session resolves to the highest-version sibling whether or not session-init populated PATH with a stale `bin/` first. This subsumes ADR-081's intended cold-start coverage for the dominant JTBD-007 surface (shim binaries). The narrow residual surface ADR-081 would still have covered is non-shim-wrapped binaries; not currently a JTBD-001/007 blocker. See `docs/decisions/081-sessionstart-path-refresh-hook-for-plugin-cache.rejected.md` § Rejection (2026-06-02).

Ticket remains **Known Error** until ADR-080's implementation ships and verifies in-session against P343's session-9 failure mode. Re-rate at `/wr-itil:review-problems` once the ADR-080 wrapper lands in each `@windyroad/*` plugin per SQ-080-4 retroactive-patch lock.

### Verification

- SKILL.md prose now states "Restart Claude Code REQUIRED" as the leading sentence (not just an aside).
- SKILL.md prose names the specific mechanism (PATH frozen at session-init, cache refresh does not mutate parent shell PATH).
- SKILL.md prose names a workaround for the current session without restart (absolute-path shim invocation).
- References section anchors P343.
- No behaviour change in install-updates Steps 1–4; no test changes required.
- `.claude/skills/install-updates/SKILL.md` symlink intact per ADR-030 / P139.
