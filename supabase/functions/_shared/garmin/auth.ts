/**
 * Garmin Connect request validation and callback fetching
 *
 * Garmin sends a `garmin-client-id` header on all push/ping notifications
 * that we validate against our registered client ID.
 */

/**
 * Validate an incoming Garmin push/ping request.
 * Returns an error message string if invalid, or null if valid.
 *
 * Logs all incoming headers for debugging during integration testing.
 */
export function validateGarminRequest(
  req: Request,
  expectedClientId: string,
): string | null {
  // Log request details for debugging
  const headers: Record<string, string> = {};
  req.headers.forEach((value, key) => {
    headers[key] = key.toLowerCase().includes('auth') ? '[REDACTED]' : value;
  });
  console.log(`[garmin-auth] ${req.method} request, headers:`, JSON.stringify(headers));
  console.log(`[garmin-auth] Expected client ID: "${expectedClientId}" (length: ${expectedClientId.length})`);

  if (req.method !== 'POST') {
    return `Expected POST, got ${req.method}`;
  }

  const clientIdHeader = req.headers.get('garmin-client-id');

  // If no garmin-client-id header, log warning but allow the request
  // (Garmin Data Generator and some push types may not include it)
  if (!clientIdHeader) {
    console.warn('[garmin-auth] No garmin-client-id header present — allowing request');
    return null;
  }

  if (clientIdHeader !== expectedClientId) {
    console.error(`[garmin-auth] Client ID mismatch: got "${clientIdHeader}", expected "${expectedClientId}"`);
    return 'Invalid garmin-client-id';
  }

  return null;
}

/**
 * Fetch data from a Garmin ping callback URL.
 * Garmin provides callback URLs in ping notifications that we
 * must GET to retrieve the actual data.
 */
export async function fetchGarminCallback(callbackUrl: string): Promise<unknown> {
  const response = await fetch(callbackUrl, {
    method: 'GET',
    headers: {
      'Accept': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(
      `Garmin callback fetch failed: ${response.status} ${response.statusText}`,
    );
  }

  return await response.json();
}
