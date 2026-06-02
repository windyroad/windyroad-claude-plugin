---
status: "proposed"
date: 2026-06-02
decision-makers: [unspecified — fill at canonical review]
consulted: []
informed: []
reassessment-date: 2026-09-02
---

# Highest-version-wins shim wrapper for plugin scaffold-template shims

> Captured via /wr-architect:capture-adr (foreground-lightweight aside-invocation per ADR-032 P156 amendment). Run /wr-architect:create-adr on this ID to expand the deferred sections canonically.

## Context and Problem Statement

P343 — `/install-updates` refreshes the plugin cache but does NOT mutate the parent shell's PATH; stale plugin-version shims remain first on PATH and run old code after refresh (workaround is per-invocation absolute-path; session-9 cost ~3hr release + $130 budget).

## Decision Drivers

- (deferred to /wr-architect:create-adr canonical review)

## Considered Options

1. **Option A (chosen)** — Replace each plugin scaffold-template shim with a wrapper script that, at invoke time, resolves to the highest-version sibling in its parent cache directory (`~/.claude/plugins/cache/<owner>/<plugin>/<latest>/bin/<shim>`).
2. (deferred — see /wr-architect:create-adr canonical review)

## Decision Outcome

Chosen option: **"Option A"**, because replacing each plugin scaffold-template shim with a wrapper script that, at invoke time, resolves to the highest-version sibling in its parent cache directory makes shim invocations always run the newest cached version regardless of PATH ordering. This is a bounded change in plugin scaffold templates (ADR-049 surface) and closes the mid-session staleness window that the sibling Option 4 (SessionStart PATH refresh) does not cover.

## Consequences

### Good

- (deferred to /wr-architect:create-adr canonical review)

### Neutral

- (deferred to /wr-architect:create-adr canonical review)

### Bad

- (deferred to /wr-architect:create-adr canonical review)

## Confirmation

(deferred to /wr-architect:create-adr canonical review)

## Pros and Cons of the Options

### Option A

- (deferred to /wr-architect:create-adr canonical review)

## Reassessment Criteria

(deferred to /wr-architect:create-adr canonical review — default reassessment-date 3 months from capture)

## Related

- **P343** (Known Error) — driving problem ticket; Option 3 in P343 § Root Cause Analysis.
- **ADR-049** — plugin-script-resolution-via-bin-on-path — the surface this ADR amends (shim layout).
- **ADR-080's sibling** — capture-adr for P343 Option 4 (SessionStart PATH refresh hook) lands as ADR-081 in the same iter; the two compose (this ADR covers mid-session staleness; ADR-081 covers cold-start).
- **P045** — auto plugin install after governance release; same install/PATH coupling.
- **P106** — `claude plugin install` silent no-op when already installed; same plugin-cache-management surface.
