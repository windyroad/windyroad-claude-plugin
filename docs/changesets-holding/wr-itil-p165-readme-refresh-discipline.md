---
"@windyroad/itil": patch
---

P165: PreToolUse:Bash commit-gate hook (`itil-readme-refresh-discipline.sh`) denies `git commit` invocations whose staged set includes a `docs/problems/<state>/NNN-*.md` ticket change but does NOT also stage `docs/problems/README.md`. Closes the P094 / P062 README-refresh enforcement gap — declarative-only contract is now hook-enforced at commit time. Architectural sibling of P125 (staging-trap) + P141 (changeset-discipline). Recovery is mechanical (`git add docs/problems/README.md`) per ADR-013 Rule 1; `BYPASS_README_REFRESH_GATE=1` env override for legitimate narrative-only ticket edits.
