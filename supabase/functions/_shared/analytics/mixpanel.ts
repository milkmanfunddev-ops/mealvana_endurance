/**
 * Minimal server-side Mixpanel track helper for edge functions.
 *
 * Why this exists: some events can only be observed on the server. The
 * activity-upload push is the motivating case — it is sent from
 * `garmin-push`/`garmin-ping`, so the client has no way to emit the
 * impression half of the funnel. Without a server event there is a
 * numerator (`activity_upload_notification_clicked`) and no denominator.
 *
 * Identity: `distinctId` MUST be the Supabase user id. The app calls
 * `mixpanel.identify(user.id)` with `user_profiles.id`, which is the same
 * value as `users.id` (see `lib/shared/database/tables/user_profiles.dart`),
 * and the push targets `include_aliases.external_id` with that same id. Pass
 * anything else and the server event will not join to the client events.
 *
 * Caveat for analysis: the app registers `is_internal` as a Mixpanel *super
 * property* on client events, and server events do not carry super
 * properties. Filter internal traffic by the `is_internal` People property
 * (set via `markInternal()`) rather than the event property, or internal
 * sends will not be excluded.
 */

const MIXPANEL_TOKEN = Deno.env.get("MIXPANEL_PROJECT_TOKEN") ?? "";
const MIXPANEL_TRACK_URL = "https://api.mixpanel.com/track";

/**
 * Fire-and-forget Mixpanel event.
 *
 * Never throws and never rejects: analytics must not be able to fail a push
 * send or a webhook response. Failures are logged and swallowed.
 *
 * [insertId] is passed as `$insert_id` for Mixpanel's 5-day dedup window.
 * Supply a value that is stable for a logical event (e.g. activity id +
 * event name) so webhook retries don't inflate counts — Garmin re-delivers
 * pushes, and both garmin-push and garmin-ping can process the same summary.
 */
export async function trackServerEvent(params: {
  event: string;
  distinctId: string;
  properties?: Record<string, unknown>;
  insertId?: string;
  logPrefix?: string;
}): Promise<void> {
  const prefix = params.logPrefix ?? "[mixpanel]";

  if (!MIXPANEL_TOKEN) {
    console.warn(`${prefix} MIXPANEL_PROJECT_TOKEN missing - skipping event`);
    return;
  }

  const payload = [{
    event: params.event,
    properties: {
      token: MIXPANEL_TOKEN,
      distinct_id: params.distinctId,
      time: Date.now(),
      ...(params.insertId ? { $insert_id: params.insertId } : {}),
      ...params.properties,
    },
  }];

  try {
    const response = await fetch(MIXPANEL_TRACK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "text/plain",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(
        `${prefix} track failed:`,
        response.status,
        errorBody,
      );
    }
  } catch (error) {
    console.error(`${prefix} track threw:`, error);
  }
}
