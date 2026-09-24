#!/usr/bin/env node
// Testing-wave code fixtures on DEV: one `codes` row per kind a redeem scenario needs, so a run
// never has to write the table by hand (Findings 11-001, 11-008). Every fixture code starts `E2E`
// so it is never mistaken for a real one. Dev only; prod refuses.
//
// CLI (token as sweep-accounts.mjs reads it; never printed):
//   node seed-codes.mjs list                     -> the E2E codes with their redemption counts
//   node seed-codes.mjs seed                     -> upsert the fixtures, clear their redemptions,
//                                                   windows recomputed from now; safe to re-run
//   node seed-codes.mjs own <user id> [--days N] -> a coach code owned by that account (a
//                                                   lee+e2e-* account only), printed; it goes when
//                                                   the account is deleted (cascade)
// Every command takes --ref <project ref>, which must be dev, and seed takes --used-by <email>
// (default test@test.com): the account whose redemption spends E2EUSEDUP.
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEV_REF, assertDev, isSweepable, devAdmin } from './sweep-accounts.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const lit = s => (s === null || s === undefined ? 'null' : `'${String(s).replaceAll("'", "''")}'`);

/** The fixtures. `from`/`until` are SQL expressions so a re-seed moves the windows with the clock. */
export const FIXTURES = [
  { code: 'E2EGIVE365', type: 'giveaway', perkDays: 365, max: null, note: 'giveaway, once in total: the first account spends it (mp-535)' },
  { code: 'E2EGIVEMANY', type: 'giveaway', perkDays: 365, max: 1000, note: 'giveaway any account can redeem once' },
  { code: 'E2EINFLUENCER', type: 'influencer', perkDays: 0, max: null, note: 'influencer, no owner: records the referral, never pairs' },
  { code: 'E2EEXPIRED', type: 'giveaway', perkDays: 365, max: 1000, from: "now() - interval '30 days'", until: "now() - interval '1 day'", note: 'window closed yesterday' },
  { code: 'E2EFUTURE', type: 'giveaway', perkDays: 365, max: 1000, from: "now() + interval '30 days'", note: 'window opens in 30 days' },
  { code: 'E2EUSEDUP', type: 'giveaway', perkDays: 365, max: 1, usedUp: true, note: 'limit 1, already spent by the seed account' },
];

/** One statement that upserts every fixture, clears their redemptions and spends E2EUSEDUP. */
export function seedSql(fixtures = FIXTURES, { usedBy = 'test@test.com' } = {}) {
  const rows = fixtures.map(f =>
    `(${lit(f.code)}, ${lit(f.type)}, null, ${f.from ?? 'now()'}, ${f.until ?? 'null'}, ${Number(f.perkDays)}, ${f.max ?? 'null'}, ${lit(`testing-wave fixture: ${f.note}`)})`);
  const codes = fixtures.map(f => lit(f.code)).join(', ');
  const spent = fixtures.filter(f => f.usedUp).map(f => lit(f.code));
  return [
    'begin;',
    `insert into public.codes (code, type, owner_user_id, valid_from, valid_until, perk_days, max_redemptions, note) values\n  ${rows.join(',\n  ')}\n` +
      'on conflict (code) do update set type = excluded.type, owner_user_id = excluded.owner_user_id, valid_from = excluded.valid_from, ' +
      'valid_until = excluded.valid_until, perk_days = excluded.perk_days, max_redemptions = excluded.max_redemptions, note = excluded.note, updated_at = now();',
    `delete from public.code_redemptions where code_id in (select id from public.codes where code in (${codes}));`,
    ...(spent.length
      ? [`insert into public.code_redemptions (code_id, user_id) select c.id, u.id from public.codes c, auth.users u where c.code in (${spent.join(', ')}) and u.email = ${lit(usedBy)};`]
      : []),
    'commit;',
  ].join('\n');
}

/** The coach code a throwaway account owns: E2ECOACH plus the first 8 hex of its id. */
export const ownCode = userId => `E2ECOACH${String(userId).replaceAll('-', '').slice(0, 8).toUpperCase()}`;

export function ownSql(userId, { days = 30 } = {}) {
  if (!UUID.test(String(userId))) throw new Error(`"${userId}" is not a uuid`);
  if (!Number.isInteger(Number(days)) || Number(days) < 0) throw new Error(`--days must be a whole number, not "${days}"`);
  return `insert into public.codes (code, type, owner_user_id, perk_days, note) values (${lit(ownCode(userId))}, 'coach', '${userId}', ${Number(days)}, 'testing-wave fixture: coach code owned by a throwaway account') ` +
    `on conflict (code) do update set owner_user_id = excluded.owner_user_id, perk_days = excluded.perk_days, updated_at = now() returning code;`;
}

export const LIST_SQL = `select c.code, c.type, c.owner_user_id::text as owner, c.valid_from, c.valid_until, c.perk_days, c.max_redemptions,
  (select count(*)::int from public.code_redemptions r where r.code_id = c.id) as redemptions
from public.codes c where c.code like 'E2E%' order by c.code`;

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const flag = name => { const i = args.indexOf(name); return i === -1 ? undefined : args.splice(i, 2)[1]; };
  const ref = flag('--ref') ?? DEV_REF;
  const days = flag('--days') ?? 30;
  const usedBy = flag('--used-by') ?? 'test@test.com';
  const [cmd, arg] = args;
  const out = s => process.stdout.write(`${s}\n`);
  try {
    assertDev(ref);
    const db = () => devAdmin(ref);
    if (cmd === 'list') {
      for (const r of await db().query(LIST_SQL)) out(JSON.stringify(r));
    } else if (cmd === 'seed') {
      await db().query(seedSql(FIXTURES, { usedBy }));
      for (const r of await db().query(LIST_SQL)) out(JSON.stringify(r));
    } else if (cmd === 'own' && arg) {
      const api = db();
      const sql = ownSql(arg, { days });
      const [user] = await api.query(`select email from auth.users where id = '${arg}'`);
      if (!user) throw new Error(`no account ${arg} on dev`);
      if (!isSweepable(user.email)) throw new Error(`${user.email} is not a lee+e2e-* account; own codes are for throwaway accounts only`);
      const [row] = await api.query(sql);
      out(row.code);
    } else {
      process.stderr.write('usage: seed-codes.mjs list | seed [--used-by <email>] | own <user id> [--days N]   [--ref <dev ref>]\n');
      process.exit(64);
    }
  } catch (e) {
    process.stderr.write(`${e.message}\n`);
    process.exit(2);
  }
}
