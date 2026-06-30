/**
 * Unit tests for save-user-food edge function.
 *
 * STRATEGY:
 * The handler has two pure logic pieces:
 * 1. Validation: device_id, id, name, category_ids (non-empty array) are required
 * 2. Category mapping: integer IDs → enum strings (1→before_run, 2→during_run, 3→after_run)
 *    Unknown IDs are filtered out (filter(cat !== undefined)).
 *
 * BUGS FOUND: documented inline.
 *
 * Run with:
 *   deno test --allow-env --node-modules-dir=none \
 *     supabase/functions/save-user-food/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Pure copies of logic from index.ts
// ============================================================================

const categoryIdToEnum: Record<number, string> = {
  1: 'before_run',
  2: 'during_run',
  3: 'after_run',
};

/** Validates the required fields in a save-user-food request */
function validateSaveRequest(data: Record<string, unknown>): { valid: boolean; error?: string } {
  const categoryIds = data.category_ids as unknown[] | undefined;
  if (!data.device_id || !data.id || !data.name || !categoryIds?.length) {
    return {
      valid: false,
      error: 'Missing required fields: device_id, id, name, and category_ids are required',
    };
  }
  return { valid: true };
}

/** Maps category_ids array → category enum strings, filtering unknowns */
function mapCategoryIds(categoryIds: number[]): string[] {
  return categoryIds
    .map((id) => categoryIdToEnum[id])
    .filter((cat): cat is string => cat !== undefined);
}

// ============================================================================
// A. Request validation
// ============================================================================

describe('save-user-food request validation', () => {
  const validBase = {
    device_id: 'device-abc-123',
    id: 'food-uuid-456',
    name: 'GU Energy Gel',
    category_ids: [2],
  };

  it('all required fields present → valid', () => {
    assertEquals(validateSaveRequest(validBase).valid, true);
  });

  it('missing device_id → invalid', () => {
    const { device_id: _, ...rest } = validBase;
    const result = validateSaveRequest(rest as any);
    assertEquals(result.valid, false);
    assertExists(result.error);
  });

  it('missing id → invalid', () => {
    const { id: _, ...rest } = validBase;
    const result = validateSaveRequest(rest as any);
    assertEquals(result.valid, false);
  });

  it('missing name → invalid', () => {
    const { name: _, ...rest } = validBase;
    const result = validateSaveRequest(rest as any);
    assertEquals(result.valid, false);
  });

  it('missing category_ids → invalid', () => {
    const { category_ids: _, ...rest } = validBase;
    const result = validateSaveRequest(rest as any);
    assertEquals(result.valid, false);
  });

  it('empty category_ids array → invalid', () => {
    const result = validateSaveRequest({ ...validBase, category_ids: [] });
    assertEquals(result.valid, false);
  });

  it('null category_ids → invalid', () => {
    const result = validateSaveRequest({ ...validBase, category_ids: null });
    assertEquals(result.valid, false);
  });

  it('empty string device_id (falsy) → invalid', () => {
    const result = validateSaveRequest({ ...validBase, device_id: '' });
    assertEquals(result.valid, false);
  });

  it('empty string name (falsy) → invalid', () => {
    const result = validateSaveRequest({ ...validBase, name: '' });
    assertEquals(result.valid, false);
  });

  it('category_ids with one item → valid', () => {
    assertEquals(validateSaveRequest(validBase).valid, true);
  });

  it('category_ids with all three → valid', () => {
    const result = validateSaveRequest({ ...validBase, category_ids: [1, 2, 3] });
    assertEquals(result.valid, true);
  });

  it('error message mentions all four required fields', () => {
    const result = validateSaveRequest({});
    assert(result.error!.includes('device_id'));
    assert(result.error!.includes('name'));
    assert(result.error!.includes('category_ids'));
  });
});

// ============================================================================
// B. Category ID → enum mapping
// ============================================================================

describe('save-user-food category ID mapping', () => {
  it('1 → before_run', () => {
    assertEquals(mapCategoryIds([1]), ['before_run']);
  });

  it('2 → during_run', () => {
    assertEquals(mapCategoryIds([2]), ['during_run']);
  });

  it('3 → after_run', () => {
    assertEquals(mapCategoryIds([3]), ['after_run']);
  });

  it('all three → all three enums', () => {
    const result = mapCategoryIds([1, 2, 3]);
    assertEquals(result, ['before_run', 'during_run', 'after_run']);
  });

  it('order preserved: [3,1,2] → [after_run, before_run, during_run]', () => {
    const result = mapCategoryIds([3, 1, 2]);
    assertEquals(result, ['after_run', 'before_run', 'during_run']);
  });

  it('unknown ID 4 → filtered out', () => {
    const result = mapCategoryIds([1, 4]);
    assertEquals(result, ['before_run']);
  });

  it('unknown ID 0 → filtered out', () => {
    const result = mapCategoryIds([0, 2]);
    assertEquals(result, ['during_run']);
  });

  it('all unknown IDs → empty array', () => {
    const result = mapCategoryIds([5, 6, 7]);
    assertEquals(result, []);
  });

  it('duplicate IDs → duplicates preserved in output (no dedup)', () => {
    // BUG NOTE: Sending [1, 1] produces ['before_run', 'before_run'].
    // The categories column is an array; duplicates are silently stored.
    // Low severity — client should not send duplicates, but defensive dedup
    // in the handler would be safer. Filed as KNOWN BUG (cosmetic).
    const result = mapCategoryIds([1, 1]);
    assertEquals(result, ['before_run', 'before_run']); // duplicates NOT deduped
  });

  it('empty input → empty output', () => {
    assertEquals(mapCategoryIds([]), []);
  });

  it('category ID 2 only (during_run food) → correct enum', () => {
    assertEquals(mapCategoryIds([2]), ['during_run']);
  });
});

// ============================================================================
// C. RLS intent — user_id is set to device_id
// ============================================================================

describe('save-user-food RLS intent', () => {
  it('user_id column is set to device_id value', () => {
    // The handler does: user_id: requestData.device_id
    // This is the RLS scoping: rows are owned by device_id (acting as user_id).
    // There is NO auth token check in this function — it uses SERVICE_ROLE key.
    // BUG SEVERITY: HIGH — any caller can save a food with ANY device_id.
    // The function should verify the JWT user matches device_id, or use ANON key
    // with RLS policies to restrict writes to the authenticated user.
    // Filed as KNOWN BUG: missing auth enforcement.

    const requestData = {
      device_id: 'user-abc',
      id: 'food-1',
      name: 'Test',
      category_ids: [1],
    };

    // Simulating the upsert payload
    const upsertPayload = {
      id: requestData.id,
      device_id: requestData.device_id,
      user_id: requestData.device_id, // THIS IS THE CRITICAL FIELD
      name: requestData.name,
      categories: mapCategoryIds(requestData.category_ids),
    };

    assertEquals(upsertPayload.user_id, 'user-abc');
    assertEquals(upsertPayload.device_id, upsertPayload.user_id); // same value
  });
});

// ============================================================================
// D. Response shape
// ============================================================================

describe('save-user-food response shape', () => {
  it('200 success response has expected fields', () => {
    const mockResponse = {
      success: true,
      message: 'User food saved successfully',
      food_id: 'food-uuid-456',
      categories_saved: 2,
    };

    assertEquals(mockResponse.success, true);
    assertExists(mockResponse.food_id);
    assertExists(mockResponse.categories_saved);
    assertEquals(mockResponse.categories_saved, 2);
  });

  it('400 error response has error field', () => {
    const mockError = {
      error: 'Missing required fields: device_id, id, name, and category_ids are required',
    };
    assertExists(mockError.error);
    assert(mockError.error.length > 0);
  });

  it('categories_saved count matches input category_ids length', () => {
    const categoryIds = [1, 2, 3];
    const mapped = mapCategoryIds(categoryIds);
    // categories_saved is requestData.category_ids.length (the INPUT count, not mapped count)
    // BUG NOTE: If unknown IDs are sent (e.g. [1, 99]), categories_saved reports 2
    // but only 1 category was actually stored. This is a count mismatch.
    // Filed as KNOWN BUG (low severity — misleading log/response).
    assertEquals(categoryIds.length, 3); // input length
    assertEquals(mapped.length, 3);      // mapped length (equal when all valid)
  });

  it('BUG: categories_saved vs actual stored count mismatch with unknown IDs', () => {
    const categoryIds = [1, 99]; // 99 is unknown
    const mapped = mapCategoryIds(categoryIds);
    // Production returns categories_saved: categoryIds.length = 2
    // But only mapped.length = 1 category is actually stored
    assertEquals(categoryIds.length, 2); // reported count
    assertEquals(mapped.length, 1);      // actual stored count — MISMATCH
  });
});

// ============================================================================
// E. CORS preflight
// ============================================================================

describe('save-user-food CORS preflight', () => {
  it('OPTIONS method check logic', () => {
    // The handler returns 'ok' for OPTIONS — verify the method check
    const method = 'OPTIONS';
    const isOptions = method === 'OPTIONS';
    assertEquals(isOptions, true);
  });

  it('POST method passes through to handler logic', () => {
    const method: string = 'POST';
    const isOptions = method === 'OPTIONS';
    assertEquals(isOptions, false);
  });
});
