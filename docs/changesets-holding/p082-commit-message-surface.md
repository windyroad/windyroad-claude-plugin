---
"@windyroad/voice-tone": patch
"@windyroad/risk-scorer": patch
---

P082 Phase 1: extends `external-comms-gate.sh` to intercept `git commit -m / --message` (including HEREDOC `$(cat <<'EOF'…EOF)` body form) as a fourth surface alongside the existing gh / npm / changeset surfaces. Commit messages reach `git log`, the GitHub PR commits tab, release-page auto-notes, CHANGELOG, and `git shortlog`. The voice-tone evaluator gates the message body for AI-tells, hedging, and banned-phrase drift; the risk evaluator gates for credential leaks and confidential-content patterns. Editor flow (bare `git commit`) is out of scope per P082 SC1: the message is written to `.git/COMMIT_EDITMSG` after PreToolUse fires, so the gate cannot read the body at firing time. Per-evaluator marker scheme reused unchanged (no new evaluator domain); Phase 2 cognitive-accessibility evaluator is captured separately as P338. Closes P082.
