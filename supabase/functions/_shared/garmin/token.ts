/**
 * Garmin OAuth token helpers shared by the user-facing Garmin functions
 * (garmin-backfill, garmin-user-mapping, delete-user).
 *
 * Q-INT8 (RULED 2026-09-10): `integrations` is the SOLE token custodian.
 * Tokens are read from and refreshed back to the integrations row; the
 * garmin_user_mappings copies were stripped by migration 20260911160000.
 *
 * Testing-wave ticket 138 (Findings 112-010, 121-010): disconnecting Garmin
 * and deleting the account must also deregister the athlete AT Garmin
 * (`DELETE /wellness-api/rest/user/registration`, Garmin Start Guide §3.1),
 * otherwise Garmin keeps pushing for a user we no longer map. Both callers
 * go through [deregisterGarminForUser], which never throws: a Garmin failure
 * is logged and the caller carries on with its own delete.
 *
 * Finding 118-016: Garmin's "Token is not active" answer means the athlete
 * has to sign in again; [markGarminRequiresReauth] records that on the
 * integrations row the way ticket 64 does for TrainingPeaks and V.O2.
 */

export const GARMIN_TOKEN_URL =
  'https://diauth.garmin.com/di-oauth2-service/oauth/token';
export const GARMIN_DEREGISTRATION_URL =
  'https://apis.garmin.com/wellness-api/rest/user/registration';

// Refresh slightly ahead of expiry so an in-flight request never races a
// token that dies mid-request.
const TOKEN_REFRESH_SKEW_MS = 5 * 60 * 1000;

/** The garmin `integrations` row's token columns. */
export interface GarminTokenRow {
  access_token: string;
  refresh_token: string | null;
  token_expires_at: string | null;
}

export interface GarminTokenOptions {
  /** Garmin OAuth client id; defaults to the GARMIN_CLIENT_ID secret. */
  clientId?: string;
  /** Garmin OAuth client secret; defaults to the GARMIN_CLIENT_SECRET secret. */
  clientSecret?: string;
  /** Replaceable in tests. */
  fetch?: typeof fetch;
  /** Log line prefix, e.g. "[garmin-backfill]". */
  logPrefix?: string;
}

// deno-lint-ignore no-explicit-any
type SupabaseLike = any;

function env(name: string): string {
  try {
    return Deno.env.get(name) ?? '';
  } catch (_) {
    return '';
  }
}

/**
 * Returns a valid Garmin access token, refreshing it via the refresh_token
 * grant when the stored one is expired (or about to expire), and persisting
 * the refreshed token back to the integrations row.
 *
 * Falls back to the existing token (and lets Garmin surface the error) when
 * there is no refresh_token or the refresh call itself fails. Never throws.
 */
export async function ensureFreshGarminToken(
  supabase: SupabaseLike,
  row: GarminTokenRow,
  userId: string,
  opts: GarminTokenOptions = {},
): Promise<string> {
  const prefix = opts.logPrefix ?? '[garmin-token]';
  const doFetch = opts.fetch ?? fetch;
  const expiresAtMs = row.token_expires_at ? Date.parse(row.token_expires_at) : 0;
  const stillValid = expiresAtMs > 0 &&
    expiresAtMs - TOKEN_REFRESH_SKEW_MS > Date.now();
  if (stillValid) return row.access_token;

  if (!row.refresh_token) {
    console.warn(`${prefix} Token expired with no refresh_token; using stale token`);
    return row.access_token;
  }

  try {
    const resp = await doFetch(GARMIN_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: row.refresh_token,
        client_id: opts.clientId ?? env('GARMIN_CLIENT_ID'),
        client_secret: opts.clientSecret ?? env('GARMIN_CLIENT_SECRET'),
      }),
    });

    if (!resp.ok) {
      console.error(
        `${prefix} Token refresh failed (${resp.status}):`,
        (await resp.text()).slice(0, 300),
      );
      return row.access_token;
    }

    const json = await resp.json();
    const newAccessToken = json.access_token as string | undefined;
    if (!newAccessToken) {
      console.error(`${prefix} Token refresh missing access_token`);
      return row.access_token;
    }
    const newRefreshToken = (json.refresh_token as string | undefined) ?? row.refresh_token;
    const expiresInSec = (json.expires_in as number | undefined) ?? 3600;
    const newExpiresAt = new Date(Date.now() + expiresInSec * 1000).toISOString();

    const { error: updateErr } = await supabase
      .from('integrations')
      .update({
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
        token_expires_at: newExpiresAt,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)
      .eq('provider', 'garmin');

    if (updateErr) {
      console.error(`${prefix} Failed to persist refreshed token:`, updateErr);
    }

    return newAccessToken;
  } catch (err) {
    console.error(`${prefix} Token refresh error:`, err);
    return row.access_token;
  }
}

/** What [deregisterGarminForUser] did. */
export type GarminDeregistrationOutcome = 'deregistered' | 'no_token' | 'failed';

/**
 * Deregisters the user's Garmin connection at Garmin, so Garmin stops
 * pushing for them. Reads the token from the integrations row, refreshes it
 * if expired, then `DELETE /user/registration` (204 on success).
 *
 * Never throws. `no_token` means Garmin is not connected on this project
 * (nothing to deregister); `failed` is logged with the status, never the token.
 * Safe to repeat: a second call finds no token once the row is gone, and
 * Garmin answers 401 for an already-deleted registration, which is logged
 * as failed and changes nothing.
 */
export async function deregisterGarminForUser(
  supabase: SupabaseLike,
  userId: string,
  opts: GarminTokenOptions = {},
): Promise<GarminDeregistrationOutcome> {
  const prefix = opts.logPrefix ?? '[garmin-token]';
  const doFetch = opts.fetch ?? fetch;
  try {
    const { data: row, error } = await supabase
      .from('integrations')
      .select('access_token, refresh_token, token_expires_at')
      .eq('user_id', userId)
      .eq('provider', 'garmin')
      .maybeSingle();

    if (error) {
      console.error(`${prefix} Garmin deregistration: integrations read failed for user ${userId}:`, error);
      return 'failed';
    }
    if (!row?.access_token) return 'no_token';

    const accessToken = await ensureFreshGarminToken(supabase, row, userId, opts);
    const resp = await doFetch(GARMIN_DEREGISTRATION_URL, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${accessToken}` },
      // A hung Garmin must not hold account deletion to the function's wall
      // clock; a timeout is a 'failed' outcome, which never blocks (wave 43 review).
      signal: AbortSignal.timeout(10_000),
    });
    if (resp.ok) {
      console.log(`${prefix} Garmin registration deleted for user ${userId}`);
      return 'deregistered';
    }
    console.error(
      `${prefix} Garmin deregistration failed for user ${userId}: status ${resp.status}`,
    );
    return 'failed';
  } catch (err) {
    console.error(
      `${prefix} Garmin deregistration error for user ${userId}: ${
        err instanceof Error ? `${err.name}: ${err.message}` : String(err)
      }`,
    );
    return 'failed';
  }
}

/**
 * Garmin's answer when the access token is dead for good (the athlete
 * revoked access, or the refresh token expired). A rate limit or a gateway
 * error is transient and is not this.
 */
export function isGarminTokenInactive(status: number, body: string): boolean {
  if (status !== 401 && status !== 403) return false;
  return body.toLowerCase().includes('token is not active');
}

/**
 * Marks the garmin integrations row `requires_reauth`, so Connected Apps
 * shows Reconnect (Finding 118-016; same status ticket 64 uses for
 * TrainingPeaks and V.O2). Stores a plain message, never the raw answer.
 * Never throws; a failed write is logged.
 */
export async function markGarminRequiresReauth(
  supabase: SupabaseLike,
  userId: string,
  logPrefix = '[garmin-token]',
): Promise<void> {
  try {
    const { error } = await supabase
      .from('integrations')
      .update({
        last_sync_status: 'requires_reauth',
        last_sync_error: 'Garmin needs you to sign in again. Please reconnect.',
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)
      .eq('provider', 'garmin');
    if (error) {
      console.error(`${logPrefix} Failed to mark Garmin requires_reauth:`, error);
    }
  } catch (err) {
    console.error(`${logPrefix} Failed to mark Garmin requires_reauth:`, err);
  }
}
