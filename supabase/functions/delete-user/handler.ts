/**
 * The delete-user request handler, built with its clients injected so the
 * tests (index.test.ts) run this exact code against fakes. index.ts wires it to
 * the caller's JWT client, the service-role client and the one RevenueCat REST
 * client (_shared/revenuecat).
 *
 * Deletes the caller's own account:
 *   1. public.users (CASCADE deletes the related data)
 *   2. auth.users (the Supabase auth account)
 *   3. the RevenueCat customer, whose id is the Supabase user id (02-005,
 *      ticket 95), so "deletes your account and all of its data" holds there
 *      too. It runs only once the auth account is gone, and a RevenueCat
 *      failure never blocks the delete: it is logged with the user id so it
 *      can be retried by hand.
 */

import type { RevenueCatClient } from '../_shared/revenuecat/client.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// deno-lint-ignore no-explicit-any
type Client = any;

export interface DeleteUserDeps {
  /** A client carrying the caller's Authorization header (auth.getUser only). */
  userClient: (authHeader: string) => Client;
  /** The service-role client: public.users delete and auth.admin.deleteUser. */
  admin: () => Client;
  /** RevenueCat's REST API; throws when the secret key is not configured. */
  revenueCat: () => RevenueCatClient;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function makeDeleteUserHandler(deps: DeleteUserDeps) {
  return async function handle(req: Request): Promise<Response> {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    try {
      const authHeader = req.headers.get('Authorization');
      if (!authHeader) {
        return json({ success: false, message: 'Missing authorization header' }, 401);
      }

      const { data: { user }, error: userError } = await deps.userClient(authHeader).auth.getUser();
      if (userError || !user) {
        console.error('Auth error:', userError);
        return json({ success: false, message: 'Invalid or expired authentication token' }, 401);
      }
      const userId: string = user.id;
      console.log(`Deleting user account: ${userId}`);

      const admin = deps.admin();

      // Step 1: public.users; CASCADE deletes the related data.
      const { error: publicDeleteError } = await admin.from('users').delete().eq('id', userId);
      if (publicDeleteError) {
        // Continue anyway: the user might not have a public.users row.
        console.error('Error deleting from public.users:', publicDeleteError);
      } else {
        console.log(`Deleted user from public.users: ${userId}`);
      }

      // Step 2: the auth account.
      const { error: authDeleteError } = await admin.auth.admin.deleteUser(userId);
      if (authDeleteError) {
        console.error('Error deleting from auth.users:', authDeleteError);
        return json({ success: false, message: `Failed to delete auth account: ${authDeleteError.message}` }, 500);
      }
      console.log(`Successfully deleted auth account: ${userId}`);

      // Step 3: the RevenueCat customer. Never blocks the delete.
      await deleteRevenueCatCustomer(deps, userId);

      return json({ success: true, message: 'Account deleted successfully', deleted_user_id: userId }, 200);
    } catch (error) {
      console.error('Unexpected error:', error);
      return json({ success: false, message: 'Internal server error' }, 500);
    }
  };
}

async function deleteRevenueCatCustomer(deps: DeleteUserDeps, userId: string): Promise<void> {
  try {
    await deps.revenueCat().deleteCustomer(userId);
    console.log(`Deleted RevenueCat customer: ${userId}`);
  } catch (e) {
    console.error(
      `[delete-user] RevenueCat customer delete failed for user ${userId}; retry DELETE /customers/${userId}: ${
        (e as Error).message
      }`,
    );
  }
}
