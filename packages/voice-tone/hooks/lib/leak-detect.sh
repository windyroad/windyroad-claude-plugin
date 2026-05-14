#!/bin/bash
# Hybrid leak-pattern pre-filter for external-comms-gate.sh (P064 / ADR-028 amended).
#
# Architecture (architect verdict — P064 iteration):
# - **Regex pre-filter** (this file) catches HIGH-CONFIDENCE leak shapes
#   (credentials, prod URL prefixes, money/revenue + financial-context tokens).
#   Hits deny immediately with a specific reason — no subagent round-trip.
# - **Subagent judgement** (wr-risk-scorer:external-comms) handles ambiguous
#   prose. Anything this filter does NOT match is delegated to the agent for
#   context-aware review against RISK-POLICY.md Confidential Information
#   classes (client names, project names, engagement details, internal
#   strategy/roadmap detail).
#
# Usage:
#   source lib/leak-detect.sh
#   if leak_detect_scan "$DRAFT"; then
#       # No high-confidence hit; delegate to subagent.
#   else
#       # Set $LEAK_DETECT_REASON; deny with that reason.
#   fi
#
# Returns 0 when the draft is CLEAN of high-confidence patterns.
# Returns 1 when a HARD-FAIL pattern is matched. $LEAK_DETECT_REASON
# is set to a one-line human-readable description of what matched.
#
# This is intentionally conservative — false negatives are expected and
# routed to the subagent. False positives here block the call entirely
# so the regex set must be high-specificity. Add new patterns only when
# the false-positive rate is verified low against representative drafts.

LEAK_DETECT_REASON=""

leak_detect_scan() {
    local draft="$1"
    LEAK_DETECT_REASON=""

    [ -z "$draft" ] && return 0

    # ---- Credentials (high confidence) ----

    # AWS access keys: AKIA prefix + 16 upper-alphanum chars.
    if echo "$draft" | grep -qE 'A''KIA[0-9A-Z]{16}'; then
        LEAK_DETECT_REASON="AWS access key pattern detected in draft"
        return 1
    fi

    # GitHub tokens: ghp_/ghs_/gho_/ghu_/ghr_ + 36+ url-safe chars.
    if echo "$draft" | grep -qE 'g''h[pousr]_[A-Za-z0-9_]{36,}'; then
        LEAK_DETECT_REASON="GitHub token pattern detected in draft"
        return 1
    fi

    # Private keys.
    if echo "$draft" | grep -qE 'BEGIN[[:space:]]+(RSA|DSA|EC|OPENSSH|PGP)?[[:space:]]*PRIVATE KEY'; then
        LEAK_DETECT_REASON="Private key block detected in draft"
        return 1
    fi

    # Bearer / Authorization headers with non-trivial value.
    if echo "$draft" | grep -qE '[Bb]earer[[:space:]]+[A-Za-z0-9_.-]{20,}'; then
        LEAK_DETECT_REASON="Bearer token detected in draft"
        return 1
    fi

    # Generic api_key / api_secret / auth_token assignments with literal value.
    if echo "$draft" | grep -qEi '(api_key|api_secret|auth_token|secret_key)[[:space:]]*[=:][[:space:]]*["\x27][A-Za-z0-9+/=_-]{16,}'; then
        LEAK_DETECT_REASON="API key/secret/token assignment detected in draft"
        return 1
    fi

    # ---- Confidential business metrics (RISK-POLICY.md) ----

    # Revenue / financial figures: $<digits><K|M|B>? near financial-context
    # keywords (ARR, MRR, revenue, profit). High-specificity to avoid catching
    # generic price strings ($5 widget) — requires a financial token nearby.
    if echo "$draft" | grep -qEi '\$[0-9]+([0-9.,]*)[KMB]?\b.{0,40}\b(ARR|MRR|revenue|profit|EBITDA|valuation)\b'; then
        LEAK_DETECT_REASON="Revenue/financial figure with business-context keyword detected"
        return 1
    fi
    if echo "$draft" | grep -qEi '\b(ARR|MRR|revenue|profit|EBITDA|valuation)\b.{0,40}\$[0-9]+([0-9.,]*)[KMB]?\b'; then
        LEAK_DETECT_REASON="Business-context keyword paired with revenue/financial figure detected"
        return 1
    fi

    # User counts with explicit unit-of-business: <digits><K|M> + (users|customers|MAU|DAU|signups).
    # Requires comma-formatted thousands or K/M suffix to skip "5 users tested this".
    if echo "$draft" | grep -qEi '\b[0-9]{1,3}(,[0-9]{3})+\s*(active\s+)?(users|customers|signups|MAU|DAU)\b'; then
        LEAK_DETECT_REASON="User-count with business-metric keyword detected"
        return 1
    fi
    if echo "$draft" | grep -qEi '\b[0-9]+[KMB]\s*(active\s+)?(users|customers|signups|MAU|DAU)\b'; then
        LEAK_DETECT_REASON="User-count (K/M/B suffix) with business-metric keyword detected"
        return 1
    fi

    # ---- Allowlist-bypass: signed/known-public marketing language is fine ----
    # No hits — signal CLEAN to the caller.
    return 0
}
