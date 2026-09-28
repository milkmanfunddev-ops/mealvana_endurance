// Read-only access to the dev project's database through the Supabase Management API
// (POST /v1/projects/<ref>/database/query). The token comes from $SUPABASE_ACCESS_TOKEN or
// $SUPABASE_PAT, else from the main clone's secrets file (the worktrees have no secrets/).
// Never printed. PROD is refused outright.

import { readFileSync } from 'node:fs';

export const DEV_REF = 'vlmtsdzpnjnavdgytcmi';
const PROD_REF = 'wvmvsodrvbkxfydabqed';
const SECRETS_FILE = '/Users/leemartin/development/mealvana_endurance/secrets/supabase_management_api.env';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function assertDev(ref) {
  if (ref === PROD_REF) throw new Error('refusing to run against PROD: judging reads dev only');
  if (ref !== DEV_REF) throw new Error(`refusing project "${ref}": judging reads dev (${DEV_REF}) only`);
}

export function assertUuid(value, what) {
  if (!UUID.test(String(value ?? ''))) throw new Error(`${what} "${value}" is not a uuid`);
}

/** Quote a value for interpolation into raw SQL (the Management API takes no bind parameters).
 *  Callers validate shape first (assertUuid / email regex); this is the second lock. */
export const sqlString = (s) => `'${String(s).replaceAll("'", "''")}'`;

export function managementToken() {
  const env = process.env.SUPABASE_ACCESS_TOKEN || process.env.SUPABASE_PAT;
  if (env) return env;
  const line = readFileSync(SECRETS_FILE, 'utf8').split('\n').find((l) => l.startsWith('SUPABASE_MANAGEMENT_TOKEN='));
  if (!line) throw new Error(`no SUPABASE_MANAGEMENT_TOKEN in ${SECRETS_FILE} and no SUPABASE_ACCESS_TOKEN in the environment`);
  return line.slice('SUPABASE_MANAGEMENT_TOKEN='.length).trim();
}

/** Run one read-only query against dev. Returns the rows. */
export async function query(sql, { ref = DEV_REF, token = managementToken() } = {}) {
  assertDev(ref);
  if (!/^(\s|--[^\n]*\n)*select\b/i.test(sql)) throw new Error('devdb is read-only: only select statements');
  const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`query failed (${res.status}): ${body.slice(0, 300)}`);
  return JSON.parse(body);
}
