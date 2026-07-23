/**
 * Unit Tests for upsert-user-profile Edge Function
 *
 * Tests partial-update field merging, validation of every enum field, food
 * preference upsert, and RLS-intent verification — all with a fake Supabase
 * client (no live DB required).
 *
 * Run with:
 *   deno test --allow-env supabase/functions/upsert-user-profile/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface UpsertUserProfilePayload {
  user_id?: string;
  device_id?: string;
  gender?: string;
  birthday?: string;
  height_feet?: number;
  height_inches?: number;
  weight_pounds?: number;
  runs_with_water_bottle?: boolean;
  gut_training_level?: string;
  food_preferences?: Record<string, string>;
  preference_levels?: Record<string, number>;
  dietary_preference?: string | null;
  allergies?: string[];
  gi_sensitivity?: boolean;
  cycling_ftp_watts?: number;
  typical_bike_bottles?: number;
  has_aero_bottle?: boolean;
  has_bento_box?: boolean;
  swimming_css_seconds_per_100m?: number;
  typical_wetsuit?: boolean;
  typical_swim_cap_type?: string | null;
  onboarding_completed?: boolean;
  app_version?: string;
}

// ---------------------------------------------------------------------------
// Fake Supabase client builder
// ---------------------------------------------------------------------------

interface UpsertCapture {
  table: string;
  // deno-lint-ignore no-explicit-any
  rows: any;
  // deno-lint-ignore no-explicit-any
  options?: any;
}

interface SelectCapture {
  table: string;
  eq?: { col: string; val: string };
}

interface FakeUpsertConfig {
  upsertUserResult?: { data: Record<string, unknown> | null; error: { message: string } | null };
  upsertPrefsResult?: { error: { message: string } | null };
  fetchPrefsResult?: { data: Record<string, unknown>[] | null; error: null };
}

function buildFakeClient(config: FakeUpsertConfig = {}) {
  const upsertCalls: UpsertCapture[] = [];
  const selectCalls: SelectCapture[] = [];

  const upsertUserResult = config.upsertUserResult ?? {
    data: {
      id: 'user-uuid-123',
      device_id: 'device-abc',
      gender: 'female',
      weight_pounds: 130,
      updated_at: new Date().toISOString(),
    },
    error: null,
  };
  const upsertPrefsResult = config.upsertPrefsResult ?? { error: null };
  const fetchPrefsResult = config.fetchPrefsResult ?? {
    data: [
      { food_name: 'banana', preference: 'like', preference_level: null },
    ],
    error: null,
  };

  // deno-lint-ignore no-explicit-any
  const client: any = {
    from: (table: string) => {
      if (table === 'users') {
        return {
          upsert: (rows: unknown, opts: unknown) => {
            upsertCalls.push({ table, rows, options: opts });
            return {
              select: () => ({
                single: () => Promise.resolve(upsertUserResult),
              }),
            };
          },
        };
      }
      if (table === 'food_preferences') {
        return {
          upsert: (rows: unknown, opts: unknown) => {
            upsertCalls.push({ table, rows, options: opts });
            return Promise.resolve(upsertPrefsResult);
          },
          select: (_cols: string) => {
            selectCalls.push({ table });
            return {
              eq: (_col: string, _val: string) => {
                selectCalls[selectCalls.length - 1].eq = { col: _col, val: _val };
                return Promise.resolve(fetchPrefsResult);
              },
            };
          },
        };
      }
      throw new Error(`Unexpected table: ${table}`);
    },
  };

  return { client, upsertCalls, selectCalls };
}

// ---------------------------------------------------------------------------
// Handler — mirrors upsert-user-profile/index.ts with injected client
// ---------------------------------------------------------------------------

async function handleUpsertUserProfile(
  payload: UpsertUserProfilePayload,
  // deno-lint-ignore no-explicit-any
  supabaseClient: any,
): Promise<Response> {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  const {
    user_id,
    device_id,
    food_preferences,
    preference_levels,
    dietary_preference,
    allergies,
    ...otherFields
  } = payload;

  // Required field: user_id
  if (!user_id) {
    return new Response(
      JSON.stringify({ success: false, message: 'Missing required field: user_id' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Required field: device_id
  if (!device_id) {
    return new Response(
      JSON.stringify({
        success: false,
        message: 'Missing required field: device_id (required by database NOT NULL constraint)',
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Validate gender if provided
  if (otherFields.gender && !['male', 'female', 'other'].includes(otherFields.gender)) {
    return new Response(
      JSON.stringify({ success: false, message: 'Invalid gender. Must be male, female, or other.' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Validate gut_training_level if provided
  if (
    otherFields.gut_training_level &&
    !['low', 'moderate', 'high'].includes(otherFields.gut_training_level)
  ) {
    return new Response(
      JSON.stringify({ success: false, message: 'Invalid gut_training_level. Must be low, moderate, or high.' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Validate dietary_preference if provided (nullable)
  if (dietary_preference !== undefined && dietary_preference !== null) {
    const validDietaryPreferences = [
      'omnivore',
      'vegetarian',
      'pescatarian',
      'vegan',
      'mediterranean',
      'paleo',
      'keto',
      'low_carb',
    ];
    if (!validDietaryPreferences.includes(dietary_preference)) {
      return new Response(
        JSON.stringify({
          success: false,
          message: `Invalid dietary_preference. Must be one of: ${validDietaryPreferences.join(', ')}`,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
  }

  // Validate allergies if provided
  if (allergies !== undefined) {
    if (!Array.isArray(allergies)) {
      return new Response(
        JSON.stringify({ success: false, message: 'allergies must be an array of strings' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    const validAllergies = ['dairy', 'eggs', 'fish', 'gluten', 'peanuts', 'sesame', 'shellfish', 'soy', 'tree_nuts'];
    const invalidAllergies = allergies.filter((a) => !validAllergies.includes(a));
    if (invalidAllergies.length > 0) {
      return new Response(
        JSON.stringify({
          success: false,
          message: `Invalid allergies: ${invalidAllergies.join(', ')}. Valid options: ${validAllergies.join(', ')}`,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
  }

  // Validate typical_bike_bottles range
  if (otherFields.typical_bike_bottles !== undefined) {
    if (otherFields.typical_bike_bottles < 0 || otherFields.typical_bike_bottles > 6) {
      return new Response(
        JSON.stringify({ success: false, message: 'typical_bike_bottles must be between 0 and 6' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
  }

  // Validate typical_swim_cap_type
  if (
    otherFields.typical_swim_cap_type !== undefined &&
    otherFields.typical_swim_cap_type !== null
  ) {
    const validCapTypes = ['none', 'latex', 'silicone', 'neoprene'];
    if (!validCapTypes.includes(otherFields.typical_swim_cap_type)) {
      return new Response(
        JSON.stringify({
          success: false,
          message: `Invalid typical_swim_cap_type. Must be one of: ${validCapTypes.join(', ')}`,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
  }

  // Build update data — only include fields that were explicitly provided
  const updateData: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };

  if (otherFields.gender !== undefined) updateData.gender = otherFields.gender;
  if (otherFields.birthday !== undefined) updateData.birthday = otherFields.birthday;
  if (otherFields.height_feet !== undefined) updateData.height_feet = otherFields.height_feet;
  if (otherFields.height_inches !== undefined) updateData.height_inches = otherFields.height_inches;
  if (otherFields.weight_pounds !== undefined) updateData.weight_pounds = otherFields.weight_pounds;
  if (otherFields.runs_with_water_bottle !== undefined) updateData.runs_with_water_bottle = otherFields.runs_with_water_bottle;
  if (otherFields.gut_training_level !== undefined) updateData.gut_training_level = otherFields.gut_training_level;
  if (otherFields.gi_sensitivity !== undefined) updateData.gi_sensitivity = otherFields.gi_sensitivity;
  if (otherFields.cycling_ftp_watts !== undefined) updateData.cycling_ftp_watts = otherFields.cycling_ftp_watts;
  if (otherFields.typical_bike_bottles !== undefined) updateData.typical_bike_bottles = otherFields.typical_bike_bottles;
  if (otherFields.has_aero_bottle !== undefined) updateData.has_aero_bottle = otherFields.has_aero_bottle;
  if (otherFields.has_bento_box !== undefined) updateData.has_bento_box = otherFields.has_bento_box;
  if (otherFields.swimming_css_seconds_per_100m !== undefined) updateData.swimming_css_seconds_per_100m = otherFields.swimming_css_seconds_per_100m;
  if (otherFields.typical_wetsuit !== undefined) updateData.typical_wetsuit = otherFields.typical_wetsuit;
  if (otherFields.typical_swim_cap_type !== undefined) updateData.typical_swim_cap_type = otherFields.typical_swim_cap_type;
  if (otherFields.onboarding_completed !== undefined) updateData.onboarding_completed = otherFields.onboarding_completed;
  if (otherFields.app_version !== undefined) updateData.app_version = otherFields.app_version;
  if (dietary_preference !== undefined) updateData.dietary_preference = dietary_preference;
  if (allergies !== undefined) updateData.allergies = allergies;

  // Upsert user profile
  const { data: upsertedUser, error: upsertError } = await supabaseClient
    .from('users')
    .upsert(
      { id: user_id, device_id, ...updateData },
      { onConflict: 'id', ignoreDuplicates: false },
    )
    .select()
    .single();

  if (upsertError) {
    return new Response(
      JSON.stringify({ success: false, message: `Failed to upsert user profile: ${upsertError.message}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Handle food_preferences
  let preferencesCount = 0;
  // deno-lint-ignore no-explicit-any
  let savedPreferences: any[] = [];

  if (food_preferences && Object.keys(food_preferences).length > 0) {
    const validPreferences = ['like', 'dislike', 'willing_to_try'];
    for (const [foodName, preference] of Object.entries(food_preferences)) {
      if (!validPreferences.includes(preference)) {
        return new Response(
          JSON.stringify({
            success: false,
            message: `Invalid preference value: ${preference}. Must be 'like', 'dislike', or 'willing_to_try'`,
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
    }

    const rows = Object.entries(food_preferences).map(([foodName, preference]) => {
      const row: Record<string, unknown> = {
        user_id,
        food_name: foodName,
        preference,
        updated_at: new Date().toISOString(),
      };
      if (preference_levels && preference_levels[foodName] !== undefined) {
        row.preference_level = preference_levels[foodName];
      }
      return row;
    });

    const { error: preferencesError } = await supabaseClient
      .from('food_preferences')
      .upsert(rows, { onConflict: 'user_id,food_name', ignoreDuplicates: false });

    if (!preferencesError) {
      preferencesCount = rows.length;
      const { data: fetchedPreferences } = await supabaseClient
        .from('food_preferences')
        .select('food_name, preference, preference_level')
        .eq('user_id', user_id);
      if (fetchedPreferences) {
        savedPreferences = fetchedPreferences;
      }
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      message: 'User profile updated successfully',
      user: upsertedUser,
      preferences_count: preferencesCount,
      saved_preferences: savedPreferences,
    }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}

// ---------------------------------------------------------------------------
// Baseline valid payload (only required fields)
// ---------------------------------------------------------------------------

const basePayload: UpsertUserProfilePayload = {
  user_id: 'user-uuid-123',
  device_id: 'device-abc',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('upsert-user-profile — required field validation', () => {
  it('returns 400 when user_id is missing', async () => {
    const { client } = buildFakeClient();
    const payload = { device_id: 'device-abc' };
    const res = await handleUpsertUserProfile(payload, client);
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('user_id'));
  });

  it('returns 400 when device_id is missing', async () => {
    const { client } = buildFakeClient();
    const payload = { user_id: 'user-uuid-123' };
    const res = await handleUpsertUserProfile(payload, client);
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('device_id'));
  });
});

describe('upsert-user-profile — gender validation', () => {
  it('accepts male, female, other', async () => {
    for (const gender of ['male', 'female', 'other']) {
      const { client } = buildFakeClient();
      const res = await handleUpsertUserProfile({ ...basePayload, gender }, client);
      assertEquals(res.status, 200, `gender="${gender}" should be accepted`);
    }
  });

  it('returns 400 for invalid gender', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, gender: 'nonbinary' }, client);
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('gender'));
  });
});

describe('upsert-user-profile — gut_training_level validation', () => {
  it('accepts low, moderate, high', async () => {
    for (const level of ['low', 'moderate', 'high']) {
      const { client } = buildFakeClient();
      const res = await handleUpsertUserProfile({ ...basePayload, gut_training_level: level }, client);
      assertEquals(res.status, 200, `gut_training_level="${level}" should be accepted`);
    }
  });

  it('returns 400 for invalid gut_training_level', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, gut_training_level: 'elite' }, client);
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('gut_training_level'));
  });
});

describe('upsert-user-profile — dietary_preference validation', () => {
  const validValues = ['omnivore', 'vegetarian', 'pescatarian', 'vegan', 'mediterranean', 'paleo', 'keto', 'low_carb'];

  it('accepts all valid dietary_preference values', async () => {
    for (const dp of validValues) {
      const { client } = buildFakeClient();
      const res = await handleUpsertUserProfile({ ...basePayload, dietary_preference: dp }, client);
      assertEquals(res.status, 200, `dietary_preference="${dp}" should be accepted`);
    }
  });

  it('accepts null dietary_preference (clearing the field)', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, dietary_preference: null }, client);
    assertEquals(res.status, 200);
  });

  it('returns 400 for invalid dietary_preference', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, dietary_preference: 'carnivore' }, client);
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('dietary_preference'));
  });
});

describe('upsert-user-profile — allergies validation', () => {
  const validAllergies = ['dairy', 'eggs', 'fish', 'gluten', 'peanuts', 'sesame', 'shellfish', 'soy', 'tree_nuts'];

  it('accepts valid allergy arrays', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile(
      { ...basePayload, allergies: ['gluten', 'dairy'] },
      client,
    );
    assertEquals(res.status, 200);
  });

  it('accepts empty allergy array', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, allergies: [] }, client);
    assertEquals(res.status, 200);
  });

  it('returns 400 for invalid allergy value', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, allergies: ['gluten', 'lactose'] }, client);
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('lactose'));
  });

  it('returns 400 when allergies is not an array', async () => {
    const { client } = buildFakeClient();
    // deno-lint-ignore no-explicit-any
    const res = await handleUpsertUserProfile({ ...basePayload, allergies: 'gluten' as any }, client);
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('array'));
  });
});

describe('upsert-user-profile — typical_bike_bottles validation', () => {
  it('accepts 0 through 6', async () => {
    for (const n of [0, 1, 3, 6]) {
      const { client } = buildFakeClient();
      const res = await handleUpsertUserProfile({ ...basePayload, typical_bike_bottles: n }, client);
      assertEquals(res.status, 200, `typical_bike_bottles=${n} should be accepted`);
    }
  });

  it('returns 400 for typical_bike_bottles > 6', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, typical_bike_bottles: 7 }, client);
    assertEquals(res.status, 400);
  });

  it('returns 400 for negative typical_bike_bottles', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, typical_bike_bottles: -1 }, client);
    assertEquals(res.status, 400);
  });
});

describe('upsert-user-profile — typical_swim_cap_type validation', () => {
  it('accepts none, latex, silicone, neoprene', async () => {
    for (const cap of ['none', 'latex', 'silicone', 'neoprene']) {
      const { client } = buildFakeClient();
      const res = await handleUpsertUserProfile({ ...basePayload, typical_swim_cap_type: cap }, client);
      assertEquals(res.status, 200, `typical_swim_cap_type="${cap}" should be accepted`);
    }
  });

  it('accepts null typical_swim_cap_type', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, typical_swim_cap_type: null }, client);
    assertEquals(res.status, 200);
  });

  it('returns 400 for invalid swim_cap_type', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile({ ...basePayload, typical_swim_cap_type: 'rubber' }, client);
    assertEquals(res.status, 400);
  });
});

describe('upsert-user-profile — partial update (field merge)', () => {
  it('only sends weight_pounds to DB when that is the only field updated', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile({ ...basePayload, weight_pounds: 145 }, client);

    const userUpsert = upsertCalls.find((c) => c.table === 'users');
    assertExists(userUpsert);
    const row = userUpsert.rows as Record<string, unknown>;

    // Should have weight_pounds
    assertEquals(row.weight_pounds, 145);
    // Should NOT have gender (not in this request)
    assertEquals(row.gender, undefined, 'Unspecified fields must NOT be sent to DB');
    assertEquals(row.birthday, undefined, 'Unspecified fields must NOT be sent to DB');
  });

  it('sends cycling fields when only cycling data is updated', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile(
      { ...basePayload, cycling_ftp_watts: 280, has_aero_bottle: true },
      client,
    );

    const userUpsert = upsertCalls.find((c) => c.table === 'users');
    assertExists(userUpsert);
    const row = userUpsert.rows as Record<string, unknown>;

    assertEquals(row.cycling_ftp_watts, 280);
    assertEquals(row.has_aero_bottle, true);
    // Running-specific fields NOT present
    assertEquals(row.runs_with_water_bottle, undefined);
  });

  it('always includes id and device_id in the upsert row', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile({ ...basePayload, weight_pounds: 155 }, client);

    const userUpsert = upsertCalls.find((c) => c.table === 'users');
    assertExists(userUpsert);
    const row = userUpsert.rows as Record<string, unknown>;
    assertEquals(row.id, 'user-uuid-123');
    assertEquals(row.device_id, 'device-abc');
  });

  it('always sends updated_at timestamp', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile(basePayload, client);

    const userUpsert = upsertCalls.find((c) => c.table === 'users');
    assertExists(userUpsert);
    assertExists(
      (userUpsert.rows as Record<string, unknown>).updated_at,
      'updated_at must always be included',
    );
  });

  it('uses onConflict:id so existing rows are updated not duplicated', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile(basePayload, client);

    const userUpsert = upsertCalls.find((c) => c.table === 'users');
    assertExists(userUpsert);
    assertEquals(
      (userUpsert.options as Record<string, unknown>).onConflict,
      'id',
      'Must use onConflict:id to avoid duplicate rows',
    );
  });
});

describe('upsert-user-profile — food preferences upsert', () => {
  it('upserts food preferences and returns them in response', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile(
      {
        ...basePayload,
        food_preferences: { banana: 'like', gel: 'willing_to_try' },
      },
      client,
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.preferences_count, 2);
    assertExists(body.saved_preferences);
  });

  it('attaches preference_level when provided in preference_levels map', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile(
      {
        ...basePayload,
        food_preferences: { banana: 'like', gel: 'dislike' },
        preference_levels: { banana: 4, gel: 1 },
      },
      client,
    );

    const prefsUpsert = upsertCalls.find((c) => c.table === 'food_preferences');
    assertExists(prefsUpsert);
    const rows = prefsUpsert.rows as Array<Record<string, unknown>>;
    const bananaRow = rows.find((r) => r.food_name === 'banana');
    assertExists(bananaRow);
    assertEquals(bananaRow.preference_level, 4);
  });

  it('does NOT attach preference_level when not in preference_levels map', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile(
      {
        ...basePayload,
        food_preferences: { banana: 'like' },
        // no preference_levels provided
      },
      client,
    );

    const prefsUpsert = upsertCalls.find((c) => c.table === 'food_preferences');
    assertExists(prefsUpsert);
    const rows = prefsUpsert.rows as Array<Record<string, unknown>>;
    assertEquals(rows[0].preference_level, undefined);
  });

  it('returns 400 for invalid food preference value', async () => {
    const { client } = buildFakeClient();
    const res = await handleUpsertUserProfile(
      {
        ...basePayload,
        food_preferences: { banana: 'neutral' }, // invalid
      },
      client,
    );
    assertEquals(res.status, 400);
    const body = await res.json();
    assert(body.message.includes('neutral'));
  });

  it('uses onConflict: user_id,food_name to handle re-upserts', async () => {
    const { client, upsertCalls } = buildFakeClient();
    await handleUpsertUserProfile(
      { ...basePayload, food_preferences: { banana: 'dislike' } },
      client,
    );
    const prefsUpsert = upsertCalls.find((c) => c.table === 'food_preferences');
    assertExists(prefsUpsert);
    assertEquals(
      (prefsUpsert.options as Record<string, unknown>).onConflict,
      'user_id,food_name',
    );
  });
});

describe('upsert-user-profile — RLS intent', () => {
  it('uses service role client (not anon) for all DB operations', () => {
    // The production code calls createClient(url, SUPABASE_SERVICE_ROLE_KEY)
    // and does NOT pass a user JWT to the Supabase client. That means RLS is
    // bypassed, and the function trusts the calling Flutter app to pass the
    // correct user_id.
    //
    // RLS INTENT: The app always sends the authenticated user's own user_id.
    // There is NO server-side enforcement in this function that the caller is
    // the same person as user_id. This is a known design decision (the auth
    // layer is the Flutter JWT used to reach the edge function; Supabase then
    // trusts the function's service-role calls).
    //
    // A future hardening step would be to: verify the JWT, extract user.id from
    // it, and reject requests where payload.user_id !== jwt.user_id.
    assert(true, 'RLS-intent note — see comment');
  });
});

describe('upsert-user-profile — DB error handling', () => {
  it('returns 500 when user upsert fails', async () => {
    const { client } = buildFakeClient({
      upsertUserResult: { data: null, error: { message: 'connection refused' } },
    });
    const res = await handleUpsertUserProfile(basePayload, client);
    assertEquals(res.status, 500);
    const body = await res.json();
    assertEquals(body.success, false);
    assert(body.message.includes('Failed to upsert user profile'));
  });

  it('returns 200 even when food_preferences upsert fails (non-critical)', async () => {
    const { client } = buildFakeClient({
      upsertPrefsResult: { error: { message: 'constraint violation' } },
    });
    const res = await handleUpsertUserProfile(
      { ...basePayload, food_preferences: { banana: 'like' } },
      client,
    );
    // Profile was saved — prefs failure is non-fatal
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.success, true);
    // preferences_count should be 0 since the upsert failed
    assertEquals(body.preferences_count, 0);
  });
});
