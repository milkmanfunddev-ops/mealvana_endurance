#!/usr/bin/env bash
# Fetch Supabase edge function logs via the Management API analytics endpoint.
#
# Why this script exists:
#   The Supabase CLI has no `functions logs` subcommand. The dashboard's logs
#   view is backed by an analytics endpoint that accepts BigQuery-style SQL —
#   this script wraps it so we don't have to remember the URL params, the
#   required iso_timestamp_start/end window, or the SELECT-* restriction.
#
# Requirements:
#   - $SUPABASE_PAT env var, OR a single-line PAT in ~/.supabase/pat
#   - python3 (for urlencode + JSON pretty-print)
#
# Usage:
#   ./scripts/edge_logs.sh                       # last 30min, function_logs (console.log)
#   ./scripts/edge_logs.sh PLAN-V3               # filter event_message LIKE '%PLAN-V3%'
#   ./scripts/edge_logs.sh -m 5 PLAN-V3          # last 5 minutes
#   ./scripts/edge_logs.sh -m 60 -l 200 PIN      # 1hr window, up to 200 rows
#   ./scripts/edge_logs.sh -s function_edge_logs # request-level logs (POST | 200 | url)
#   ./scripts/edge_logs.sh -p PROJECT_REF        # override project (default: dev)
#   ./scripts/edge_logs.sh --raw PLAN-V3         # print raw JSON instead of formatted lines
#
# Notes:
#   - Default project ref points to dev (vlmtsdzpnjnavdgytcmi). Override with -p.
#   - Source tables: function_logs (console.log), function_edge_logs (request
#     boot/response), edge_logs (postgrest/general).
#   - Timestamp is rendered in local time. The raw value is microseconds-epoch.

set -euo pipefail

# ---- Defaults ---------------------------------------------------------------
PROJECT_REF="vlmtsdzpnjnavdgytcmi"
MINUTES=30
LIMIT=100
SOURCE="function_logs"
RAW=0
PATTERN=""

# ---- Arg parsing ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--minutes)  MINUTES="$2"; shift 2 ;;
    -l|--limit)    LIMIT="$2"; shift 2 ;;
    -s|--source)   SOURCE="$2"; shift 2 ;;
    -p|--project)  PROJECT_REF="$2"; shift 2 ;;
    --raw)         RAW=1; shift ;;
    -h|--help)
      awk '/^# / { sub(/^# ?/, ""); print; next } /^#$/ { print ""; next } NR>1 { exit }' "$0"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      PATTERN="$1"; shift ;;
  esac
done

# ---- Auth -------------------------------------------------------------------
if [[ -z "${SUPABASE_PAT:-}" ]]; then
  if [[ -r "$HOME/.supabase/pat" ]]; then
    SUPABASE_PAT="$(tr -d '[:space:]' < "$HOME/.supabase/pat")"
  else
    echo "error: set \$SUPABASE_PAT or put a PAT in ~/.supabase/pat" >&2
    exit 1
  fi
fi

# ---- Build SQL --------------------------------------------------------------
WHERE=""
if [[ -n "$PATTERN" ]]; then
  ESCAPED_PATTERN="${PATTERN//\'/\'\'}"
  WHERE="where event_message like '%${ESCAPED_PATTERN}%'"
fi
SQL="select timestamp, event_message from ${SOURCE} ${WHERE} order by timestamp desc limit ${LIMIT}"

# ---- Time window (REQUIRED — empty results without these) -------------------
START=$(date -u -v-"${MINUTES}"M +"%Y-%m-%dT%H:%M:%SZ")
END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ---- URL-encode SQL ---------------------------------------------------------
ENCODED_SQL=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$SQL")

URL="https://api.supabase.com/v1/projects/${PROJECT_REF}/analytics/endpoints/logs.all?sql=${ENCODED_SQL}&iso_timestamp_start=${START}&iso_timestamp_end=${END}"

# ---- Fetch ------------------------------------------------------------------
RESPONSE=$(curl -s -H "Authorization: Bearer ${SUPABASE_PAT}" "$URL")

# ---- Format -----------------------------------------------------------------
if [[ "$RAW" == "1" ]]; then
  echo "$RESPONSE" | python3 -m json.tool
  exit 0
fi

# Pretty-print: oldest-first, local-time prefix, message trimmed of trailing \n
RESPONSE="$RESPONSE" python3 <<'PY'
import json, os, sys, datetime
raw = os.environ.get("RESPONSE", "")
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    print(f"error: non-JSON response: {raw[:300]}", file=sys.stderr)
    sys.exit(1)
if data.get("error"):
    print(f"error: {data['error']}", file=sys.stderr)
    sys.exit(1)
rows = data.get("result") or []
if not rows:
    print("(no rows in window)", file=sys.stderr)
    sys.exit(0)
# rows came back DESC; flip to ASC for chronological reading
rows.sort(key=lambda r: r["timestamp"])
for r in rows:
    ts = datetime.datetime.fromtimestamp(r["timestamp"] / 1_000_000).strftime("%H:%M:%S")
    msg = (r.get("event_message") or "").rstrip("\n")
    print(f"[{ts}] {msg}")
sys.stdout.flush()
print(f"\n({len(rows)} rows)", file=sys.stderr)
PY
