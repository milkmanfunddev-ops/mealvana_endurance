/**
 * Shared OneSignal push helper for Garmin match notifications.
 *
 * Both garmin-push and garmin-ping should send the same
 * "workout uploaded" alert when they match a planned activity.
 */

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") ?? "";
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") ?? "";

function toMmDdYyyy(dateString: string): string {
  const [year, month, day] = dateString.split("-");
  if (!year || !month || !day) return dateString;
  return `${month}/${day}/${year}`;
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

  const notificationPayload = {
    app_id: ONESIGNAL_APP_ID,
    include_aliases: {
      external_id: [params.userId],
    },
    target_channel: "push",
    headings: { en: "Workout uploaded" },
    contents: {
      en: `A workout for ${activityDateText} was uploaded from ${provider}.`,
    },
    data: {
      type: "activity",
      activityId: params.activityId,
      activity_id: params.activityId,
      provider: provider.toLowerCase(),
      activity_date: activityDateText,
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
  } else {
    console.log(
      `${prefix} OneSignal notification sent for activity ${params.activityId} to user ${params.userId}`,
    );
  }
}
