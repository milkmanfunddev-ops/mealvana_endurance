#!/usr/bin/env node
// Testing-wave account sweep: finds the `lee+e2e-*@rightpathprogramming.com` accounts that runs
// left on DEV and deletes them the way the app's delete-user function does (the public.users row,
// whose foreign keys cascade, then the auth user). Dev only; prod refuses. Dry run by default.
//
// CLI (token from $SUPABASE_ACCESS_TOKEN or $SUPABASE_PAT, else read from the main clone's
// secrets/supabase_management_api.env; never printed):
//   node sweep-accounts.mjs list                 -> the sweepable accounts (dry run)
//   node sweep-accounts.mjs delete               -> same as list: says what --apply would delete
//   node sweep-accounts.mjs delete --apply       -> deletes them; exit 1 if any delete failed
//   node sweep-accounts.mjs delete --id <id,id> --apply -> only those accounts (a run cleaning up after
//                                                   itself; a bare sweep also takes other runs' live accounts)
//   node sweep-accounts.mjs footprint <user id>  -> rows still keyed to that id, per table
// Every command takes --ref <project ref>, which must be dev.

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const DEV_REF = 'vlmtsdzpnjnavdgytcmi';
export const PROD_REF = 'wvmvsodrvbkxfydabqed';

// The only addresses a sweep may touch: a plus tag that starts `e2e-` and carries a run tag, on
// Lee's work domain. The plain address (the Gmail fallback) is never swept.
const SWEEPABLE = /^lee\+e2e-[a-z0-9][a-z0-9._-]*@rightpathprogramming\.com$/i;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isSweepable = email => typeof email === 'string' && SWEEPABLE.test(email);

/** Keep only accounts the sweep may delete, whatever the listing returned. */
export const selectSweepable = users =>
  users.filter(u => isSweepable(u?.email) && typeof u?.id === 'string' && UUID.test(u.id));

export function assertDev(ref) {
  if (ref === PROD_REF) throw new Error('refusing to run against PROD: the sweep is dev only');
  if (ref !== DEV_REF) throw new Error(`refusing project "${ref}": the sweep runs against dev (${DEV_REF}) only`);
}

/**
 * List the sweepable accounts and, with apply, delete them one by one. A failed delete is
 * reported and the rest still run. `api` is { listCandidates(), deleteAccount(id) }.
 */
export async function sweep({ ref, api, apply = false, ids }) {
  assertDev(ref);
  // `ids` narrows the sweep to named accounts (still only sweepable ones), so a run cleaning up
  // after itself never deletes another live run's account.
  const targets = selectSweepable(await api.listCandidates()).filter(t => !ids || ids.includes(t.id));
  if (!apply) return { mode: 'dry-run', targets, deleted: [], failed: [] };
  const deleted = [];
  const failed = [];
  for (const t of targets) {
    try {
      await api.deleteAccount(t.id);
      deleted.push(t.id);
    } catch (e) {
      failed.push({ id: t.id, email: t.email, error: e?.message ?? String(e) });
    }
  }
  return { mode: 'delete', targets, deleted, failed };
}

const ident = s => `"${String(s).replaceAll('"', '""')}"`;

/**
 * One query that counts, for a user id, the auth user and every public row keyed to it through
 * the given (table, column) pairs. Only rows with a count above zero come back.
 */
export function footprintSql(userId, columns) {
  if (!UUID.test(String(userId))) throw new Error(`"${userId}" is not a uuid`);
  const parts = [
    `select 'auth.users' as tbl, 'id' as col, count(*)::int as n from auth.users where id = '${userId}'`,
    `select 'auth.identities', 'user_id', count(*)::int from auth.identities where user_id = '${userId}'`,
    ...columns.map(c =>
      `select 'public.${c.table_name}', '${c.column_name}', count(*)::int from public.${ident(c.table_name)} where ${ident(c.column_name)} = '${userId}'`),
  ];
  return `select * from (${parts.join('\nunion all ')}) f where n > 0 order by tbl`;
}

// Every uuid column in a public base table that can hold a user's id: users.id and the columns
// named for a user (user_id, *_user_id, owner/account/reviewer/added_by/used_by_*).
const USER_COLUMNS_SQL = `
select c.table_name, c.column_name
from information_schema.columns c
join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name
where c.table_schema = 'public' and t.table_type = 'BASE TABLE' and c.data_type = 'uuid'
  and ((c.table_name = 'users' and c.column_name = 'id')
    or c.column_name ~ '(^|_)user_id$' or c.column_name ~ '^(owner|account|reviewer|added_by|used_by)'
    or c.column_name = 'device_id')
order by 1, 2`;

function managementToken() {
  const env = process.env.SUPABASE_ACCESS_TOKEN || process.env.SUPABASE_PAT;
  if (env) return env;
  const file = '/Users/leemartin/development/mealvana_endurance/secrets/supabase_management_api.env';
  const line = readFileSync(file, 'utf8').split('\n').find(l => l.startsWith('SUPABASE_MANAGEMENT_TOKEN='));
  if (!line) throw new Error(`no SUPABASE_MANAGEMENT_TOKEN in ${file}`);
  return line.slice('SUPABASE_MANAGEMENT_TOKEN='.length).trim();
}

/** The dev project's Management API and Auth admin API, for the CLI and the code probe. */
export function devAdmin(ref = DEV_REF, { token = managementToken() } = {}) {
  assertDev(ref);
  const mgmt = `https://api.supabase.com/v1/projects/${ref}`;
  const auth = `https://${ref}.supabase.co/auth/v1`;
  let serviceKey;

  async function query(sql) {
    const res = await fetch(`${mgmt}/database/query`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: sql }),
    });
    const body = await res.text();
    if (!res.ok) throw new Error(`query failed (${res.status}): ${body.slice(0, 300)}`);
    return JSON.parse(body);
  }

  async function adminHeaders() {
    if (!serviceKey) {
      const res = await fetch(`${mgmt}/api-keys?reveal=true`, { headers: { Authorization: `Bearer ${token}` } });
      if (!res.ok) throw new Error(`api-keys failed (${res.status})`);
      serviceKey = (await res.json()).find(k => k.name === 'service_role')?.api_key;
      if (!serviceKey) throw new Error('no service_role key on the dev project');
    }
    return { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' };
  }

  async function authAdmin(path, init = {}) {
    const res = await fetch(`${auth}/admin${path}`, { ...init, headers: await adminHeaders() });
    const text = await res.text();
    if (!res.ok) throw new Error(`auth admin ${init.method ?? 'GET'} ${path.split('?')[0]} failed (${res.status}): ${text.slice(0, 300)}`);
    return text ? JSON.parse(text) : null;
  }

  return {
    query,
    authAdmin,
    listCandidates: () =>
      query(`select id::text, email, created_at from auth.users where email ilike 'lee+e2e-%@rightpathprogramming.com' order by created_at`),
    async deleteAccount(id) {
      if (!UUID.test(id)) throw new Error(`"${id}" is not a uuid`);
      // Same order as supabase/functions/delete-user: public.users (cascades), then the auth user.
      await query(`delete from public.users where id = '${id}'`);
      await authAdmin(`/users/${id}`, { method: 'DELETE' });
    },
    async footprint(id) {
      return query(footprintSql(id, await query(USER_COLUMNS_SQL)));
    },
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const flag = name => { const i = args.indexOf(name); return i === -1 ? undefined : args.splice(i, 2)[1]; };
  const ref = flag('--ref') ?? DEV_REF;
  const idArg = flag('--id');
  const ids = idArg ? idArg.split(',').map(x => x.trim()).filter(Boolean) : undefined;
  const apply = args.includes('--apply');
  const [cmd, arg] = args.filter(a => a !== '--apply');
  const out = s => process.stdout.write(`${s}\n`);
  try {
    if (cmd === 'list' || cmd === 'delete') {
      assertDev(ref);
      const r = await sweep({ ref, api: devAdmin(ref), apply: cmd === 'delete' && apply, ids });
      out(`${r.mode} on dev ${ref}: ${r.targets.length} lee+e2e-* account(s)`);
      for (const t of r.targets) out(`  ${t.id}  ${t.email}  created ${t.created_at}`);
      if (r.mode === 'dry-run' && cmd === 'delete' && r.targets.length) out('dry run: nothing deleted. Add --apply to delete these.');
      for (const id of r.deleted) out(`deleted ${id}`);
      for (const f of r.failed) out(`FAILED ${f.id} ${f.email}: ${f.error}`);
      process.exit(r.failed.length ? 1 : 0);
    } else if (cmd === 'footprint' && arg) {
      const rows = await devAdmin(ref).footprint(arg);
      out(rows.length ? rows.map(r => `${r.tbl}.${r.col}: ${r.n}`).join('\n') : `no rows keyed to ${arg}`);
    } else {
      process.stderr.write('usage: sweep-accounts.mjs list | delete [--id <id,id>] [--apply] | footprint <user id>   [--ref <dev ref>]\n');
      process.exit(64);
    }
  } catch (e) {
    process.stderr.write(`${e.message}\n`);
    process.exit(2);
  }
}
