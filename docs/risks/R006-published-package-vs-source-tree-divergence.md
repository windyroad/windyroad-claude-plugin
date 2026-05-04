# R006: Published-package references source-tree-only paths and IDs

Plugins are authored in a monorepo where SKILL.md / agent.md / hook prose can freely reference repo-only artefacts: `docs/decisions/NNN-...md`, `docs/problems/PNNN`, `docs/jtbd/<persona>/JTBD-NNN-...md`, `RISK-POLICY.md`, sibling `packages/<other-plugin>/scripts/foo.sh`. When the plugin is published to npm, only `packages/<this-plugin>/` ships in the tarball. Adopters install into their own project; the tarball extracts into their `~/.claude/plugins/cache/<org>/<plugin>/<version>/` tree, which contains ONLY the plugin's own files.

Three sub-classes:
- **Internal-ID leakage** (P137): published prose cites `ADR-049` / `JTBD-001` / `P137` as if universally meaningful. In an adopter's project, those IDs don't resolve at all (best case — agent ignores) or resolve to UNRELATED decisions/jobs in the adopter's own `docs/decisions/` (worst case — agent applies wrong semantics).
- **Repo-relative path leakage** (P151): published bash like `bash packages/itil/scripts/reconcile-readme.sh` resolves in the source repo but hard-fails at adopter installs.
- **Publish-manifest drift** (P154): a `bin/` shim exists in source but isn't in `package.json` `files` array → ships broken; source-tree-walking detectors miss this because the source has the shim.

## Controls

- **ADR-049 plugin-bundled scripts via `$PATH bin/`** — thin shim wrappers (`packages/<plugin>/bin/wr-<plugin>-<command>`) dispatch to canonical bodies. SKILL.md prose calls the shim by name; `$PATH` resolves at adopter install.
- **ADR-055 namespace-prefixed permalinks** — internal IDs in published prose use `@windyroad/<plugin>:` prefix so adopter agents recognise them as publisher-scope.
- **`packages/retrospective/scripts/check-namespace-prefix-leakage.sh`** — advisory detector at retro time.
- **P154 npm-pack-extension** — detector runs against `npm pack` tarball output, catching publish-manifest drift (e.g., missing `files` array entries).
- **`packages/<plugin>/package.json` `files` array curation** — explicit allowlist of paths to include in the tarball.

## Watch-out

- The three sub-classes have very different controls; map the report's specifics to the right sub-class:
  - hard-fail at Step 0 of a skill → repo-relative path → ADR-049 shim missing or unwrapped.
  - adopter agent applies mis-resolved ID → internal-ID → ADR-055 prefix missing.
  - bin shim missing in tarball but present in source → publish-manifest → `files` array gap, P154 detector.
- Production-shipped instance: `@windyroad/itil@0.23.2 → 0.24.0` shipped broken bin shims for ~5 versions before P154 detector caught it. Don't assume "we have ADR-049, we're safe" — file-array regression only surfaces in tarball, not source.
- Hook prose changes that ship under `patch` but actually shift behaviour belong here too — it's a published-surface boundary crossing under-classified.
