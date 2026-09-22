// The grace month, granted on flip day (mp-455 §1-3, ticket paywall/06).
//
// Every registered account created before the flip gets 30 days of `pro`
// through RevenueCat and the `founding_member` attribute. A dry run by default:
// it prints each selected account, what it would do, and the count. It writes
// only with --write, and skips what an account already holds, so a second run
// does nothing. Dev first, then production with Lee's go.
//
// The selection and the grant live in supabase/functions/_shared/grace/grace.ts
// (the old-install claim, ticket 09, reuses them). This file only reads flags
// and credentials and prints.
//
// Runs under Deno (the shared module is TypeScript):
//
//   export SUPABASE_SERVICE_ROLE_KEY=...   # of the project named by --project
//   export REVENUECAT_SECRET_KEY=...       # v2 secret key (secrets/revenuecat.env)
//   deno run --allow-net --allow-env scripts/grace-grant.mjs --project dev --flip 2026-10-01T00:00:00-05:00
//   deno run --allow-net --allow-env scripts/grace-grant.mjs --project dev --flip ... --write --user <uid>
//   deno run --allow-net --allow-env scripts/grace-grant.mjs --project prod --flip ... --write --all
//
// Flags:
//   --project dev|prod   required; the service role key must belong to it
//   --flip <ISO>         required, with a zone (Z or ±hh:mm): accounts created strictly before it qualify
//   --write              actually grant; without it nothing is written
//   --user <uid>         only this account (repeatable); still subject to the selection
//   --all                required with --write when no --user is given
//
// Undo one account: RevenueCat dashboard → customer → revoke the promotional
// entitlement and delete the founding_member attribute, or the v2 API
// POST /projects/{id}/customers/{uid}/actions/revoke_granted_entitlement.

import { makeRevenueCatClient } from '../supabase/functions/_shared/revenuecat/client.ts';
import { formatOutcome, GRACE_DAYS, listAuthUsers, runGrace } from '../supabase/functions/_shared/grace/grace.ts';

const PROJECTS = { dev: 'vlmtsdzpnjnavdgytcmi', prod: 'wvmvsodrvbkxfydabqed' };
const DEFAULT_REVENUECAT_PROJECT_ID = 'proj77b3c48f'; // one RevenueCat project serves dev and prod

function fail(message) {
  console.error(`grace-grant: ${message}`);
  Deno.exit(2);
}

function parseArgs(argv) {
  const args = { write: false, all: false, users: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const value = () => {
      const v = argv[++i];
      if (v === undefined || v.startsWith('--')) fail(`${a} needs a value`);
      return v;
    };
    if (a === '--project') args.project = value();
    else if (a === '--flip') args.flip = value();
    else if (a === '--user') args.users.push(value());
    else if (a === '--write') args.write = true;
    else if (a === '--all') args.all = true;
    else fail(`unknown argument ${a}`);
  }
  return args;
}

/** The project ref inside a Supabase service role JWT, or null. */
function jwtRef(token) {
  try {
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload.role === 'service_role' ? payload.ref ?? null : null;
  } catch {
    return null;
  }
}

async function main() {
  const args = parseArgs(Deno.args);
  const ref = PROJECTS[args.project];
  if (!ref) fail('--project dev|prod is required');
  if (!args.flip || !/(Z|[+-]\d\d:\d\d)$/.test(args.flip)) fail('--flip <ISO with zone> is required, e.g. 2026-10-01T00:00:00-05:00');
  const flipAt = new Date(args.flip);
  if (Number.isNaN(flipAt.getTime())) fail(`--flip ${args.flip} is not a date`);
  if (args.write && args.users.length === 0 && !args.all) fail('--write without --user needs --all');
  if (args.all && args.users.length > 0) fail('--all and --user are exclusive');

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (jwtRef(serviceRoleKey) !== ref) fail(`SUPABASE_SERVICE_ROLE_KEY is not the ${args.project} project's service role key`);
  const secretKey = Deno.env.get('REVENUECAT_SECRET_KEY') ?? '';
  if (!secretKey) fail('REVENUECAT_SECRET_KEY is not set');
  const projectId = Deno.env.get('REVENUECAT_PROJECT_ID') || DEFAULT_REVENUECAT_PROJECT_ID;

  console.log(`grace-grant  project=${args.project} (${ref})  flip=${flipAt.toISOString()}  days=${GRACE_DAYS}`);
  console.log(args.write ? 'WRITE RUN: grants are made' : 'DRY RUN: nothing is written');
  if (args.users.length) console.log(`only: ${args.users.join(', ')}`);

  const users = await listAuthUsers({ url: `https://${ref}.supabase.co`, serviceRoleKey });
  const rc = makeRevenueCatClient({ secretKey, projectId });
  const summary = await runGrace({
    users,
    rc,
    flipAt,
    write: args.write,
    onlyIds: args.users.length ? args.users : undefined,
    log: (_line, user, outcome) => console.log(formatOutcome(user, outcome)),
  });

  console.log('');
  console.log(`accounts listed: ${users.length}; selected (registered, created before the flip): ${summary.selected}`);
  const c = summary.counts;
  if (summary.write) console.log(`granted ${c.granted}, marked founding only ${c.marked}, already held ${c.already}, failed ${c.failed}`);
  else console.log(`would grant ${c.would_grant}, would mark founding only ${c.would_mark}, already held ${c.already}, failed to read ${c.failed}`);
  if (summary.notSelected.length) console.log(`named but not selected: ${summary.notSelected.join(', ')}`);
  if (c.failed > 0) Deno.exit(1);
}

await main();
