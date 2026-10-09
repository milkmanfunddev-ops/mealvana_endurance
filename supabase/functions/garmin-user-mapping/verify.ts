/**
 * The upsert action's check that the access token the app sent belongs to
 * the Garmin user id it claims, built with `fetch` injectable so
 * index.test.ts drives this exact code against fakes (as delete.ts does).
 *
 * Ticket 76 (Finding 69-012): a refused check logs Garmin's status and error
 * code only (the shared rule in `../_shared/provider_error.ts`), never
 * Garmin's body, which can echo the Bearer token.
 */

import { providerErrorSummary } from '../_shared/provider_error.ts';

export const GARMIN_USER_ID_URL =
  'https://apis.garmin.com/wellness-api/rest/user/id';

export type VerifyGarminUserResult =
  | { ok: true }
  | { ok: false; status: 401 | 403; message: string };

export async function verifyGarminUserId(
  accessToken: string,
  expectedGarminUserId: string,
  fetchFn: typeof fetch = fetch,
): Promise<VerifyGarminUserResult> {
  const response = await fetchFn(GARMIN_USER_ID_URL, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    console.error(
      '[garmin-user-mapping] Garmin user verification failed',
      providerErrorSummary(response.status, await response.text()),
    );
    return { ok: false, status: 401, message: 'Unable to verify Garmin account' };
  }

  const payload = await response.json();
  if (payload.userId !== expectedGarminUserId) {
    console.error('[garmin-user-mapping] Garmin user ID mismatch', {
      expectedGarminUserId,
      actualGarminUserId: payload.userId,
    });
    return { ok: false, status: 403, message: 'Garmin account verification mismatch' };
  }

  return { ok: true };
}
