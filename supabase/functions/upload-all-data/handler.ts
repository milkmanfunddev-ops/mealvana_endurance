/**
 * upload-all-data — request handler.
 *
 * Split out of `index.ts` so the real handler can be exercised in tests without
 * `serve()` binding a port. `index.ts` is now the thin wiring file.
 *
 * Auth (ai-cost ticket 01, mp-466): a signed-in caller is required, and the owning
 * user id comes from the token — never from the request body. A body `user_id` is
 * IGNORED, not rejected, so released app versions that name their own id keep
 * working. Every row written to a user-scoped table has its `user_id` overwritten
 * with the token's user id before the upsert.
 *
 * The write still uses the service role (it bypasses RLS); the token is what decides
 * whose rows they are.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { authenticate } from '../_shared/vana/auth.ts';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// deno-lint-ignore no-explicit-any
export type Row = Record<string, any>;

export interface UploadRequest {
  /** Ignored — kept in the type because released clients still send it. */
  user_id?: string;
  dirty_records?: Partial<Record<TableKey, Row[]>>;
}

export interface TableResult {
  success: boolean;
  uploaded: number;
  error?: string;
}

/**
 * The tables this function accepts, in upload order (parents before children).
 * `userScoped` marks the tables that carry a `user_id` column; those rows are
 * stamped with the token's user id. `carb_loading_days` and
 * `carb_loading_day_meals` have no `user_id` column — they hang off
 * `carb_loading_plans`.
 */
export const UPLOAD_TABLES = [
  { key: 'activities', userScoped: true },
  { key: 'events', userScoped: true },
  { key: 'carb_loading_plans', userScoped: true },
  { key: 'carb_loading_days', userScoped: false },
  { key: 'carb_loading_day_meals', userScoped: false },
  { key: 'user_foods', userScoped: true },
  { key: 'feedback', userScoped: true },
  { key: 'food_preferences', userScoped: true },
] as const;

export type TableKey = typeof UPLOAD_TABLES[number]['key'];

/** Only the shape this handler needs — the shared helper returns more. */
type AuthOutcome =
  | { ok: true; v: { userId: string } }
  | { ok: false; status: number; error: string };

export interface UploadDeps {
  /** Caller check. Defaults to the shared `_shared/vana/auth.ts` helper. */
  authenticate?: (req: Request) => Promise<AuthOutcome>;
  /** Service-role client factory, so tests never touch a database. */
  // deno-lint-ignore no-explicit-any
  createAdminClient?: () => any;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/** The token's user id wins over whatever the row carried. */
export function stampOwner(rows: Row[], userId: string): Row[] {
  return rows.map((row) => ({ ...row, user_id: userId }));
}

function defaultAdminClient() {
  // Service role bypasses RLS; ownership is enforced by stampOwner above.
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
}

export async function handleUpload(req: Request, deps: UploadDeps = {}): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const auth = deps.authenticate ?? authenticate;

  // Caller check first: nothing is read and nothing is written for a stranger.
  const result = await auth(req);
  if (!result.ok) {
    return json(
      { success: false, error: result.error, timestamp: new Date().toISOString() },
      result.status,
    );
  }
  const userId = result.v.userId;

  try {
    // `user_id` in the body is deliberately not read — the token decides the owner.
    const { dirty_records }: UploadRequest = await req.json();

    console.log(`Starting upload for user: ${userId}`);

    // If no dirty records provided, that's a success (nothing to upload)
    if (!dirty_records || Object.keys(dirty_records).length === 0) {
      console.log('No dirty records to upload - returning success');
      return json(
        {
          success: true,
          timestamp: new Date().toISOString(),
          results: {},
          message: 'No dirty records to upload',
        },
        200,
      );
    }

    const supabaseClient = (deps.createAdminClient ?? defaultAdminClient)();

    const results: Record<string, TableResult> = {};

    for (const { key, userScoped } of UPLOAD_TABLES) {
      const rows = dirty_records[key];
      if (!rows || rows.length === 0) continue;

      const payload = userScoped ? stampOwner(rows, userId) : rows;

      try {
        console.log(`Uploading ${payload.length} ${key}...`);
        // onConflict is always 'id' (the primary key). A partial-unique-index
        // column here would raise PostgreSQL 42P10.
        const { error } = await supabaseClient
          .from(key)
          .upsert(payload, { onConflict: 'id' });

        if (error) throw error;

        results[key] = { success: true, uploaded: payload.length };
        console.log(`✓ Uploaded ${payload.length} ${key}`);
      } catch (error) {
        // PostgREST hands back a plain `{ message, code, ... }` object, not an Error.
        const message = (error as { message?: string })?.message ?? String(error);
        console.error(`✗ Failed to upload ${key}: ${message}`);
        results[key] = { success: false, uploaded: 0, error: message };
      }
    }

    // Success if no tables were processed (empty payload handled above) OR any table succeeded
    const anySuccess =
      Object.keys(results).length === 0 || Object.values(results).some((r) => r.success);
    const totalUploaded = Object.values(results).reduce((sum, r) => sum + r.uploaded, 0);
    const failedTables = Object.entries(results)
      .filter(([, r]) => !r.success)
      .map(([name]) => name);

    console.log(`Upload completed: ${totalUploaded} total records uploaded`);
    if (failedTables.length > 0) {
      console.log(`Failed tables: ${failedTables.join(', ')}`);
    }

    return json(
      { success: anySuccess, timestamp: new Date().toISOString(), results },
      anySuccess ? 200 : 500,
    );
  } catch (error) {
    console.error('Unexpected error in upload-all-data:', error);
    return json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString(),
      },
      500,
    );
  }
}
