#!/usr/bin/env bash
# Dashboard transient-state exposure monitor (read-only).
#
# The macro dashboard renders its disabled/placeholder state while today's
# daily_macro_targets row is absent or carries an older algorithm_version
# (the client treats stale versions as cache misses and recomputes — see
# daily_macro_targets_repository.dart). This probe counts, in PROD, how many
# recently-active users will enter that recompute window on their next app
# open. It is a leading indicator of exposure, not live duration — duration
# comes from the client telemetry event (dashboard_transient_targets).
#
# Usage: scripts/monitor_dashboard_transient.sh [--watch [SECONDS]]
#   --watch  repeat every SECONDS (default 3600) until interrupted.
# Requires: Supabase PAT at ~/.supabase/pat. Read-only; never writes.
set -euo pipefail

PROJECT_REF="wvmvsodrvbkxfydabqed" # prod
PAT="$(cat "$HOME/.supabase/pat")"

QUERY=$(cat <<'SQL'
with active as (
  select distinct user_id from daily_macro_targets
  where updated_at > now() - interval '14 days'
), current_v as (
  select max(algorithm_version) v from daily_macro_targets
  where updated_at > now() - interval '7 days'
), today as (
  select user_id, max(algorithm_version) v from daily_macro_targets
  where target_date = current_date group by user_id
)
select
  now()::timestamptz(0)                              as probed_at,
  (select v from current_v)                          as current_algo_version,
  (select count(*) from active)                      as active_users_14d,
  (select count(*) from active a
    where not exists (select 1 from today t
                      where t.user_id = a.user_id))  as no_targets_today,
  (select count(*) from today
    where v <> (select v from current_v))            as stale_version_today,
  (select count(*) from today
    where v = (select v from current_v))             as fresh_today
SQL
)

probe() {
  curl -s -X POST \
    "https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query" \
    -H "Authorization: Bearer ${PAT}" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys;print(json.dumps({"query":sys.stdin.read()}))' <<<"$QUERY")" \
    | python3 -m json.tool
}

if [[ "${1:-}" == "--watch" ]]; then
  interval="${2:-3600}"
  while true; do probe; sleep "$interval"; done
else
  probe
fi
