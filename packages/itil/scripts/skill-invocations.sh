#!/usr/bin/env bash
# packages/itil/scripts/skill-invocations.sh
#
# Phase 2a (P087) transcript-axis maturity-measurement script.
#
# Reads `~/.claude/projects/**/*.jsonl` (recursive), filters to
# `type=assistant` messages whose `message.content` array carries a
# `tool_use` entry, tallies invocations by `Skill` / `Agent` / `Bash` per
# ADR-058 §Script contracts, and emits one NDJSON record per surface to
# stdout.
#
# Schema (per ADR-058 line 70-82):
#   {"schema_version":"1.0","axis":"skill-invocations","surface":"<name>",
#    "kind":"skill|agent|bash-attributed","plugin":"<name>",
#    "window_days":<N>,"invocations":<N>,
#    "first_invocation_iso":"<ISO>","last_invocation_iso":"<ISO>"}
#
# Usage:
#   wr-itil-skill-invocations [--window-days=N] [--root=PATH]
#                              [--project-root=PATH]
#                              [--category-overrides=FILE]
#
# Defaults:
#   --window-days   30   (ADR-058 line 67)
#   --root          ~/.claude/projects
#   --project-root  $PWD   (opt-out marker location: <project-root>/.claude/.skill-metrics-opt-out)
#
# Exit codes:
#   0 = always — ADR-013 Rule 6 fail-safe. Opt-out marker / inaccessible
#                root / missing data all hit the zero-records path with
#                stderr-comment.
#
# Privacy (ADR-035 clauses adopted verbatim):
#   - Opt-out marker `.claude/.skill-metrics-opt-out` disables reads.
#   - No network egress — the script body invokes no exfiltration
#     primitives. ADR-058 §Confirmation 3 enforces via negative-grep
#     on this file (banned-token list lives in the bats fixture, not
#     here, to avoid self-matching).
#   - Content sanitisation — only fixed-pattern surface names extracted
#     via tight regex from tool inputs are emitted. Raw user content,
#     paths, and secrets are never copied to stdout.
#   - Path-hashing — if a path-bearing field is added in a future schema
#     version, values MUST be sha256-prefix-hashed (first 12 hex chars).
#     The v1.0 schema has no path-bearing field; the hashing function is
#     internal defence-in-depth, exercised structurally by Confirmation #4.
#
# @problem P087 (Phase 2a — transcript axis)
# @adr ADR-058 (Plugin maturity measurement mechanism)
# @adr ADR-049 (Shim grammar — bin/wr-itil-skill-invocations on $PATH)
# @adr ADR-035 (Privacy posture adopted verbatim)
# @adr ADR-052 (Behavioural tests default; ADR-058 §Confirmation 1-5)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — exit 0 always)
# @adr ADR-023 (Performance — < 1.5s warm-cache; 30-day window default)
# @jtbd JTBD-101 (Extend the Suite — hardening-prioritisation outcome,
#   2026-05-04 amendment serves Phase 2 NDJSON as data source)
# @jtbd JTBD-201 (Restore Service Fast — audit-trail composition)

set -uo pipefail

# ── CLI parse ───────────────────────────────────────────────────────────────

WINDOW_DAYS=30
TRANSCRIPT_ROOT="${HOME}/.claude/projects"
PROJECT_ROOT="$PWD"
CATEGORY_OVERRIDES=""

for arg in "$@"; do
  case "$arg" in
    --window-days=*) WINDOW_DAYS="${arg#--window-days=}" ;;
    --root=*)        TRANSCRIPT_ROOT="${arg#--root=}" ;;
    --project-root=*) PROJECT_ROOT="${arg#--project-root=}" ;;
    --category-overrides=*) CATEGORY_OVERRIDES="${arg#--category-overrides=}" ;;
    --help|-h)
      sed -n '4,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "# wr-itil-skill-invocations: ignoring unknown argument: $arg" >&2
      ;;
  esac
done

# ── Opt-out marker check (ADR-035 / ADR-058 §Privacy posture) ───────────────

OPT_OUT_MARKER="${PROJECT_ROOT}/.claude/.skill-metrics-opt-out"
if [ -e "$OPT_OUT_MARKER" ]; then
  echo "# wr-itil-skill-invocations: opt-out marker present at ${OPT_OUT_MARKER}" >&2
  exit 0
fi

# ── Transcript root accessibility (ADR-013 Rule 6 fail-safe) ────────────────

if [ ! -d "$TRANSCRIPT_ROOT" ]; then
  echo "# wr-itil-skill-invocations: transcript root inaccessible at ${TRANSCRIPT_ROOT}" >&2
  exit 0
fi

# ── --category-overrides validation (ADR-058 §Per-category override hook) ───
# Forward-extension flag; ships unused in Phase 2. Validated for path
# existence; not yet consumed by the body.

if [ -n "$CATEGORY_OVERRIDES" ] && [ ! -f "$CATEGORY_OVERRIDES" ]; then
  echo "# wr-itil-skill-invocations: category-overrides file not found: ${CATEGORY_OVERRIDES}" >&2
  exit 0
fi

# ── JSONL parse + NDJSON emit (Python 3 stdlib — ADR-058 line 127) ──────────
# Inputs pinned via environment to avoid argv leakage of secrets.

export SI_TRANSCRIPT_ROOT="$TRANSCRIPT_ROOT"
export SI_WINDOW_DAYS="$WINDOW_DAYS"

python3 - <<'PYEOF'
import json, os, sys, time, re, hashlib
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict

root = Path(os.environ["SI_TRANSCRIPT_ROOT"])
window_days = int(os.environ["SI_WINDOW_DAYS"])
now = time.time()
cutoff = now - window_days * 86400

# Bin shim grammar from ADR-049: wr-<plugin>-<kebab-script-name>.
# Anchor on word boundary; allow alnum + hyphens; non-greedy plugin token
# stops at the first hyphen so `wr-itil-reconcile-readme` attributes to
# `itil`, not `itil-reconcile`.
BIN_RE = re.compile(r"\bwr-([a-z0-9]+)-[a-z0-9-]+")

def plugin_from_skill(name):
    """`wr-itil:manage-problem` -> `itil`. Non-wr-prefixed or short-form
    names like `commit`, `loop` return None (excluded from per-plugin
    attribution per ADR-058 line 64)."""
    if not name or ":" not in name:
        return None
    prefix = name.split(":", 1)[0]
    if prefix.startswith("wr-"):
        return prefix[3:]
    return None

def plugin_from_agent(name):
    return plugin_from_skill(name)

def hash_path(p):
    """sha256-prefix-12hex per ADR-035 path-hashing convention. Reserved
    for future schema bumps that emit path-bearing fields; not consumed
    by the v1.0 schema."""
    return hashlib.sha256(str(p).encode("utf-8")).hexdigest()[:12]

# Aggregate keyed by (kind, surface).
counts = defaultdict(lambda: {"invocations": 0, "first": None, "last": None, "plugin": None})

try:
    jsonl_iter = root.rglob("*.jsonl")
except OSError:
    sys.exit(0)

for jsonl in jsonl_iter:
    try:
        st = jsonl.stat()
    except OSError:
        continue
    if st.st_mtime < cutoff:
        # File hasn't been touched in the window; skip without parsing.
        continue
    try:
        fh = jsonl.open("r", encoding="utf-8", errors="replace")
    except OSError:
        continue
    with fh:
        for line in fh:
            # Phase 2d (P087) substring pre-filter — skip json.loads() on lines
            # that cannot possibly contribute a count. The literal substring
            # `"tool_use"` is the discriminating token: every content block we
            # count carries `"type":"tool_use"`, while ~60% of in-window
            # transcript lines (user messages, tool_result blocks, snapshots,
            # title records) carry no `"tool_use"` value at all. The check is
            # whitespace-robust because `"tool_use"` is a string value, not a
            # key:value pair — compact-JSON (`"type":"tool_use"`) and
            # pretty-JSON (`"type": "tool_use"`) both contain the literal
            # token verbatim. False-positives (content-body prose containing
            # the substring) fall through to full parse and the existing
            # `c.get("type") == "tool_use"` content-block check excludes them.
            # The "false-positive substring fall-through" bats fixture pins
            # this invariant.
            if '"tool_use"' not in line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if not isinstance(rec, dict) or rec.get("type") != "assistant":
                continue

            # Per-message timestamp filter (more accurate than file mtime).
            ts = rec.get("timestamp")
            ts_iso = None
            if ts:
                try:
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    if dt.timestamp() < cutoff:
                        continue
                    ts_iso = dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                except Exception:
                    ts_iso = None

            msg = rec.get("message") or {}
            content = msg.get("content") if isinstance(msg, dict) else None
            if not isinstance(content, list):
                continue

            for c in content:
                if not isinstance(c, dict) or c.get("type") != "tool_use":
                    continue
                name = c.get("name")
                inp = c.get("input") if isinstance(c.get("input"), dict) else {}
                surface = kind = plugin = None

                if name == "Skill":
                    sk = inp.get("skill")
                    p = plugin_from_skill(sk)
                    if p:
                        surface, kind, plugin = sk, "skill", p
                elif name == "Agent":
                    sub = inp.get("subagent_type")
                    p = plugin_from_agent(sub)
                    if p:
                        surface, kind, plugin = sub, "agent", p
                elif name == "Bash":
                    cmd = inp.get("command", "")
                    if not isinstance(cmd, str):
                        continue
                    m = BIN_RE.search(cmd)
                    if m:
                        # Surface is the matched bin shim token only. The
                        # surrounding command (paths, secrets, args) is
                        # discarded — content-sanitisation per ADR-035.
                        surface = m.group(0)
                        kind = "bash-attributed"
                        plugin = m.group(1)

                if surface and kind and plugin:
                    key = (kind, surface)
                    info = counts[key]
                    info["invocations"] += 1
                    info["plugin"] = plugin
                    if ts_iso:
                        if info["first"] is None or ts_iso < info["first"]:
                            info["first"] = ts_iso
                        if info["last"] is None or ts_iso > info["last"]:
                            info["last"] = ts_iso

# Deterministic output order: sort by kind, then surface.
for key in sorted(counts.keys()):
    kind, surface = key
    info = counts[key]
    record = {
        "schema_version": "1.0",
        "axis": "skill-invocations",
        "surface": surface,
        "kind": kind,
        "plugin": info["plugin"],
        "window_days": window_days,
        "invocations": info["invocations"],
        "first_invocation_iso": info["first"],
        "last_invocation_iso": info["last"],
    }
    sys.stdout.write(json.dumps(record, separators=(",", ":")) + "\n")
PYEOF

exit 0
