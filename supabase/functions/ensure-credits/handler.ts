/**
 * The ensure-credits request handler, built with its client injected so the
 * tests (handler.test.ts) run this exact code against a fake. index.ts wires
 * it to the service-role client. Why the function exists is in index.ts.
 *
 * One unit-aware read (round develop-2026-10, ticket 23, D9): after the grant,
 * the caller's token_wallets row is read with select('*'). Develop counts
 * whole tokens and its migrations have no `unit` column. Dev's database once
 * carried mealplanning's micro-dollar accounting, which added `unit` and
 * converted wallets to 'usd_micro'; a wallet like that shows a balance in the
 * millions and takes develop's +50 / -1 in the wrong unit. When the row has a
 * `unit` that is not 'credit', a Sentry warning records it and the answer is
 * still 200. On prod the column is absent and nothing happens. Develop never
 * writes `unit`.
 */

import { handleCors } from '../_shared/cors.ts';
import { errorResponse, jsonResponse, serverError } from '../_shared/responses.ts';
import { captureEdgeError, edgeBreadcrumb } from '../_shared/sentry.ts';

// deno-lint-ignore no-explicit-any
type Client = any;

export interface EnsureCreditsDeps {
  /** The service-role client: auth.getUser(token), the RPC and the wallet read. */
  admin: () => Client;
  freeMonthly: number;
  enforced: boolean;
}

export function makeEnsureCreditsHandler(deps: EnsureCreditsDeps) {
  return async function handle(req: Request): Promise<Response> {
    const cors = handleCors(req);
    if (cors) return cors;

    try {
      const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
      if (!token) return errorResponse('Missing authorization header', 401);

      const admin = deps.admin();
      const { data: { user }, error: authError } = await admin.auth.getUser(token);
      if (authError || !user) {
        // Expected client fault: a breadcrumb, not an event.
        return errorResponse('Invalid or expired token', 401, authError?.message);
      }

      const { data, error } = await admin.rpc('ensure_free_credits', {
        p_user_id: user.id,
        p_amount: deps.freeMonthly,
      });

      if (error) {
        return serverError(error, false, 'Could not provision wallet');
      }

      const balance = typeof data === 'number' ? data : 0;
      await warnIfWalletNotInTokens(admin, user.id, balance);

      return jsonResponse({
        balance,
        free_monthly: deps.freeMonthly,
        enforced: deps.enforced,
      });
    } catch (e) {
      return serverError(e, false, 'Unexpected error');
    }
  };
}

/** Never throws, never changes the answer. */
async function warnIfWalletNotInTokens(admin: Client, userId: string, balance: number): Promise<void> {
  try {
    const { data: row, error } = await admin
      .from('token_wallets')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();
    if (error) {
      // The check is advisory; the grant already succeeded. Leave a server
      // log and a breadcrumb so the skipped check is visible.
      console.warn(`[credits] wallet unit check skipped for ${userId}: ${error.message ?? error}`);
      edgeBreadcrumb('[credits] wallet unit check skipped', { userId, error: error.message ?? String(error) });
      return;
    }
    if (row && 'unit' in row && row.unit != null && row.unit !== 'credit') {
      captureEdgeError(new Error('wallet not in whole tokens'), {
        level: 'warning',
        message: '[credits] wallet not in whole tokens',
        extra: { userId, unit: row.unit, balance: row.balance ?? balance },
      });
    }
  } catch (e) {
    console.warn(`[credits] wallet unit check threw for ${userId}: ${(e as Error)?.message ?? e}`);
    edgeBreadcrumb('[credits] wallet unit check threw', { userId, error: String(e) });
  }
}
