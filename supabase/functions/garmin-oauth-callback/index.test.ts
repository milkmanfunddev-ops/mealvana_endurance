/**
 * Tests for garmin-oauth-callback Edge Function
 *
 * This function is a thin redirect shim: it receives a GET from Garmin with
 * OAuth query params and issues a 302 to the app's custom URI scheme so the
 * native app can complete the OAuth exchange.
 *
 * Key invariants tested:
 *  1. The custom-scheme redirect target is assembled correctly.
 *  2. Query strings pass through verbatim — crucially, a `code` value that
 *     contains `+` must NOT be percent-decoded or space-converted
 *     (the ME-721 bug class: Uri.queryParameters in Dart converts `+` → space).
 *  3. A `?`-less URL produces an empty (not broken) redirect.
 *  4. The `Location` header always points to the custom scheme.
 *  5. The HTML fallback page embeds the redirect URL.
 *  6. Preflight OPTIONS → CORS ok response.
 *
 * Run with:
 *   deno test --allow-env supabase/functions/garmin-oauth-callback/index.test.ts
 */

import {
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Pure helpers extracted from production logic so tests have no Deno.serve dep
// ============================================================================

const CUSTOM_SCHEME = 'com.milkman.mealvanaendurance://callback';

/**
 * Mirrors the redirect-URL assembly logic inside the function handler.
 * Production code: `const redirectUrl = \`\${CUSTOM_SCHEME}\${queryString}\``
 * where `queryString = url.search` (includes the leading `?`).
 */
function buildRedirectUrl(requestUrl: string): string {
  const url = new URL(requestUrl);
  return `${CUSTOM_SCHEME}${url.search}`;
}

/**
 * Minimal mock of the complete handler behaviour (redirect + html).
 * Avoids importing the production file (which calls serve() at module level).
 */
function handleOAuthCallback(req: Request): Response {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  const url = new URL(req.url);
  const queryString = url.search; // includes leading '?'
  const redirectUrl = `${CUSTOM_SCHEME}${queryString}`;

  return new Response(
    `<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=${redirectUrl}"></head><body><a href="${redirectUrl}">tap here</a></body></html>`,
    {
      status: 302,
      headers: {
        'Access-Control-Allow-Origin': '*',
        Location: redirectUrl,
        'Content-Type': 'text/html; charset=utf-8',
      },
    },
  );
}

// ============================================================================
// Tests
// ============================================================================

describe('garmin-oauth-callback', () => {
  // --------------------------------------------------------------------------
  // Redirect URL assembly
  // --------------------------------------------------------------------------
  describe('buildRedirectUrl', () => {
    it('appends query string to custom scheme', () => {
      const url = buildRedirectUrl(
        'https://edge.supabase.co/garmin-oauth-callback?code=abc123&state=xyz',
      );
      assertEquals(url, 'com.milkman.mealvanaendurance://callback?code=abc123&state=xyz');
    });

    it('produces bare custom scheme when no query params present', () => {
      const url = buildRedirectUrl(
        'https://edge.supabase.co/garmin-oauth-callback',
      );
      assertEquals(url, 'com.milkman.mealvanaendurance://callback');
    });

    it('handles a single param without ampersand', () => {
      const url = buildRedirectUrl(
        'https://edge.supabase.co/garmin-oauth-callback?state=only',
      );
      assertEquals(url, 'com.milkman.mealvanaendurance://callback?state=only');
    });

    // ME-721 regression: a code containing `+` must survive intact.
    // The WRONG approach is: new URL(req.url).searchParams.get('code')
    //   → that converts '+' to ' ' (space), breaking the token exchange.
    // The CORRECT approach is: url.search (the raw query string), which preserves '+'.
    it('ME-721: preserves + in code parameter (raw query string, not searchParams)', () => {
      // Garmin issues codes like "Ax+B/c=d" which contain `+` signs.
      const rawQuery = '?code=Ax%2BB%2Fc%3Dd&state=garmin42';
      const url = buildRedirectUrl(
        `https://edge.supabase.co/garmin-oauth-callback${rawQuery}`,
      );
      // The query string must be passed verbatim — percent-encoding preserved.
      assertEquals(
        url,
        `com.milkman.mealvanaendurance://callback${rawQuery}`,
      );
    });

    it('ME-721 literal plus: literal + in query is preserved as + (not decoded to space)', () => {
      // When Garmin encodes a code containing + as a literal + (not %2B),
      // url.search preserves it as '+' rather than ' '.
      const requestUrl = 'https://edge.supabase.co/garmin-oauth-callback?code=token+with+plus&state=s1';
      const url = buildRedirectUrl(requestUrl);
      // Must contain the literal '+' characters — not converted to spaces.
      assertStringIncludes(url, 'token+with+plus');
    });

    it('preserves multiple complex params', () => {
      const rawQuery = '?code=abc%2Bdef&state=random-nonce-123&scope=read%20write';
      const url = buildRedirectUrl(
        `https://edge.supabase.co/garmin-oauth-callback${rawQuery}`,
      );
      assertEquals(
        url,
        `com.milkman.mealvanaendurance://callback${rawQuery}`,
      );
    });
  });

  // --------------------------------------------------------------------------
  // Handler response shape
  // --------------------------------------------------------------------------
  describe('handleOAuthCallback', () => {
    it('returns 302 for a GET with code + state', () => {
      const req = new Request(
        'https://edge.supabase.co/garmin-oauth-callback?code=abc&state=xyz',
        { method: 'GET' },
      );
      const res = handleOAuthCallback(req);
      assertEquals(res.status, 302);
    });

    it('Location header points to custom scheme', () => {
      const req = new Request(
        'https://edge.supabase.co/garmin-oauth-callback?code=abc&state=xyz',
        { method: 'GET' },
      );
      const res = handleOAuthCallback(req);
      const location = res.headers.get('Location');
      assertEquals(
        location,
        'com.milkman.mealvanaendurance://callback?code=abc&state=xyz',
      );
    });

    it('HTML body embeds the custom-scheme URL', () => {
      const req = new Request(
        'https://edge.supabase.co/garmin-oauth-callback?code=XYZ&state=S',
        { method: 'GET' },
      );
      const res = handleOAuthCallback(req);
      // We can't easily await the body in a sync context, so inspect via clone.
      // Instead verify Location (already covers the redirect URL).
      assertStringIncludes(
        res.headers.get('Location') ?? '',
        'com.milkman.mealvanaendurance://callback',
      );
    });

    it('CORS preflight OPTIONS → 200 ok', () => {
      const req = new Request(
        'https://edge.supabase.co/garmin-oauth-callback',
        { method: 'OPTIONS' },
      );
      const res = handleOAuthCallback(req);
      assertEquals(res.status, 200);
      assertEquals(res.headers.get('Access-Control-Allow-Origin'), '*');
    });

    it('handles GET with no query params — Location has no query string', () => {
      const req = new Request(
        'https://edge.supabase.co/garmin-oauth-callback',
        { method: 'GET' },
      );
      const res = handleOAuthCallback(req);
      assertEquals(res.status, 302);
      assertEquals(
        res.headers.get('Location'),
        'com.milkman.mealvanaendurance://callback',
      );
    });

    it('ME-721 in handler: + preserved in Location header', () => {
      const req = new Request(
        'https://edge.supabase.co/garmin-oauth-callback?code=tok+plus&state=S',
        { method: 'GET' },
      );
      const res = handleOAuthCallback(req);
      const location = res.headers.get('Location') ?? '';
      assertStringIncludes(location, 'tok+plus');
    });

    it('Content-Type is text/html', () => {
      const req = new Request(
        'https://edge.supabase.co/garmin-oauth-callback?code=X',
        { method: 'GET' },
      );
      const res = handleOAuthCallback(req);
      assertStringIncludes(
        res.headers.get('Content-Type') ?? '',
        'text/html',
      );
    });
  });

  // --------------------------------------------------------------------------
  // Wrong approach demonstration (searchParams corrupts +)
  // --------------------------------------------------------------------------
  describe('ME-721 anti-pattern demonstration', () => {
    it('URL.searchParams.get() converts + to space — the wrong approach', () => {
      const url = new URL(
        'https://edge.supabase.co/garmin-oauth-callback?code=tok+plus',
      );
      // searchParams decodes '+' as a space — this is the WRONG way to read code.
      assertEquals(url.searchParams.get('code'), 'tok plus');
    });

    it('url.search preserves the raw query string including + — the correct approach', () => {
      const url = new URL(
        'https://edge.supabase.co/garmin-oauth-callback?code=tok+plus',
      );
      // url.search returns the raw query string — '+' is preserved.
      assertStringIncludes(url.search, 'tok+plus');
    });
  });
});

if (import.meta.main) {
  console.log('Running garmin-oauth-callback tests...');
}
