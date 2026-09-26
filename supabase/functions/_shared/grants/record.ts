/**
 * Where a Grant of `pro` came from (mp-615): one `public.pro_grants` row per
 * Grant made (migration 20260926070000_pro_grants_source.sql). The app reads
 * the account's latest row to label the Grant on the Subscription screen,
 * since RevenueCat's customer info names no source.
 *
 * Written right after the RevenueCat grant succeeds. The account already
 * holds the grant, so a failed write is logged and swallowed: the app then
 * falls back to reading the source from the Grant's length, as it did before
 * this table.
 */

import type { Db } from '../vana/env.ts';

export type GrantSource = 'grace' | 'code' | 'coach';

/** Records a Grant just made; never throws. */
export type RecordGrant = (userId: string, source: GrantSource, days: number) => Promise<void>;

/** A [RecordGrant] writing to `pro_grants` through a service-role client. */
export function recordGrantTo(db: Db): RecordGrant {
  return async (userId, source, days) => {
    try {
      const { error } = await db.from('pro_grants').insert({ user_id: userId, source, pro_days: days });
      if (error) console.error(`[pro_grants] ${source} grant for ${userId} not recorded: ${error.message}`);
    } catch (e) {
      console.error(`[pro_grants] ${source} grant for ${userId} not recorded:`, e);
    }
  };
}
