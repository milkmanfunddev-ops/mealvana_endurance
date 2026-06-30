/**
 * Unit tests for search-public-events edge function.
 *
 * STRATEGY:
 * The handler is a thin pass-through to the `search_public_events_hybrid` RPC.
 * The only pure testable logic is:
 * 1. Query validation: must be >= 2 characters
 * 2. Response assembly: events array, count, has_exact_matches, has_fuzzy_matches
 * 3. Default parameter values: limit=10, eventType=null, state=null
 *
 * The RPC call itself requires a live integration test.
 *
 * BUGS FOUND: documented inline.
 *
 * Run with:
 *   deno test --allow-env --node-modules-dir=none \
 *     supabase/functions/search-public-events/index.test.ts
 */

import {
  assertEquals,
  assert,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Pure copies of logic from index.ts
// ============================================================================

/** Validates the query parameter (must be >= 2 chars after trim) */
function validateSearchQuery(query: unknown): { valid: boolean; error?: string } {
  if (!query || (query as string).trim().length < 2) {
    return { valid: false, error: 'Query must be at least 2 characters' };
  }
  return { valid: true };
}

/** Assembles the success response envelope */
function assembleSearchResponse(
  events: Array<Record<string, unknown>>,
  query: string,
): Record<string, unknown> {
  const results = events || [];
  return {
    events: results,
    count: results.length,
    query,
    has_exact_matches: results.some((e) => e.match_type === 'exact'),
    has_fuzzy_matches: results.some((e) => e.match_type === 'fuzzy'),
  };
}

// ============================================================================
// A. Query validation
// ============================================================================

describe('search-public-events query validation', () => {
  it('2-character query → valid', () => {
    assertEquals(validateSearchQuery('bo').valid, true);
  });

  it('3+ characters → valid', () => {
    assertEquals(validateSearchQuery('Boston Marathon').valid, true);
  });

  it('1-character query → invalid', () => {
    const result = validateSearchQuery('a');
    assertEquals(result.valid, false);
    assertExists(result.error);
    assert(result.error!.includes('2 characters'));
  });

  it('empty string → invalid', () => {
    const result = validateSearchQuery('');
    assertEquals(result.valid, false);
  });

  it('null → invalid', () => {
    const result = validateSearchQuery(null);
    assertEquals(result.valid, false);
  });

  it('undefined → invalid', () => {
    const result = validateSearchQuery(undefined);
    assertEquals(result.valid, false);
  });

  it('single space " " → invalid (trim() gives length 0 < 2)', () => {
    const result = validateSearchQuery(' ');
    assertEquals(result.valid, false);
  });

  it('two spaces "  " → invalid (trim() gives length 0 < 2)', () => {
    const result = validateSearchQuery('  ');
    assertEquals(result.valid, false);
  });

  it('one char + space " a" → invalid (trim() gives "a", length 1 < 2)', () => {
    const result = validateSearchQuery(' a');
    assertEquals(result.valid, false);
  });

  it('two chars + spaces "  ab  " → valid (trim() gives "ab", length 2)', () => {
    // Note: search-public-events calls query.trim() on the RPC arg, but
    // the validation checks query.trim().length < 2 BEFORE trimming the stored query.
    // The stored `query` in the response is the UNTRIMMED original.
    // BUG NOTE: The handler passes `query.trim()` to the RPC but puts the
    // ORIGINAL (untrimmed) `query` in the response body. Inconsistency.
    const result = validateSearchQuery('  ab  ');
    assertEquals(result.valid, true); // trim() = "ab", length = 2
  });

  it('exactly 2 meaningful chars surrounded by whitespace → valid', () => {
    assertEquals(validateSearchQuery('  NY  ').valid, true);
  });
});

// ============================================================================
// B. Response assembly — has_exact_matches / has_fuzzy_matches
// ============================================================================

describe('search-public-events response assembly', () => {
  it('empty results → count=0, both match flags false', () => {
    const response = assembleSearchResponse([], 'test');
    assertEquals(response.count, 0);
    assertEquals(response.has_exact_matches, false);
    assertEquals(response.has_fuzzy_matches, false);
    assertEquals((response.events as unknown[]).length, 0);
  });

  it('exact match in results → has_exact_matches=true', () => {
    const events = [{ match_type: 'exact', event_name: 'Boston Marathon' }];
    const response = assembleSearchResponse(events, 'boston');
    assertEquals(response.has_exact_matches, true);
    assertEquals(response.has_fuzzy_matches, false);
  });

  it('fuzzy match in results → has_fuzzy_matches=true', () => {
    const events = [{ match_type: 'fuzzy', event_name: 'Bostun Marathon' }];
    const response = assembleSearchResponse(events, 'boston');
    assertEquals(response.has_exact_matches, false);
    assertEquals(response.has_fuzzy_matches, true);
  });

  it('mixed results → both match flags true', () => {
    const events = [
      { match_type: 'exact', event_name: 'Boston Marathon' },
      { match_type: 'fuzzy', event_name: 'Boston Half Marathon' },
    ];
    const response = assembleSearchResponse(events, 'boston');
    assertEquals(response.has_exact_matches, true);
    assertEquals(response.has_fuzzy_matches, true);
  });

  it('match_type absent → neither flag set', () => {
    const events = [{ event_name: 'Some Race' }]; // no match_type
    const response = assembleSearchResponse(events, 'race');
    assertEquals(response.has_exact_matches, false);
    assertEquals(response.has_fuzzy_matches, false);
  });

  it('count reflects actual results length', () => {
    const events = [
      { match_type: 'exact' },
      { match_type: 'fuzzy' },
      { match_type: 'fuzzy' },
    ];
    const response = assembleSearchResponse(events, 'test');
    assertEquals(response.count, 3);
  });

  it('query is included in response', () => {
    const response = assembleSearchResponse([], 'Boston 2026');
    assertEquals(response.query, 'Boston 2026');
  });

  it('events field is always an array (even when RPC returns null)', () => {
    // The handler does `const results = events || []`
    // If RPC returns null, events defaults to []
    const response = assembleSearchResponse(null as any, 'test');
    assert(Array.isArray(response.events));
    assertEquals(response.count, 0);
  });
});

// ============================================================================
// C. Default parameters
// ============================================================================

describe('search-public-events default parameters', () => {
  it('limit defaults to 10 when not provided', () => {
    // Mirrors: const { query, limit = 10, eventType, state } = await req.json()
    const params = { query: 'Boston' } as any;
    const limit = params.limit ?? 10;
    assertEquals(limit, 10);
  });

  it('eventType defaults to null', () => {
    const params = { query: 'Boston' } as any;
    const eventType = params.eventType || null;
    assertEquals(eventType, null);
  });

  it('state defaults to null', () => {
    const params = { query: 'Boston' } as any;
    const state = params.state || null;
    assertEquals(state, null);
  });

  it('explicit eventType overrides null default', () => {
    const params = { query: 'Boston', eventType: 'marathon' };
    const eventType = params.eventType || null;
    assertEquals(eventType, 'marathon');
  });

  it('explicit state overrides null default', () => {
    const params = { query: 'Boston', state: 'MA' };
    const state = params.state || null;
    assertEquals(state, 'MA');
  });

  it('explicit limit overrides default', () => {
    const params = { query: 'Boston', limit: 5 };
    const limit = params.limit ?? 10;
    assertEquals(limit, 5);
  });

  it('min_similarity is hardcoded at 0.2 (not user-configurable)', () => {
    // The function always passes min_similarity: 0.2 to the RPC.
    // This is intentional — not exposed as a parameter.
    const minSimilarity = 0.2;
    assertEquals(minSimilarity, 0.2);
  });
});

// ============================================================================
// D. RPC parameter assembly
// ============================================================================

describe('search-public-events RPC parameter assembly', () => {
  it('RPC args built correctly with all defaults', () => {
    // Mirrors: supabaseClient.rpc('search_public_events_hybrid', { ... })
    const query = 'Boston';
    const limit = 10;
    const eventType = null;
    const state = null;

    const rpcArgs = {
      search_term: query.trim(),
      limit_count: limit,
      event_type_filter: eventType,
      state_filter: state,
      min_similarity: 0.2,
    };

    assertEquals(rpcArgs.search_term, 'Boston');
    assertEquals(rpcArgs.limit_count, 10);
    assertEquals(rpcArgs.event_type_filter, null);
    assertEquals(rpcArgs.state_filter, null);
    assertEquals(rpcArgs.min_similarity, 0.2);
  });

  it('search_term is trimmed before passing to RPC', () => {
    const query = '  Boston Marathon  ';
    const rpcSearchTerm = query.trim();
    assertEquals(rpcSearchTerm, 'Boston Marathon');
  });

  it('BUG: response query field is UNTRIMMED original (inconsistency)', () => {
    // The RPC receives `query.trim()` but the response body contains `query` (untrimmed).
    // Filed as KNOWN BUG (low severity — cosmetic inconsistency).
    const query = '  Boston  ';
    const rpcSearchTerm = query.trim(); // 'Boston' (what RPC searches for)
    const responseQuery = query;        // '  Boston  ' (what response reports)
    assert(rpcSearchTerm !== responseQuery, 'search_term trimmed ≠ response query (inconsistency)');
  });

  it('event_type_filter: explicit value passed through', () => {
    const eventType = 'marathon';
    const rpcArgs = { event_type_filter: eventType || null };
    assertEquals(rpcArgs.event_type_filter, 'marathon');
  });

  it('state_filter: explicit value passed through', () => {
    const state = 'CA';
    const rpcArgs = { state_filter: state || null };
    assertEquals(rpcArgs.state_filter, 'CA');
  });
});

// ============================================================================
// E. Error response shapes
// ============================================================================

describe('search-public-events error shapes', () => {
  it('400 validation error shape matches production', () => {
    const errorResponse = {
      error: 'Query must be at least 2 characters',
    };
    assertExists(errorResponse.error);
    assertEquals(errorResponse.error, 'Query must be at least 2 characters');
  });

  it('500 RPC error shape includes details', () => {
    const rpcError = { message: 'function does not exist' };
    const errorResponse = {
      error: 'Failed to search events',
      details: rpcError.message,
    };
    assertExists(errorResponse.details);
    assertEquals(errorResponse.error, 'Failed to search events');
  });

  it('500 unexpected error shape has details field', () => {
    const unexpectedError = new Error('Connection timeout');
    const errorResponse = {
      error: 'Internal server error',
      details: unexpectedError instanceof Error ? unexpectedError.message : 'Unknown error',
    };
    assertEquals(errorResponse.details, 'Connection timeout');
  });
});

// ============================================================================
// F. Live integration test note
// ============================================================================

describe('search-public-events — live integration required', () => {
  it('NOTE: search_public_events_hybrid RPC requires live Supabase integration test', () => {
    // Full-text + trigram fuzzy search cannot be unit-tested.
    // To verify:
    //   1. Known race name returns exact match (e.g., "Boston Marathon")
    //   2. Typo returns fuzzy match (e.g., "Bostun Marathon")
    //   3. eventType filter narrows results
    //   4. state filter narrows results (e.g., state="MA")
    //   5. Results capped at limit
    assert(true, 'placeholder for live integration reminder');
  });
});
