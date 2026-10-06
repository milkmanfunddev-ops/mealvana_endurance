/**
 * What garmin-backfill answers when Garmin queued nothing.
 *
 * Until ticket 19 (Sentry MEALVANA-ENDURANCE-AA / AB, DEV-5P / DEV-9M) every
 * all-failed backfill answered 502, whatever Garmin had said. The prod logs
 * (2026-09-27, 2026-10-01, 2026-10-02) showed three different causes behind
 * that one 502:
 *
 *  - `401 {"errorMessage":"Token is not active"}` after the refresh grant came
 *    back `invalid_grant`: the athlete's Garmin connection is dead and only a
 *    reconnect fixes it. Retrying never helps.
 *  - `429 Too many request: Limit 100 per 1 minute`: Garmin's own throttle.
 *  - `502` HTML from Garmin's Cloudflare edge: Garmin is down.
 *
 * Each now gets an answer that says which it was, so the app can act on it and
 * the app's HTTP layer stops reporting a dead token or a throttle as a server
 * fault (it reports 5xx only). Only a real upstream outage keeps 502.
 */

export type BackfillFailureCode =
  | 'garmin_reauth_required'
  | 'garmin_rate_limited'
  | 'garmin_unavailable';

export interface BackfillFailure {
  status: number;
  code: BackfillFailureCode;
  message: string;
}

/** Seconds the app should wait before asking again after a Garmin throttle. */
export const RATE_LIMIT_RETRY_AFTER_SECONDS = 60;

/**
 * [queued] maps each requested summary type to Garmin's HTTP status (a type
 * whose fetch threw is absent). Returns `null` when at least one type was
 * queued, i.e. the call succeeded.
 */
export function classifyBackfillFailure(
  queued: Record<string, number>,
): BackfillFailure | null {
  const statuses = Object.values(queued);
  const allFailed = statuses.length === 0 || statuses.every((s) => s >= 400);
  if (!allFailed) return null;

  // Garmin checks the token before anything else, so one 401 means the token
  // is dead for every type (the other types' 429s are noise behind it).
  if (statuses.includes(401)) {
    return {
      status: 409,
      code: 'garmin_reauth_required',
      message: 'Garmin connection expired; the athlete must reconnect Garmin',
    };
  }

  if (statuses.length > 0 && statuses.every((s) => s === 429)) {
    return {
      status: 429,
      code: 'garmin_rate_limited',
      message: 'Garmin is throttling backfill requests; retry later',
    };
  }

  return {
    status: 502,
    code: 'garmin_unavailable',
    message: 'Garmin backfill request failed for all summary types',
  };
}
