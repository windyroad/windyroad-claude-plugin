#!/usr/bin/env bash
# packages/itil/scripts/plugin-maturity-populate.sh
#
# Phase 3a (P087) plugin-maturity population script.
#
# Reads two Phase 2 NDJSON streams — `wr-itil-skill-invocations` output
# (transcript-axis) + `wr-itil-plugin-exercise-index` output (git-axis) —
# applies ADR-053 §promotion criteria + §Bootstrapping clause, and writes
# the `maturity:` field per surface and per plugin root into each
# `packages/<plugin>/.claude-plugin/plugin.json`. Idempotent: re-running
# with unchanged inputs and a pinned `--now=` produces byte-identical
# plugin.json output.
#
# Plugin.json schema extension (ADR-063 §plugin.json field schema):
#   {
#     "name": "wr-<plugin>",
#     "version": "...",
#     "description": "...",
#     "maturity": {"schema_version": "1.0", "band": "<Band>"},
#     "skills":   {"<name>": {"maturity": {...rich record...}}},
#     "agents":   {"<name>": {"maturity": {...rich record...}}},
#     "hooks":    {"<name>": {"maturity": {...rich record with null inv...}}},
#     "commands": {"<name>": {"maturity": {...rich record...}}}
#   }
#
# Per-surface rich record:
#   {
#     "schema_version": "1.0",
#     "band": "Experimental|Alpha|Beta|Stable|Deprecated",
#     "computed_at": "<ISO>",
#     "evidence": {
#       "invocations_30d": <int|null>,    # null for hooks (architect §C)
#       "days_shipped": <int>,
#       "closed_tickets_window": <int>,
#       "breaking_change_age_days": <int|null>
#     }
#   }
# Deprecated band entries additionally carry "supersededBy": "<pointer>"
# and are preserved across re-runs — Phase 3a never overwrites a
# Deprecated record (architect §I).
#
# Surface-key normalisation table (architect §B + §F):
#   skill   → Phase 2 NDJSON key `wr-<plugin>:<dir-name>`; filesystem
#             `packages/<plugin>/skills/<dir-name>/`
#   agent   → Phase 2 NDJSON key `wr-<plugin>:<basename-without-.md>`;
#             filesystem `packages/<plugin>/agents/<basename>.md`
#   hook    → Phase 2 NDJSON not transcript-observable (harness-fired);
#             filesystem `packages/<plugin>/hooks/<basename>.sh`
#             — invocations_30d sentinel `null`, band derived from git axis
#   command → Phase 2 NDJSON key `wr-<plugin>:<basename-without-.md>`;
#             filesystem `packages/<plugin>/commands/<basename>.md`
#
# Plugin-name attribution (architect §F): the plugin.json `name` field is
# prefixed `wr-<plugin>`, but Phase 2 NDJSON `plugin:` field is bare
# (`<plugin>`). This script keys by filesystem path discovery
# (`packages/<bare-name>/`) and accepts bare-form NDJSON input — no
# plugin.json `name`-matching required.
#
# Bootstrapping clause (ADR-053 §Bootstrapping clause):
#   Active iff `max(days_shipped across plugins) < 60`. Sunset auto-
#   derives from the data (architect §D — no hard-coded calendar date).
#   Under bootstrapping: default = Experimental; provisional Alpha iff
#   invocations_30d ≥ 100 AND days_shipped ≥ 14. Hooks (null invocations)
#   stay Experimental during bootstrapping — provisional-Alpha rule
#   requires a numeric invocation count.
#
# Steady-state thresholds (ADR-053 §promotion criteria, post-sunset):
#   Experimental: days <14 OR invocations <10 OR tickets <3
#   Alpha:        days 14–60 AND inv 10–100 AND tickets 3–10
#   Beta:         days ≥60 AND inv ≥100 AND tickets ≥10 AND breaking ≥30
#                 (or null)
#   Stable:       days ≥180 AND inv ≥1000 AND breaking ≥90 (or null)
#   Deprecated:   author-declared; preserved across re-runs.
#
# ADR-044 silent-framework carve-out (scope-limited per ADR-063 §scope):
#   Band recomputation is mechanical, policy-resolved. No `AskUserQuestion`
#   per band recompute. The carve-out does NOT cover author-declared
#   Deprecated assignment, `supersededBy:` authoring, or Phase 4+ gate
#   threshold tuning — those remain AskUserQuestion-eligible per ADR-013
#   Rule 1.
#
# Usage:
#   wr-itil-plugin-maturity-populate
#     [--transcript-ndjson=FILE]    # default: invoke wr-itil-skill-invocations
#     [--exercise-ndjson=FILE]      # default: invoke wr-itil-plugin-exercise-index
#     [--project-root=PATH]         # default: $PWD
#     [--now=ISO]                   # default: current UTC time
#     [--dry-run]                   # print diff to stdout, do not write
#
# Exit codes:
#   0 = always — ADR-013 Rule 6 fail-safe. Missing NDJSON inputs / no
#                packages/ / opt-out marker all hit the no-write stderr-
#                comment path.
#
# Privacy (ADR-035 clauses adopted verbatim):
#   - Opt-out marker `.claude/.skill-metrics-opt-out` disables writes.
#   - No network egress — the script body invokes no exfiltration
#     primitives. Negative-grep enforcement lives in the bats fixture.
#
# @problem P237 (Phase 3a — population script)
# @problem P087 (parent — no maturity signal on plugin features)
# @adr ADR-063 (Plugin maturity presentation layer — Phase 3a contract)
# @adr ADR-053 (Plugin maturity taxonomy — promotion criteria +
#   Bootstrapping clause)
# @adr ADR-058 (Phase 2 NDJSON measurement — input shape)
# @adr ADR-049 (Shim grammar — `wr-itil-plugin-maturity-populate` on $PATH)
# @adr ADR-035 (Privacy posture — opt-out marker, no network primitive)
# @adr ADR-044 (Decision delegation — silent-framework carve-out)
# @adr ADR-052 (Behavioural tests default)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — exit 0 always)
# @jtbd JTBD-201 (Restore Service Fast — rich-record evidence block IS the
#   durable audit-trail surface at the canonical record)
# @jtbd JTBD-101 (Extend the Suite — band-derivation persists Phase 2
#   transient NDJSON signal as durable plugin.json field)

set -uo pipefail

# ── CLI parse ───────────────────────────────────────────────────────────────

TRANSCRIPT_NDJSON=""
EXERCISE_NDJSON=""
PROJECT_ROOT="$PWD"
NOW_ISO=""
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --transcript-ndjson=*) TRANSCRIPT_NDJSON="${arg#--transcript-ndjson=}" ;;
    --exercise-ndjson=*)   EXERCISE_NDJSON="${arg#--exercise-ndjson=}" ;;
    --project-root=*)      PROJECT_ROOT="${arg#--project-root=}" ;;
    --now=*)               NOW_ISO="${arg#--now=}" ;;
    --dry-run)             DRY_RUN=1 ;;
    --help|-h)
      sed -n '4,90p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "# wr-itil-plugin-maturity-populate: ignoring unknown argument: $arg" >&2
      ;;
  esac
done

# ── Opt-out marker check (ADR-035 / ADR-058 §Privacy posture) ───────────────

OPT_OUT_MARKER="${PROJECT_ROOT}/.claude/.skill-metrics-opt-out"
if [ -e "$OPT_OUT_MARKER" ]; then
  echo "# wr-itil-plugin-maturity-populate: opt-out marker present at ${OPT_OUT_MARKER}" >&2
  exit 0
fi

# ── packages/ discovery check (ADR-013 Rule 6 fail-safe) ────────────────────

if [ ! -d "${PROJECT_ROOT}/packages" ]; then
  echo "# wr-itil-plugin-maturity-populate: no packages/ directory at ${PROJECT_ROOT}" >&2
  exit 0
fi

# ── Python body ─────────────────────────────────────────────────────────────
# Inputs pinned via environment to avoid argv leakage.

export PMP_TRANSCRIPT_NDJSON="$TRANSCRIPT_NDJSON"
export PMP_EXERCISE_NDJSON="$EXERCISE_NDJSON"
export PMP_PROJECT_ROOT="$PROJECT_ROOT"
export PMP_NOW_ISO="$NOW_ISO"
export PMP_DRY_RUN="$DRY_RUN"

python3 - <<'PYEOF'
import json, os, sys
from pathlib import Path
from datetime import datetime, timezone

project_root = Path(os.environ["PMP_PROJECT_ROOT"]).resolve()
transcript_ndjson = os.environ.get("PMP_TRANSCRIPT_NDJSON", "")
exercise_ndjson = os.environ.get("PMP_EXERCISE_NDJSON", "")
now_iso = os.environ.get("PMP_NOW_ISO", "")
dry_run = os.environ.get("PMP_DRY_RUN", "0") == "1"

# ── Resolve `now` ──────────────────────────────────────────────────────────
# `--now=ISO` testability override (architect §H — pin across idempotency
# fixtures so byte-equality holds without field-exclusion logic).
if now_iso:
    try:
        now_dt = datetime.fromisoformat(now_iso.replace("Z", "+00:00"))
    except Exception:
        print(f"# wr-itil-plugin-maturity-populate: invalid --now={now_iso!r}, using current time", file=sys.stderr)
        now_dt = datetime.now(timezone.utc)
else:
    now_dt = datetime.now(timezone.utc)
now_canonical_iso = now_dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# ── Load NDJSON inputs (fail-soft on missing/unreadable) ───────────────────

def load_ndjson(path):
    """Read NDJSON, returning list of records. Missing/unreadable -> []."""
    if not path:
        return []
    p = Path(path)
    if not p.is_file():
        print(f"# wr-itil-plugin-maturity-populate: NDJSON input not found: {path}", file=sys.stderr)
        return []
    records = []
    try:
        with p.open("r", encoding="utf-8", errors="replace") as fh:
            for raw_line in fh:
                line = raw_line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                if isinstance(rec, dict):
                    records.append(rec)
    except OSError:
        pass
    return records

transcript_records = load_ndjson(transcript_ndjson)
exercise_records = load_ndjson(exercise_ndjson)

# Index transcript by (kind, surface) -> invocations.
# Phase 2a NDJSON `surface` keys:
#   skill   -> "wr-<plugin>:<skill-name>"
#   agent   -> "wr-<plugin>:<agent-name>"  (default "agent")
#   bash    -> "wr-<plugin>-<bin-name>"
inv_by_surface = {}
for r in transcript_records:
    kind = r.get("kind")
    surface = r.get("surface")
    inv = r.get("invocations")
    if not surface or not isinstance(inv, int):
        continue
    inv_by_surface[(kind, surface)] = inv

# Index exercise by plugin (bare name, e.g. "itil").
exercise_by_plugin = {}
for r in exercise_records:
    plug = r.get("plugin")
    if not plug:
        continue
    exercise_by_plugin[plug] = {
        "days_shipped": int(r.get("days_shipped", 0) or 0),
        "closed_tickets_window": int(r.get("closed_tickets_window", 0) or 0),
        "breaking_change_age_days": r.get("breaking_change_age_days"),
    }

# ── Bootstrapping window sunset auto-derivation (architect §D) ─────────────
# Active iff max(days_shipped across plugins) < 60. No calendar-date
# hard-code; the data alone determines the lapse.

if exercise_by_plugin:
    suite_oldest_days = max(v["days_shipped"] for v in exercise_by_plugin.values())
else:
    suite_oldest_days = 0
bootstrapping_active = suite_oldest_days < 60

# ── Plugin discovery (filesystem) ──────────────────────────────────────────

packages_dir = project_root / "packages"
plugin_dirs = sorted(
    [d for d in packages_dir.iterdir() if d.is_dir() and (d / ".claude-plugin" / "plugin.json").is_file()]
)
if not plugin_dirs:
    print("# wr-itil-plugin-maturity-populate: no plugins under packages/", file=sys.stderr)
    sys.exit(0)

# ── Surface inventory (filesystem) ─────────────────────────────────────────

def discover_surfaces(pkg_dir):
    """Returns dict[kind] -> sorted list of surface names."""
    out = {"skill": [], "agent": [], "hook": [], "command": []}
    # Skills: packages/<plugin>/skills/<name>/SKILL.md or just the dir.
    skills_dir = pkg_dir / "skills"
    if skills_dir.is_dir():
        out["skill"] = sorted(d.name for d in skills_dir.iterdir() if d.is_dir())
    # Agents: packages/<plugin>/agents/<name>.md (excludes test/).
    agents_dir = pkg_dir / "agents"
    if agents_dir.is_dir():
        out["agent"] = sorted(f.stem for f in agents_dir.glob("*.md") if f.is_file())
    # Hooks: packages/<plugin>/hooks/<name>.sh (excludes lib/, test/).
    hooks_dir = pkg_dir / "hooks"
    if hooks_dir.is_dir():
        out["hook"] = sorted(f.stem for f in hooks_dir.glob("*.sh") if f.is_file())
    # Commands: packages/<plugin>/commands/<name>.md.
    commands_dir = pkg_dir / "commands"
    if commands_dir.is_dir():
        out["command"] = sorted(f.stem for f in commands_dir.glob("*.md") if f.is_file())
    return out

# ── Band-mapping (ADR-053 §promotion criteria + §Bootstrapping clause) ─────

# Band ordering, worst-first. "Deprecated" is an overlay axis (ADR-053
# §granularity contract line 109) — elided from the rollup computation but
# retained on individual surface entries. Worst-case rollup compares only
# {Experimental, Alpha, Beta, Stable}.
BAND_ORDER = ["Experimental", "Alpha", "Beta", "Stable"]

def compute_band(evidence):
    """Map a per-surface evidence record -> band per ADR-053.

    - During bootstrapping (suite-oldest < 60d): default Experimental;
      provisional Alpha iff invocations_30d >= 100 AND days_shipped >= 14.
      Hooks (invocations_30d=None) stay Experimental — the provisional
      rule requires a numeric invocation count.
    - Steady-state (post-sunset): AND-gated bands per the strawman.
    """
    inv = evidence.get("invocations_30d")
    days = evidence.get("days_shipped", 0)
    tickets = evidence.get("closed_tickets_window", 0)
    breaking = evidence.get("breaking_change_age_days")  # None or int

    if bootstrapping_active:
        # Provisional Alpha rule (ADR-053 §Bootstrapping clause line 86).
        if isinstance(inv, int) and inv >= 100 and days >= 14:
            return "Alpha"
        return "Experimental"

    # Steady-state. Hooks (None invocations) cannot meet inv-gated floors,
    # so they stay Experimental — consistent with the bootstrapping rule.
    inv_val = inv if isinstance(inv, int) else 0

    # Stable floor.
    stable_breaking_ok = (breaking is None) or (isinstance(breaking, int) and breaking >= 90)
    if days >= 180 and inv_val >= 1000 and stable_breaking_ok:
        return "Stable"
    # Beta floor.
    beta_breaking_ok = (breaking is None) or (isinstance(breaking, int) and breaking >= 30)
    if days >= 60 and inv_val >= 100 and tickets >= 10 and beta_breaking_ok:
        return "Beta"
    # Alpha floor.
    if 14 <= days < 60 and 10 <= inv_val < 100 and 3 <= tickets <= 10:
        return "Alpha"
    return "Experimental"

def rollup_band(surface_bands):
    """Worst-case across non-Deprecated bands; Deprecated entries elided.
    A plugin whose ONLY surfaces are Deprecated is itself Deprecated.
    """
    non_dep = [b for b in surface_bands if b in BAND_ORDER]
    if non_dep:
        for band in BAND_ORDER:
            if band in non_dep:
                return band
        return "Stable"
    if surface_bands and all(b == "Deprecated" for b in surface_bands):
        return "Deprecated"
    return None

# ── Per-plugin write loop ──────────────────────────────────────────────────

def lookup_invocations(plugin_bare, kind, name):
    """Return invocations_30d for a (plugin, kind, name) tuple.
    Hooks are not transcript-observable -> None (sentinel for "n/a").
    """
    if kind == "hook":
        return None
    surface = f"wr-{plugin_bare}:{name}"
    return inv_by_surface.get((kind, surface), 0)

def build_surface_record(existing, kind, plugin_bare, name, evidence):
    """Construct the new maturity record for a surface, respecting the
    Deprecated-overlay invariant (architect §I + ADR-053 #6 / #102):
    if existing band is Deprecated, return existing record VERBATIM —
    do NOT recompute, do NOT update computed_at, do NOT overwrite
    supersededBy. All other records get a fresh recompute.
    """
    existing_maturity = existing.get("maturity") if isinstance(existing, dict) else None
    if isinstance(existing_maturity, dict) and existing_maturity.get("band") == "Deprecated":
        return existing_maturity

    band = compute_band(evidence)
    record = {
        "schema_version": "1.0",
        "band": band,
        "computed_at": now_canonical_iso,
        "evidence": {
            "invocations_30d": evidence["invocations_30d"],
            "days_shipped": evidence["days_shipped"],
            "closed_tickets_window": evidence["closed_tickets_window"],
            "breaking_change_age_days": evidence["breaking_change_age_days"],
        },
    }
    return record

wrote_records = 0
unchanged_records = 0
total_plugins = 0

for pkg_dir in plugin_dirs:
    plugin_bare = pkg_dir.name
    plugin_json_path = pkg_dir / ".claude-plugin" / "plugin.json"
    try:
        plugin_doc = json.loads(plugin_json_path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"# wr-itil-plugin-maturity-populate: skipping unreadable plugin.json at {plugin_json_path}: {exc}", file=sys.stderr)
        continue
    if not isinstance(plugin_doc, dict):
        continue

    exercise = exercise_by_plugin.get(plugin_bare, {
        "days_shipped": 0,
        "closed_tickets_window": 0,
        "breaking_change_age_days": None,
    })

    surfaces = discover_surfaces(pkg_dir)
    total_plugins += 1

    # Per-kind surface maps.
    kind_to_key = {"skill": "skills", "agent": "agents", "hook": "hooks", "command": "commands"}
    surface_bands_for_rollup = []

    for kind, names in surfaces.items():
        if not names:
            continue
        key = kind_to_key[kind]
        existing_map = plugin_doc.get(key, {})
        if not isinstance(existing_map, dict):
            existing_map = {}
        new_map = {}
        for name in names:
            existing_entry = existing_map.get(name, {}) if isinstance(existing_map.get(name), dict) else {}
            evidence = {
                "invocations_30d": lookup_invocations(plugin_bare, kind, name),
                "days_shipped": exercise["days_shipped"],
                "closed_tickets_window": exercise["closed_tickets_window"],
                "breaking_change_age_days": exercise["breaking_change_age_days"],
            }
            maturity_record = build_surface_record(existing_entry, kind, plugin_bare, name, evidence)
            # Preserve any extra keys on the existing entry (forward-compat).
            merged_entry = dict(existing_entry)
            merged_entry["maturity"] = maturity_record
            new_map[name] = merged_entry
            surface_bands_for_rollup.append(maturity_record.get("band"))
        plugin_doc[key] = new_map
        wrote_records += len(new_map)

    # Plugin root rollup (ADR-063 §rollup schema: schema_version + band only).
    rollup = rollup_band(surface_bands_for_rollup)
    if rollup is not None:
        plugin_doc["maturity"] = {"schema_version": "1.0", "band": rollup}
    else:
        # Plugin with no shipped surfaces -> no plugin-level maturity field
        # (ADR-053 §granularity contract line 110).
        plugin_doc.pop("maturity", None)

    # Serialise canonically: sorted keys + 2-space indent. Idempotency
    # depends on this stability (architect §H).
    new_text = json.dumps(plugin_doc, indent=2, sort_keys=True) + "\n"
    old_text = plugin_json_path.read_text(encoding="utf-8")

    if new_text == old_text:
        unchanged_records += 1
        continue

    if dry_run:
        sys.stdout.write(f"--- {plugin_json_path}\n+++ would-write\n")
        sys.stdout.write(new_text)
        sys.stdout.write("\n")
    else:
        plugin_json_path.write_text(new_text, encoding="utf-8")

# ── Operator-facing freshness summary on stderr (JTBD-007 currency aid) ────
# Non-load-bearing; cheap operator-comfort signal per JTBD review §4.

print(
    f"# wr-itil-plugin-maturity-populate: "
    f"plugins={total_plugins} surfaces_written={wrote_records} "
    f"unchanged_plugins={unchanged_records} "
    f"bootstrapping={'active' if bootstrapping_active else 'inactive'} "
    f"suite_oldest_days={suite_oldest_days} "
    f"computed_at={now_canonical_iso}",
    file=sys.stderr,
)
PYEOF

exit 0
