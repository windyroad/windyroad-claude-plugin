# Behavioural fixture 2: genuinely-new capture (PROCEED_NEW)

Validates that the agent does NOT spuriously fold a genuinely-new capture into a candidate just because the mechanical pre-filter surfaced one.

## Input 1: New capture description

```
The `claude plugin marketplace update` command silently caches plugin
metadata for 24 hours without surfacing the cache state in any UI. Adopters
attempting to refresh after a release wait 24h not knowing the cache is
serving stale data. Need a manual cache-bust flag or a TTL surface in the
marketplace command's output. Affects every adopter waiting on a release.
Verifiable by: invoke `claude plugin marketplace update` immediately after a
release; observe no version-bump surface; wait 24h; observe version bump.
```

## Input 2: Filtered candidate set

| Candidate | Title | Path | Matching signals |
|-----------|-------|------|------------------|
| P106 | `claude plugin install` is a silent no-op when already installed at any version | `docs/problems/open/106-...md` | shared `claude plugin` command surface; both touch the install/marketplace cache layer |

## Expected verdict

```
PROCEED_NEW

**Rationale**: P106's root cause is the `claude plugin install` command being
a no-op when already installed at any version (no version-equality check).
The new capture's root cause is a different surface: `claude plugin
marketplace update`'s opaque 24-hour metadata cache. The two share the
upstream "claude plugin marketplace cache layer" but operate at different
commands with different observable symptoms and different fix loci. Folding
the new capture into P106 would dilute P106's single-purpose anchor.

**Per-candidate explanation**:
- P106 (claude plugin install silent no-op) — different command (`install` vs
  `marketplace update`); different observable (no version bump on already-
  installed plugin vs no version bump because metadata cache is stale);
  different fix locus (per-project install logic vs marketplace metadata
  TTL/surfacing). Surface signals overlap (both touch the marketplace cache
  layer) but the captured friction is genuinely distinct.
```
