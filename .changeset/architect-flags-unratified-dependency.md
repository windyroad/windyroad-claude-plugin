---
"@windyroad/architect": patch
---

Architect flags changes built on an unratified ADR (ADR-074 surface 3, RFC-010, P318).

The architect review (every file edit + plans via review-design) now emits a new [Unratified Dependency] verdict: when a change or plan explicitly cites or implements an ADR that lacks `human-oversight: confirmed` (unratified, and not superseded), it reports ISSUES FOUND with the action "ratify it via /wr-architect:review-decisions before this lands."

- Keyed on the human-oversight marker, NOT on `status:` — building on a ratified ADR is fine even when its status is still `proposed` (status and oversight are orthogonal axes).
- The agent performs the read-only equivalent of the is-decision-unconfirmed predicate via a frontmatter-scoped marker grep (it has Read/Glob/Grep, no Bash).
- Bounded to explicit cite/implement (not transitive dependence); near-zero noise in steady state.
- Closes the residual gap where work built on an unratified decision outside the ITIL propose-fix surface went unflagged.
