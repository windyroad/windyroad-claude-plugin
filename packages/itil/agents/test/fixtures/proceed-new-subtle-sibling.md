# Behavioural fixture 3: subtle sibling-vs-parent (PROCEED_NEW with reasoned rationale)

Validates that the agent reasons cleanly about sibling-vs-parent shape — two tickets sharing surface signals where neither is the other's parent.

## Input 1: New capture description

```
`/wr-itil:report-upstream` SKILL.md surface — the report-upstream skill's
generated GitHub issue body sometimes carries our internal P<NNN> ticket IDs
verbatim instead of stripping them. Adopters reporting upstream see opaque
references they can't resolve. Should redact internal IDs before posting or
include a "for our records" footer separating internal vs upstream
references. Affects every outbound issue from /wr-itil:report-upstream.
```

## Input 2: Filtered candidate set

| Candidate | Title | Path | Matching signals |
|-----------|-------|------|------------------|
| P070 | `/wr-itil:report-upstream` doesn't deduplicate against existing upstream issues | `docs/problems/verifying/070-...md` | shared `/wr-itil:report-upstream` SKILL reference; both about outbound surfaces on the same SKILL |

## Expected verdict

```
PROCEED_NEW

**Rationale**: P070's root cause is the report-upstream SKILL not checking
the upstream repo for an existing issue before posting (deduplication gap).
The new capture's root cause is the report-upstream SKILL leaking
maintainer-internal P<NNN> references in the generated issue body (privacy /
adopter-confusion gap). The two are siblings — both surface on
`/wr-itil:report-upstream`'s outbound generation flow — but neither is the
other's parent. The shared SKILL surface is coincidental; the fix loci are
distinct (upstream-repo-state lookup vs body-text scrubbing). P070's scope
does not name internal-ID-leakage as deferred follow-up. Recommend
PROCEED_NEW; let `/wr-itil:review-problems` cluster them as sibling-class at
the next cluster pass if a common parent emerges.

**Per-candidate explanation**:
- P070 (report-upstream deduplication gap) — same SKILL surface, but
  different observable (duplicate upstream issues vs leaked internal IDs in
  the body), different fix locus (gh API state lookup vs string scrubbing on
  the body template), different lifecycle stage (P070 is Verifying with a
  shipping fix; the new capture is fresh discovery on a different code
  surface in the same file). Folding would dilute P070's single-purpose
  anchor and force its Verifying transition to wait on un-related work.
```
