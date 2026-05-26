---
"@windyroad/itil": patch
---

The changeset-discipline commit gate now recognises `docs/changesets-holding/<name>.md` entries as satisfying the gate, alongside `.changeset/<name>.md` (P177). Previously, committing `packages/<plugin>/` source whose changeset was intentionally held in the ADR-042 Rule 7 holding directory was denied — forcing a two-commit workaround (work commit, then a separate move-to-holding chore). A staged held-window entry is now an audit-trailed changeset the gate accepts, so held-window-bound work lands in a single commit. Release semantics are unchanged: the Release workflow still reads `.changeset/` only; a held entry is never drained without a graduation `git mv` back into `.changeset/`. The holding directory's `README.md` is excluded as a meta-doc, mirroring the `.changeset/README.md` exclusion.
