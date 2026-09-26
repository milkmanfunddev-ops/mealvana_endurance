/**
 * The `delete` action of garmin-user-mapping, built with its collaborators
 * injected so index.test.ts drives this exact code against fakes.
 *
 * Testing-wave ticket 138 (Findings 112-010, 121-010): a disconnect used to
 * delete only our mapping row, so Garmin kept pushing for the athlete.
 * The registration is now deleted AT Garmin first (Start Guide §3.1), with
 * a fresh token; a Garmin failure is logged and the row is still deleted,
 * because from our side the athlete is disconnected either way.
 */

import type { GarminDeregistrationOutcome } from '../_shared/garmin/token.ts';

// deno-lint-ignore no-explicit-any
type SupabaseLike = any;

export interface DeleteMappingDeps {
  /** Deregisters the user at Garmin; never throws by contract, but is guarded anyway. */
  deregister: (userId: string) => Promise<GarminDeregistrationOutcome>;
}

export type DeleteMappingResult =
  | { ok: true; remaining: number; garmin: GarminDeregistrationOutcome }
  | { ok: false; status: 500; message: string; details: string };

/**
 * Deregisters at Garmin, then deletes the user's mapping row(s) and verifies
 * none remain. Safe to repeat: a second run finds no token (`no_token`) and
 * deletes nothing new.
 */
export async function deleteGarminMapping(
  supabase: SupabaseLike,
  userId: string,
  garminUserId: string | undefined,
  deps: DeleteMappingDeps,
): Promise<DeleteMappingResult> {
  let garmin: GarminDeregistrationOutcome = 'failed';
  try {
    garmin = await deps.deregister(userId);
  } catch (err) {
    console.error('[garmin-user-mapping] Garmin deregistration threw:', err);
  }

  let query = supabase.from('garmin_user_mappings').delete().eq('user_id', userId);
  if (garminUserId) {
    query = query.eq('garmin_user_id', garminUserId);
  }

  const { error } = await query;
  if (error) {
    console.error('[garmin-user-mapping] Delete error:', error);
    return {
      ok: false,
      status: 500,
      message: 'Failed to delete Garmin mapping',
      details: error.message,
    };
  }

  let countQuery = supabase
    .from('garmin_user_mappings')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId);
  if (garminUserId) {
    countQuery = countQuery.eq('garmin_user_id', garminUserId);
  }

  const { count, error: countError } = await countQuery;
  if (countError) {
    console.error('[garmin-user-mapping] Delete verification error:', countError);
    return {
      ok: false,
      status: 500,
      message: 'Failed to verify Garmin mapping deletion',
      details: countError.message,
    };
  }

  return { ok: true, remaining: count ?? 0, garmin };
}
