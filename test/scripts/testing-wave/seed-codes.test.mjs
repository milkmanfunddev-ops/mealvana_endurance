// node --test test/scripts/testing-wave/*.test.mjs   (Node 22 takes files or globs, not a folder)
//
// The code fixtures: which rows a seed writes, that an owned code belongs to the account it
// names, and that the CLI never runs against prod.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROD_REF } from '../../../scripts/testing-wave/sweep-accounts.mjs';
import { FIXTURES, seedSql, ownSql, ownCode } from '../../../scripts/testing-wave/seed-codes.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), '../../../scripts/testing-wave/seed-codes.mjs');

test('every fixture is a valid E2E code of each kind a redeem scenario needs', () => {
  for (const f of FIXTURES) {
    assert.match(f.code, /^E2E[A-Z0-9]{0,29}$/, `${f.code}: upper case, no spaces, at most 32 characters`);
    assert.ok(['giveaway', 'influencer'].includes(f.type), `${f.code}: a coach code needs an owner, so it comes from \`own\``);
  }
  const has = pred => FIXTURES.some(pred);
  assert.ok(has(f => f.type === 'giveaway' && f.max === null), 'a once-in-total giveaway');
  assert.ok(has(f => f.type === 'influencer'), 'an influencer code');
  assert.ok(has(f => f.until), 'an expired code');
  assert.ok(has(f => f.from && f.from.includes('+')), 'a not-yet-valid code');
  assert.ok(has(f => f.usedUp && f.max === 1), 'a used-up code');
});

test('a seed upserts every fixture, clears their redemptions, then spends the used-up one, in one transaction', () => {
  const sql = seedSql(FIXTURES, { usedBy: 'test@test.com' });
  assert.match(sql, /^begin;/); assert.match(sql, /commit;$/);
  for (const f of FIXTURES) assert.ok(sql.includes(`'${f.code}'`), f.code);
  assert.match(sql, /on conflict \(code\) do update/);
  const clear = sql.indexOf('delete from public.code_redemptions');
  const spend = sql.indexOf('insert into public.code_redemptions');
  assert.ok(clear > 0 && spend > clear, 'redemptions are cleared before E2EUSEDUP is spent again');
  assert.match(sql.slice(spend), /c\.code in \('E2EUSEDUP'\) and u\.email = 'test@test\.com'/);
  assert.ok(!sql.includes("E2EGIVE365') and u.email"), 'only the used-up fixture is pre-spent');
});

test('an owned coach code is named from the account id and refuses a non-uuid', () => {
  const id = '9a986318-7cbf-4489-8115-b60850a2bac7';
  assert.equal(ownCode(id), 'E2ECOACH9A986318');
  const sql = ownSql(id, { days: 30 });
  assert.match(sql, /'E2ECOACH9A986318', 'coach', '9a986318-7cbf-4489-8115-b60850a2bac7', 30/);
  assert.throws(() => ownSql("x'; drop table codes; --"), /not a uuid/);
  assert.throws(() => ownSql(id, { days: 'ten' }), /whole number/);
});

test('the CLI refuses prod before it reads a token or touches the network', () => {
  const r = spawnSync('node', [cli, 'list', '--ref', PROD_REF], { encoding: 'utf8', env: { ...process.env, SUPABASE_ACCESS_TOKEN: 'unused' } });
  assert.equal(r.status, 2);
  assert.match(r.stderr, /PROD/);
});
