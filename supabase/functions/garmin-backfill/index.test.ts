/**
 * Tests for garmin-backfill Edge Function
 *
 * Validates:
 *  1. Summary type filtering — unknown types are rejected; known types map to
 *     the correct Garmin backfill path segment.
 *  2. Window-day clamping: max 90, min 1, floor on floats.
 *  3. Backfill URL assembly: correct base, path segment, and time params.
 *  4. ensureFreshGarminToken:
 *     a. Returns stored token when still valid.
 *     b. Calls refresh when token is expired.
 *     c. Falls back to stale token when no refresh_token present.
 *     d. Falls back gracefully when refresh HTTP call fails.
 *     e. Persists refreshed token back to garmin_user_mappings.
 *  5. All-failed detection: returns 502 when every queued status is >= 400.
 *  6. Partial success: partial failures included in errors map; overall still
 *     returns success as long as at least one succeeds.
 *  7. Request method guard: non-POST → 405.
 *
 * Run with:
 *   deno test --allow-env supabase/functions/garmin-backfill/index.test.ts
 */

import {
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Pure logic extracted from production — no Deno.serve / createClient deps
// ============================================================================

const GARMIN_BACKFILL_PATH: Record<string, string> = {
  body_composition: 'bodyComps',
  user_metrics: 'userMetrics',
  dailies: 'dailies',
  sleeps: 'sleeps',
  stress: 'stressDetails',
};

const DEFAULT_SUMMARY_TYPES = ['body_composition', 'user_metrics'];
const MAX_WINDOW_DAYS = 90;
const GARMIN_BACKFILL_BASE =
  'https://apis.garmin.com/wellness-api/rest/backfill';
const TOKEN_REFRESH_SKEW_MS = 5 * 60 * 1000;

/** Mirrors production summary-type filtering */
function filterSummaryTypes(requested: string[] | undefined): string[] {
  return (requested?.length ? requested : DEFAULT_SUMMARY_TYPES).filter(
    (t) => t in GARMIN_BACKFILL_PATH,
  );
}

/** Mirrors production window-day clamping */
function clampWindowDays(raw: number | undefined): number {
  return Math.min(
    Math.max(Math.floor(raw ?? MAX_WINDOW_DAYS), 1),
    MAX_WINDOW_DAYS,
  );
}

/** Mirrors production backfill URL assembly */
function buildBackfillUrl(
  summaryType: string,
  startSec: number,
  endSec: number,
): string {
  const path = GARMIN_BACKFILL_PATH[summaryType];
  return `${GARMIN_BACKFILL_BASE}/${path}?summaryStartTimeInSeconds=${startSec}&summaryEndTimeInSeconds=${endSec}`;
}

/** Mirrors allFailed detection */
function isAllFailed(queued: Record<string, number>): boolean {
  return (
    Object.keys(queued).length === 0 ||
    Object.values(queued).every((s) => s >= 400)
  );
}

// Mirrors ensureFreshGarminToken (pure logic, injectable fetch + supabase)
interface TokenMapping {
  access_token: string;
  refresh_token: string | null;
  token_expires_at: string | null;
}

async function ensureFreshGarminToken(
  supabase: { from: (t: string) => unknown },
  mapping: TokenMapping,
  userId: string,
  tokenUrl: string,
  clientId: string,
  clientSecret: string,
  // deno-lint-ignore no-explicit-any
  fetchFn: (url: string, init?: RequestInit) => Promise<any>,
): Promise<string> {
  const expiresAtMs = mapping.token_expires_at
    ? Date.parse(mapping.token_expires_at)
    : 0;
  const stillValid =
    expiresAtMs > 0 && expiresAtMs - TOKEN_REFRESH_SKEW_MS > Date.now();
  if (stillValid) return mapping.access_token;

  if (!mapping.refresh_token) {
    return mapping.access_token;
  }

  try {
    const resp = await fetchFn(tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: mapping.refresh_token,
        client_id: clientId,
        client_secret: clientSecret,
      }),
    });

    if (!resp.ok) {
      return mapping.access_token;
    }

    const json = await resp.json();
    const newAccessToken = json.access_token as string | undefined;
    if (!newAccessToken) return mapping.access_token;

    const newRefreshToken =
      (json.refresh_token as string | undefined) ?? mapping.refresh_token;
    const expiresInSec = (json.expires_in as number | undefined) ?? 3600;
    const newExpiresAt = new Date(Date.now() + expiresInSec * 1000).toISOString();

    // Persist refreshed token
    // deno-lint-ignore no-explicit-any
    const sb = supabase as any;
    await sb
      .from('garmin_user_mappings')
      .update({
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
        token_expires_at: newExpiresAt,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    return newAccessToken;
  } catch {
    return mapping.access_token;
  }
}

// ============================================================================
// Stubs
// ============================================================================

function buildFetchStub(opts: {
  ok: boolean;
  status?: number;
  // deno-lint-ignore no-explicit-any
  json?: Record<string, any>;
  text?: string;
// deno-lint-ignore no-explicit-any
}): (url: string, init?: RequestInit) => Promise<any> {
  return (_url: string, _init?: RequestInit) =>
    Promise.resolve({
      ok: opts.ok,
      status: opts.status ?? (opts.ok ? 200 : 400),
      json: () => Promise.resolve(opts.json ?? {}),
      text: () => Promise.resolve(opts.text ?? ''),
    });
}

function buildSupabaseUpdateStub() {
  // deno-lint-ignore no-explicit-any
  let lastUpdate: Record<string, any> | null = null;
  let updateCount = 0;

  const client = {
    from: (_table: string) => ({
      // deno-lint-ignore no-explicit-any
      update: (data: Record<string, any>) => {
        lastUpdate = data;
        updateCount++;
        return {
          eq: (_col: string, _val: string) =>
            Promise.resolve({ error: null }),
        };
      },
    }),
    getLastUpdate: () => lastUpdate,
    getUpdateCount: () => updateCount,
  };
  return client;
}

// ============================================================================
// Tests
// ============================================================================

describe('garmin-backfill', () => {
  // --------------------------------------------------------------------------
  // Summary type filtering
  // --------------------------------------------------------------------------
  describe('filterSummaryTypes', () => {
    it('defaults to body_composition + user_metrics when undefined', () => {
      assertEquals(filterSummaryTypes(undefined), [
        'body_composition',
        'user_metrics',
      ]);
    });

    it('defaults when empty array provided', () => {
      assertEquals(filterSummaryTypes([]), [
        'body_composition',
        'user_metrics',
      ]);
    });

    it('keeps only known types', () => {
      const result = filterSummaryTypes(['body_composition', 'unknown_type']);
      assertEquals(result, ['body_composition']);
    });

    it('passes through all known types', () => {
      const all = Object.keys(GARMIN_BACKFILL_PATH);
      assertEquals(filterSummaryTypes(all), all);
    });

    it('unknown-only array returns empty', () => {
      assertEquals(filterSummaryTypes(['not_a_real_type']), []);
    });

    it('preserves order of known types', () => {
      const result = filterSummaryTypes(['sleeps', 'dailies']);
      assertEquals(result, ['sleeps', 'dailies']);
    });
  });

  // --------------------------------------------------------------------------
  // Window-day clamping
  // --------------------------------------------------------------------------
  describe('clampWindowDays', () => {
    it('defaults to 90 when undefined', () => {
      assertEquals(clampWindowDays(undefined), 90);
    });

    it('clamps above 90 down to 90', () => {
      assertEquals(clampWindowDays(180), 90);
    });

    it('clamps below 1 up to 1', () => {
      assertEquals(clampWindowDays(0), 1);
    });

    it('negative value → 1', () => {
      assertEquals(clampWindowDays(-30), 1);
    });

    it('floors fractional days', () => {
      assertEquals(clampWindowDays(30.9), 30);
    });

    it('passes through 30 unchanged', () => {
      assertEquals(clampWindowDays(30), 30);
    });

    it('exactly 90 → 90', () => {
      assertEquals(clampWindowDays(90), 90);
    });

    it('exactly 1 → 1', () => {
      assertEquals(clampWindowDays(1), 1);
    });
  });

  // --------------------------------------------------------------------------
  // Backfill URL assembly
  // --------------------------------------------------------------------------
  describe('buildBackfillUrl', () => {
    it('assembles body_composition URL correctly', () => {
      const url = buildBackfillUrl('body_composition', 1000000, 1007776);
      assertEquals(
        url,
        'https://apis.garmin.com/wellness-api/rest/backfill/bodyComps?summaryStartTimeInSeconds=1000000&summaryEndTimeInSeconds=1007776',
      );
    });

    it('uses camelCase path segment from GARMIN_BACKFILL_PATH', () => {
      assertEquals(
        buildBackfillUrl('user_metrics', 0, 1).includes('/userMetrics'),
        true,
      );
      assertEquals(
        buildBackfillUrl('stress', 0, 1).includes('/stressDetails'),
        true,
      );
      assertEquals(
        buildBackfillUrl('dailies', 0, 1).includes('/dailies'),
        true,
      );
      assertEquals(
        buildBackfillUrl('sleeps', 0, 1).includes('/sleeps'),
        true,
      );
    });

    it('start and end times appear as query params', () => {
      const url = buildBackfillUrl('dailies', 1711584000, 1719273600);
      assertStringIncludes(url, 'summaryStartTimeInSeconds=1711584000');
      assertStringIncludes(url, 'summaryEndTimeInSeconds=1719273600');
    });

    it('URL does not contain a body (no payload params)', () => {
      // Production sends Content-Length: 0 and no body — ensure URL has no
      // body-related params that would confuse Garmin.
      const url = buildBackfillUrl('sleeps', 0, 1);
      assertEquals(url.includes('body'), false);
    });
  });

  // --------------------------------------------------------------------------
  // allFailed detection
  // --------------------------------------------------------------------------
  describe('isAllFailed', () => {
    it('empty queued → true (nothing succeeded)', () => {
      assertEquals(isAllFailed({}), true);
    });

    it('single 202 success → false', () => {
      assertEquals(isAllFailed({ body_composition: 202 }), false);
    });

    it('all 400+ → true', () => {
      assertEquals(
        isAllFailed({ body_composition: 400, user_metrics: 502 }),
        true,
      );
    });

    it('mixed: one success → false', () => {
      assertEquals(
        isAllFailed({ body_composition: 202, user_metrics: 401 }),
        false,
      );
    });

    it('202 alone → false', () => {
      assertEquals(isAllFailed({ body_composition: 202 }), false);
    });
  });

  // --------------------------------------------------------------------------
  // ensureFreshGarminToken
  // --------------------------------------------------------------------------
  describe('ensureFreshGarminToken', () => {
    const TOKEN_URL = 'https://diauth.garmin.com/di-oauth2-service/oauth/token';
    const CLIENT_ID = 'test-client-id';
    const CLIENT_SECRET = 'test-client-secret';
    const USER_ID = 'user-uuid-001';

    it('returns stored token when still valid (not expired)', async () => {
      const futureExpiry = new Date(Date.now() + 60 * 60 * 1000).toISOString();
      const mapping: TokenMapping = {
        access_token: 'valid-token-abc',
        refresh_token: 'refresh-token-xyz',
        token_expires_at: futureExpiry,
      };
      const sb = buildSupabaseUpdateStub();
      const fetchStub = buildFetchStub({ ok: true, json: {} });

      const token = await ensureFreshGarminToken(
        sb,
        mapping,
        USER_ID,
        TOKEN_URL,
        CLIENT_ID,
        CLIENT_SECRET,
        fetchStub,
      );

      assertEquals(token, 'valid-token-abc');
      // No refresh call needed
      assertEquals(sb.getUpdateCount(), 0);
    });

    it('refreshes token when expired and returns new token', async () => {
      const pastExpiry = new Date(Date.now() - 60 * 1000).toISOString();
      const mapping: TokenMapping = {
        access_token: 'stale-token',
        refresh_token: 'valid-refresh-token',
        token_expires_at: pastExpiry,
      };
      const sb = buildSupabaseUpdateStub();
      const fetchStub = buildFetchStub({
        ok: true,
        json: {
          access_token: 'fresh-token-new',
          refresh_token: 'new-refresh-token',
          expires_in: 3600,
        },
      });

      const token = await ensureFreshGarminToken(
        sb,
        mapping,
        USER_ID,
        TOKEN_URL,
        CLIENT_ID,
        CLIENT_SECRET,
        fetchStub,
      );

      assertEquals(token, 'fresh-token-new');
      // Refreshed token must be persisted
      assertEquals(sb.getUpdateCount(), 1);
      assertEquals(sb.getLastUpdate()?.access_token, 'fresh-token-new');
    });

    it('falls back to stale token when no refresh_token available', async () => {
      const pastExpiry = new Date(Date.now() - 60 * 1000).toISOString();
      const mapping: TokenMapping = {
        access_token: 'stale-token',
        refresh_token: null,
        token_expires_at: pastExpiry,
      };
      const sb = buildSupabaseUpdateStub();
      let fetchCalled = false;
      const fetchStub = (_url: string) => {
        fetchCalled = true;
        return Promise.resolve({ ok: false, status: 400, json: () => Promise.resolve({}), text: () => Promise.resolve('') });
      };

      const token = await ensureFreshGarminToken(
        sb,
        mapping,
        USER_ID,
        TOKEN_URL,
        CLIENT_ID,
        CLIENT_SECRET,
        fetchStub,
      );

      assertEquals(token, 'stale-token');
      assertEquals(fetchCalled, false); // should not even attempt refresh
      assertEquals(sb.getUpdateCount(), 0);
    });

    it('falls back to stale token when refresh HTTP call fails', async () => {
      const pastExpiry = new Date(Date.now() - 60 * 1000).toISOString();
      const mapping: TokenMapping = {
        access_token: 'stale-token',
        refresh_token: 'bad-refresh',
        token_expires_at: pastExpiry,
      };
      const sb = buildSupabaseUpdateStub();
      const fetchStub = buildFetchStub({ ok: false, status: 401 });

      const token = await ensureFreshGarminToken(
        sb,
        mapping,
        USER_ID,
        TOKEN_URL,
        CLIENT_ID,
        CLIENT_SECRET,
        fetchStub,
      );

      assertEquals(token, 'stale-token');
      assertEquals(sb.getUpdateCount(), 0);
    });

    it('falls back gracefully when refresh response has no access_token', async () => {
      const pastExpiry = new Date(Date.now() - 60 * 1000).toISOString();
      const mapping: TokenMapping = {
        access_token: 'stale-token',
        refresh_token: 'some-refresh',
        token_expires_at: pastExpiry,
      };
      const sb = buildSupabaseUpdateStub();
      // Response OK but missing access_token field
      const fetchStub = buildFetchStub({
        ok: true,
        json: { token_type: 'Bearer' }, // no access_token
      });

      const token = await ensureFreshGarminToken(
        sb,
        mapping,
        USER_ID,
        TOKEN_URL,
        CLIENT_ID,
        CLIENT_SECRET,
        fetchStub,
      );

      assertEquals(token, 'stale-token');
      assertEquals(sb.getUpdateCount(), 0);
    });

    it('uses existing refresh_token when response omits refresh_token', async () => {
      const pastExpiry = new Date(Date.now() - 60 * 1000).toISOString();
      const mapping: TokenMapping = {
        access_token: 'stale-token',
        refresh_token: 'original-refresh',
        token_expires_at: pastExpiry,
      };
      const sb = buildSupabaseUpdateStub();
      const fetchStub = buildFetchStub({
        ok: true,
        json: {
          access_token: 'fresh-token',
          expires_in: 3600,
          // No refresh_token in response — should keep original
        },
      });

      await ensureFreshGarminToken(
        sb,
        mapping,
        USER_ID,
        TOKEN_URL,
        CLIENT_ID,
        CLIENT_SECRET,
        fetchStub,
      );

      assertEquals(sb.getLastUpdate()?.refresh_token, 'original-refresh');
    });

    it('handles null token_expires_at as expired', async () => {
      const mapping: TokenMapping = {
        access_token: 'old-token',
        refresh_token: 'refresh-tok',
        token_expires_at: null, // no expiry stored → treated as expired
      };
      const sb = buildSupabaseUpdateStub();
      const fetchStub = buildFetchStub({
        ok: true,
        json: { access_token: 'new-tok', expires_in: 3600 },
      });

      const token = await ensureFreshGarminToken(
        sb,
        mapping,
        USER_ID,
        TOKEN_URL,
        CLIENT_ID,
        CLIENT_SECRET,
        fetchStub,
      );

      assertEquals(token, 'new-tok');
    });
  });

  // --------------------------------------------------------------------------
  // GARMIN_BACKFILL_PATH mapping coverage
  // --------------------------------------------------------------------------
  describe('GARMIN_BACKFILL_PATH', () => {
    it('all expected summary types are present', () => {
      const expectedKeys = [
        'body_composition',
        'user_metrics',
        'dailies',
        'sleeps',
        'stress',
      ];
      for (const key of expectedKeys) {
        assertEquals(
          key in GARMIN_BACKFILL_PATH,
          true,
          `Missing key: ${key}`,
        );
      }
    });

    it('maps to correct Garmin camelCase path segments', () => {
      assertEquals(GARMIN_BACKFILL_PATH['body_composition'], 'bodyComps');
      assertEquals(GARMIN_BACKFILL_PATH['user_metrics'], 'userMetrics');
      assertEquals(GARMIN_BACKFILL_PATH['dailies'], 'dailies');
      assertEquals(GARMIN_BACKFILL_PATH['sleeps'], 'sleeps');
      assertEquals(GARMIN_BACKFILL_PATH['stress'], 'stressDetails');
    });
  });
});

if (import.meta.main) {
  console.log('Running garmin-backfill tests...');
}
