#!/usr/bin/env bash
# Fire a synthetic Garmin activity webhook to trigger the activity-upload push.
#
# Why this script exists:
#   The "Your targets just updated" push is only sent from garmin-push /
#   garmin-ping, which fire on a real Garmin webhook. Waiting to finish an
#   actual workout is a slow way to check copy, and it can't exercise the
#   device-name attribution branches at all. garmin-push runs with
#   verify_jwt = false (supabase/config.toml) and treats a missing
#   garmin-client-id header as valid, so a plain POST reproduces the real
#   path end to end: match/auto-create → OneSignal send → Mixpanel
#   activity_upload_push_sent.
#
# Prereqs:
#   - A garmin_user_mappings row on the target project for the account you're
#     testing with. Get the id with:
#       select garmin_user_id, user_id from garmin_user_mappings;
#   - The app installed and signed in as that user, with push permission
#     granted (TestFlight or simulator).
#
# Usage:
#   ./scripts/test_activity_push.sh -g <garmin_user_id>
#   ./scripts/test_activity_push.sh -g <id> -d "Forerunner 955"
#   ./scripts/test_activity_push.sh -g <id> -d ""            # no model → "Garmin Connect"
#   ./scripts/test_activity_push.sh -g <id> --prod           # requires typing PROD to confirm
#
# After it returns, verify:
#   1. Device       — heading/body read correctly, nothing truncated.
#   2. Edge logs    — ./scripts/edge_logs.sh -m 5 garmin-push
#   3. Mixpanel     — Events / Live View: activity_upload_push_sent, then tap
#                     the push and watch for activity_upload_notification_clicked.
#                     Both should carry the same copy_variant.

set -euo pipefail

# ---- Defaults ---------------------------------------------------------------
DEV_REF="vlmtsdzpnjnavdgytcmi"
PROJECT_REF="$DEV_REF"
GARMIN_USER_ID=""
DEVICE_NAME="Forerunner 955"
SPORT="running"
MINUTES_AGO=45
IS_PROD=0

# ---- Arg parsing ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--garmin-user-id) GARMIN_USER_ID="$2"; shift 2 ;;
    -d|--device)         DEVICE_NAME="$2"; shift 2 ;;
    -s|--sport)          SPORT="$2"; shift 2 ;;
    -m|--minutes-ago)    MINUTES_AGO="$2"; shift 2 ;;
    -p|--project)        PROJECT_REF="$2"; shift 2 ;;
    --prod)              IS_PROD=1; shift ;;
    -h|--help)
      awk '/^# / { sub(/^# ?/, ""); print; next } /^#$/ { print ""; next } NR>1 { exit }' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$GARMIN_USER_ID" ]]; then
  echo "error: -g/--garmin-user-id is required." >&2
  echo "  select garmin_user_id, user_id from garmin_user_mappings;" >&2
  exit 1
fi

# ---- Prod guard -------------------------------------------------------------
# This inserts or completes a real activity row for a real athlete and sends
# them a real push. Never let that happen from a typo.
if [[ "$IS_PROD" -eq 1 ]]; then
  if [[ "$PROJECT_REF" == "$DEV_REF" ]]; then
    echo "error: --prod needs the prod ref too: --prod -p <prod-project-ref>" >&2
    exit 1
  fi
  echo "About to write a real activity and push a real notification on PROD"
  echo "  project:        $PROJECT_REF"
  echo "  garmin user id: $GARMIN_USER_ID"
  read -r -p "Type PROD to continue: " confirm
  [[ "$confirm" == "PROD" ]] || { echo "Aborted."; exit 1; }
fi

# ---- Payload ----------------------------------------------------------------
START_TIME=$(( $(date +%s) - MINUTES_AGO * 60 ))
# Unique per run: a repeated summaryId takes the duplicate path, which
# deliberately skips the notification.
SUMMARY_ID="manual-test-$(date +%s)-$$"
UTC_OFFSET_SECONDS=$(date +%z | awk '{
  sign = substr($0,1,1); h = substr($0,2,2); m = substr($0,4,2);
  s = (h * 3600) + (m * 60); print (sign == "-") ? -s : s
}')

URL="https://${PROJECT_REF}.supabase.co/functions/v1/garmin-push"

PAYLOAD=$(cat <<JSON
{
  "activities": [
    {
      "userId": "${GARMIN_USER_ID}",
      "userAccessToken": "manual-test-token",
      "summaryId": "${SUMMARY_ID}",
      "activityId": "${SUMMARY_ID}",
      "activityType": "${SPORT}",
      "activityName": "Manual push test",
      "deviceName": "${DEVICE_NAME}",
      "durationInSeconds": 3600,
      "startTimeInSeconds": ${START_TIME},
      "startTimeOffsetInSeconds": ${UTC_OFFSET_SECONDS},
      "distanceInMeters": 10000,
      "activeKilocalories": 650,
      "averageHeartRateInBeatsPerMinute": 145,
      "maxHeartRateInBeatsPerMinute": 175
    }
  ]
}
JSON
)

echo "POST $URL"
echo "  garmin user id: $GARMIN_USER_ID"
echo "  device:         ${DEVICE_NAME:-(none → expect \"Garmin Connect\")}"
echo "  summary id:     $SUMMARY_ID"
echo

curl -sS -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | python3 -m json.tool 2>/dev/null || true

cat <<'NEXT'

Next:
  1. Check the device for the notification.
  2. ./scripts/edge_logs.sh -m 5 garmin-push
     Expect: "OneSignal notification sent for activity <id>"
     A "[mixpanel] MIXPANEL_PROJECT_TOKEN missing" line means the secret
     isn't set on this project — the push still sends, but the
     click-through denominator is not being recorded.
  3. Mixpanel Live View: activity_upload_push_sent should appear within
     ~30s. Tap the push, then look for activity_upload_notification_clicked
     with a matching copy_variant.
NEXT
