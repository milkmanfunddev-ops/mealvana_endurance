/**
 * Shared OneSignal push helper for Garmin match notifications.
 *
 * Both garmin-push and garmin-ping should send the same
 * "targets updated" alert when they match a planned activity.
 *
 * The copy leads with the retrospective recalculation rather than the file
 * transfer: Garmin's measured energy expenditure re-runs the nutrition
 * calculator, and tapping the push invalidates the macro cache for
 * `scheduled_date` so the athlete lands on the corrected plan. Keep the
 * `${provider}` attribution in the body — Garmin's Developer API Brand
 * Guidelines require attribution wherever Garmin-derived data is surfaced.
 */

import { trackServerEvent } from "../analytics/mixpanel.ts";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") ?? "";
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") ?? "";

/**
 * Identifies which wording this push was sent with.
 *
 * Rides along in the push `data` payload so the client can echo it back on
 * `activity_upload_notification_clicked`, letting click-through be segmented
 * by copy instead of inferred from a release date. Bump this whenever the
 * heading or body changes, and keep it in lockstep with
 * `_activityUploadCopyVariant` in `lib/shared/services/notification_service.dart`.
 *
 * History:
 *   upload_v1       — "Workout uploaded" / "A workout for <date> was
 *                     uploaded from <provider>." (never carried this field;
 *                     clicks on it report `unknown`)
 *   accuracy_hook_v2 — current: leads with the retrospective recalculation
 */
export const ACTIVITY_UPLOAD_COPY_VARIANT = "accuracy_hook_v2";

function toMmDdYyyy(dateString: string): string {
  const [year, month, day] = dateString.split("-");
  if (!year || !month || !day) return dateString;
  return `${month}/${day}/${year}`;
}

/**
 * Short MM/DD form used in the push body only.
 *
 * The body carries a Garmin attribution string that expands to the device
 * model when known ("Garmin Forerunner 955"), so the copy is already close
 * to the ~120-char mark iOS starts truncating at. Dropping the year buys
 * back six characters with no loss of meaning — the notification always
 * refers to a recent session. The `activity_date` field in the data payload
 * keeps the full MM/DD/YYYY form so downstream analytics stay comparable.
 */
function toMmDd(dateString: string): string {
  const [, month, day] = dateString.split("-");
  if (!month || !day) return dateString;
  return `${month}/${day}`;
}

/**
 * Build the brand-compliant Garmin attribution string for a push body.
 *
 * Garmin's Developer API Brand Guidelines require:
 *   - No abbreviations — never a bare "Garmin" token on its own
 *   - Prefer the "Garmin [device model]" form when the model is known
 *     (e.g. "Garmin Forerunner 955")
 *   - Fall back to "Garmin Connect" when no device model is present
 */
export function buildGarminProviderLabel(deviceName?: string | null): string {
  const trimmed = deviceName?.trim();
  if (!trimmed) return "Garmin Connect";
  const lower = trimmed.toLowerCase();
  // Garmin sends "unknown" when the device model isn't identified.
  // Bare "Garmin" alone also violates brand guidelines.
  // In both cases, fall back to the full brand name.
  if (lower === "unknown" || lower === "garmin") return "Garmin Connect";
  if (lower.startsWith("garmin")) return trimmed;
  return `Garmin ${trimmed}`;
}

export async function sendActivityUploadedPush(params: {
  userId: string;
  activityId: string;
  scheduledDate: string; // YYYY-MM-DD
  /**
   * Human-readable attribution string used in the push body (e.g.
   * "Garmin Forerunner 955" or "Garmin Connect"). Must comply with Garmin's
   * Developer API Brand Guidelines — never abbreviate "Garmin", and prefer
   * the "Garmin [device model]" form when the device model is known.
   */
  provider?: string;
  logPrefix?: string;
}): Promise<void> {
  const prefix = params.logPrefix ?? "[garmin]";

  if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
    console.warn(
      `${prefix} OneSignal credentials missing - skipping remote push`,
    );
    return;
  }

  const provider = params.provider ?? "Garmin Connect";
  const activityDateText = toMmDdYyyy(params.scheduledDate);
  const bodyDateText = toMmDd(params.scheduledDate);

  const notificationPayload = {
    app_id: ONESIGNAL_APP_ID,
    include_aliases: {
      external_id: [params.userId],
    },
    target_channel: "push",
    headings: { en: "Your targets just updated" },
    contents: {
      en:
        `Your ${provider} workout is in. We recalculated your fuel plan for ` +
        `${bodyDateText} from what you actually burned.`,
    },
    data: {
      type: "activity",
      activityId: params.activityId,
      activity_id: params.activityId,
      provider: provider.toLowerCase(),
      activity_date: activityDateText,
      scheduled_date: params.scheduledDate,
      copy_variant: ACTIVITY_UPLOAD_COPY_VARIANT,
    },
  };

  const response = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Key ${ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify(notificationPayload),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(
      `${prefix} OneSignal send failed:`,
      response.status,
      errorBody,
    );
    return;
  }

  console.log(
    `${prefix} OneSignal notification sent for activity ${params.activityId} to user ${params.userId}`,
  );

  // Denominator for push click-through. Only emitted once OneSignal has
  // accepted the send, so this counts *sent*, not delivered or seen — a
  // device with notifications disabled still lands here. If you need
  // delivered, enable OneSignal Confirmed Deliveries; nothing can report
  // "seen" for a push.
  //
  // $insert_id is keyed on the activity so Garmin webhook re-deliveries and
  // the garmin-push / garmin-ping overlap collapse into one event.
  await trackServerEvent({
    event: "activity_upload_push_sent",
    distinctId: params.userId,
    insertId: `activity_upload_push_sent:${params.activityId}`,
    properties: {
      activity_id: params.activityId,
      activity_date: activityDateText,
      scheduled_date: params.scheduledDate,
      provider: provider.toLowerCase(),
      copy_variant: ACTIVITY_UPLOAD_COPY_VARIANT,
      source: prefix.replace(/[[\]]/g, ""),
    },
    logPrefix: prefix,
  });
}
