/**
 * The one redaction rule (testing-wave develop-2026-10 tickets 76 and 84,
 * Finding 69-012): a provider error keeps its status and error code only;
 * a database error keeps its code and message only.
 *
 * Run with: deno test --allow-all supabase/functions/_shared/provider_error.test.ts
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import { dbErrorSummary, providerErrorSummary } from './provider_error.ts';

// Garmin's real invalid_grant shape (69-012): the description carries a
// base64 JSON holding the refresh token value.
const leakedB64 = btoa(
  JSON.stringify({ refreshTokenValue: 'rt-live-5f2c', garminGuid: 'g-guid-1' }),
);
const invalidGrantBody = JSON.stringify({
  error: 'invalid_grant',
  error_description: `Invalid refresh token: ${leakedB64}`,
});

Deno.test('invalid_grant keeps the code and drops the description', () => {
  const summary = providerErrorSummary(400, invalidGrantBody);
  assertEquals(summary, { status: 400, error_code: 'invalid_grant' });
  const text = JSON.stringify(summary);
  assertEquals(text.includes('rt-live-5f2c'), false);
  assertEquals(text.includes(leakedB64.slice(0, 12)), false);
  assertEquals(text.includes('Invalid refresh token'), false);
});

Deno.test('errorMessage only gives no code', () => {
  assertEquals(
    providerErrorSummary(401, '{"errorMessage":"Token is not active"}'),
    { status: 401, error_code: null },
  );
});

Deno.test('a non-JSON body (Garmin 502 HTML) gives no code', () => {
  assertEquals(
    providerErrorSummary(
      502,
      '<html><head><title>502 Bad Gateway</title></head><body>cloudflare</body></html>',
    ),
    { status: 502, error_code: null },
  );
});

Deno.test('an error with spaces gives no code', () => {
  assertEquals(
    providerErrorSummary(400, '{"error":"has a space rt-live"}'),
    { status: 400, error_code: null },
  );
});

Deno.test('code is read when error and errorCode are absent', () => {
  assertEquals(
    providerErrorSummary(429, '{"code":"rate_limited"}'),
    { status: 429, error_code: 'rate_limited' },
  );
  assertEquals(
    providerErrorSummary(400, '{"errorCode":"INVALID_TOKEN"}'),
    { status: 400, error_code: 'INVALID_TOKEN' },
  );
});

Deno.test('a 200-character error gives no code', () => {
  const body = JSON.stringify({ error: 'a'.repeat(200) });
  assertEquals(providerErrorSummary(400, body), { status: 400, error_code: null });
});

Deno.test('only message, a JSON array or a JSON string give no code', () => {
  assertEquals(providerErrorSummary(400, '{"message":"bad"}').error_code, null);
  assertEquals(providerErrorSummary(400, '["invalid_grant"]').error_code, null);
  assertEquals(providerErrorSummary(400, '"invalid_grant"').error_code, null);
  assertEquals(providerErrorSummary(400, '').error_code, null);
});

Deno.test('a numeric code is not kept', () => {
  assertEquals(providerErrorSummary(400, '{"code":42}').error_code, null);
});

Deno.test('dbErrorSummary keeps code and message, drops details and hint', () => {
  const summary = dbErrorSummary({
    code: '23502',
    message: 'null value in column "access_token" violates not-null constraint',
    details: 'Failing row contains (u1, garmin, rt-live-5f2c, …)',
    hint: 'rt-live-5f2c',
  });
  assertEquals(summary, {
    code: '23502',
    message: 'null value in column "access_token" violates not-null constraint',
  });
  assertEquals(JSON.stringify(summary).includes('rt-live-5f2c'), false);
});

Deno.test('dbErrorSummary of a thrown Error gives name: message', () => {
  assertEquals(dbErrorSummary(new TypeError('network down')), {
    code: null,
    message: 'TypeError: network down',
  });
});

Deno.test('dbErrorSummary of anything else gives nulls', () => {
  assertEquals(dbErrorSummary('rt-live-5f2c'), { code: null, message: null });
  assertEquals(dbErrorSummary(null), { code: null, message: null });
  assertEquals(dbErrorSummary({ code: 1, message: {} }), { code: null, message: null });
});

Deno.test('dbErrorSummary withholds a SyntaxError message (it quotes the refused text)', () => {
  const s = dbErrorSummary(new SyntaxError('Unexpected token \'<\', "<html>refresh_token=abc" is not valid JSON'));
  assertEquals(s.code, null);
  assertEquals(s.message?.includes('abc'), false);
  assertEquals(s.message?.startsWith('SyntaxError'), true);
});
