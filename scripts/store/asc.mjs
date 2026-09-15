#!/usr/bin/env node
/**
 * App Store Connect: list the DEV app's subscriptions and add the seven-day
 * free introductory offer (mp-279: the existing monthly and annual products
 * get a free-trial intro offer; no new product ids).
 *
 * Usage (no dependencies, Node 18+):
 *   node scripts/store/asc.mjs list                 # read-only: groups, subscriptions, intro offers
 *   node scripts/store/asc.mjs add-trial            # creates ONE_WEEK FREE_TRIAL on every subscription lacking one
 *   node scripts/store/asc.mjs add-trial --dry-run  # shows what it would create
 *
 * Env (defaults are the dev app):
 *   ASC_APP_ID      App Store Connect app id — refuses the prod app (6751113738).
 *   ASC_KEY_ID      API key id (default 565CMLNU3G)
 *   ASC_ISSUER_ID   issuer id
 *   ASC_KEY_FILE    path to the .p8 (default secrets/apple/AuthKey_Codemagic_<key>.p8 in the main clone)
 *
 * The prod app is refused by id, not by flag: there is no way to point this at
 * 6751113738. Prod intro offers are a release-day act (docs/implement_mealplanning/04-entitlement.md).
 */
import { createSign, createPrivateKey } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const PROD_APP_ID = '6751113738';
const DEV_APP_ID = '6756683509';

const appId = process.env.ASC_APP_ID ?? DEV_APP_ID;
if (appId === PROD_APP_ID) {
  console.error(`refusing to touch the PROD app (${PROD_APP_ID}); intro offers on prod are a release-day act`);
  process.exit(2);
}
const keyId = process.env.ASC_KEY_ID ?? '565CMLNU3G';
const issuer = process.env.ASC_ISSUER_ID ?? '4ddd5f89-a054-4c06-b65a-ac9ed980786d';
const keyFile = process.env.ASC_KEY_FILE ?? firstExisting([
  resolve('secrets/apple', `AuthKey_Codemagic_${keyId}.p8`),
  resolve(process.env.HOME ?? '', 'development/mealvana_endurance/secrets/apple', `AuthKey_Codemagic_${keyId}.p8`),
]);

function firstExisting(paths) {
  for (const p of paths) if (existsSync(p)) return p;
  console.error(`no .p8 found; tried:\n  ${paths.join('\n  ')}`);
  process.exit(2);
}

function b64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function jwt() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = b64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }));
  const signer = createSign('SHA256');
  signer.update(`${header}.${payload}`);
  const key = createPrivateKey(readFileSync(keyFile));
  const sig = signer.sign({ key, dsaEncoding: 'ieee-p1363' });
  return `${header}.${payload}.${b64url(sig)}`;
}

const BASE = 'https://api.appstoreconnect.apple.com';

async function api(method, path, body) {
  const res = await fetch(path.startsWith('http') ? path : `${BASE}${path}`, {
    method,
    headers: { Authorization: `Bearer ${jwt()}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON body */ }
  if (!res.ok) {
    throw new Error(`${method} ${path} → ${res.status}\n${text}`);
  }
  return json;
}

async function listAll(path) {
  const items = [];
  let next = path;
  while (next) {
    const page = await api('GET', next);
    items.push(...(page.data ?? []));
    next = page.links?.next ?? null;
  }
  return items;
}

async function catalogue() {
  const app = await api('GET', `/v1/apps/${appId}?fields[apps]=name,bundleId`);
  const groups = await listAll(`/v1/apps/${appId}/subscriptionGroups?fields[subscriptionGroups]=referenceName`);
  const out = { app: { id: app.data.id, ...app.data.attributes }, groups: [] };
  for (const g of groups) {
    const subs = await listAll(
      `/v1/subscriptionGroups/${g.id}/subscriptions?fields[subscriptions]=name,productId,state,subscriptionPeriod,groupLevel`,
    );
    const group = { id: g.id, ...g.attributes, subscriptions: [] };
    for (const s of subs) {
      const offers = await listAll(
        `/v1/subscriptions/${s.id}/introductoryOffers?fields[subscriptionIntroductoryOffers]=duration,offerMode,numberOfPeriods,startDate,endDate,territory&include=territory`,
      );
      group.subscriptions.push({
        id: s.id,
        ...s.attributes,
        introductoryOffers: offers.map((o) => ({
          id: o.id,
          ...o.attributes,
          territory: o.relationships?.territory?.data?.id ?? '(all)',
        })),
      });
    }
    out.groups.push(group);
  }
  return out;
}

function print(cat) {
  console.log(`App ${cat.app.id} · ${cat.app.name} · ${cat.app.bundleId}`);
  for (const g of cat.groups) {
    console.log(`  group ${g.id} · ${g.referenceName}`);
    for (const s of g.subscriptions) {
      console.log(`    ${s.productId} (${s.id}) · ${s.subscriptionPeriod} · ${s.state}`);
      if (s.introductoryOffers.length === 0) console.log('      intro offers: none');
      const byKind = new Map();
      for (const o of s.introductoryOffers) {
        const k = `${o.offerMode} ${o.duration} ×${o.numberOfPeriods}`;
        byKind.set(k, (byKind.get(k) ?? 0) + 1);
      }
      for (const [k, n] of byKind) console.log(`      intro offer ${k} in ${n} territories`);
    }
  }
}

async function territoriesFor(subscriptionId) {
  const availability = await api('GET', `/v1/subscriptions/${subscriptionId}/subscriptionAvailability`);
  const items = await listAll(
    `/v1/subscriptionAvailabilities/${availability.data.id}/availableTerritories?fields[territories]=currency&limit=200`,
  );
  return items.map((t) => t.id);
}

async function addTrial(dryRun) {
  const cat = await catalogue();
  print(cat);
  for (const s of cat.groups.flatMap((g) => g.subscriptions)) {
    // Apple wants one introductory offer per territory (the "territory"
    // relationship is required), so the offer is created for every territory
    // the subscription is available in, skipping those that already have one.
    const territories = await territoriesFor(s.id);
    const covered = new Set(s.introductoryOffers.filter((o) => o.offerMode === 'FREE_TRIAL').map((o) => o.territory));
    const missing = territories.filter((t) => !covered.has(t));
    console.log(`${s.productId}: ${territories.length} territories, ${covered.size} with a free trial, ${missing.length} to create`);
    if (missing.length === 0) continue;
    if (dryRun) {
      console.log(`  [dry-run] would create ONE_WEEK FREE_TRIAL in ${missing.join(' ')}`);
      continue;
    }
    let n = 0;
    for (const territory of missing) {
      await api('POST', '/v1/subscriptionIntroductoryOffers', {
        data: {
          type: 'subscriptionIntroductoryOffers',
          attributes: { duration: 'ONE_WEEK', offerMode: 'FREE_TRIAL', numberOfPeriods: 1 },
          relationships: {
            subscription: { data: { type: 'subscriptions', id: s.id } },
            territory: { data: { type: 'territories', id: territory } },
          },
        },
      });
      n++;
      if (n % 25 === 0) console.log(`  ${n}/${missing.length}`);
    }
    console.log(`  created ${n} offers on ${s.productId}`);
  }
  console.log('\nAfter:');
  printSummary(await catalogue());
}

/** One line per subscription: how many territories carry the free trial. */
function printSummary(cat) {
  for (const s of cat.groups.flatMap((g) => g.subscriptions)) {
    const trials = s.introductoryOffers.filter((o) => o.offerMode === 'FREE_TRIAL' && o.duration === 'ONE_WEEK');
    console.log(`  ${s.productId}: ONE_WEEK FREE_TRIAL in ${trials.length} territories`);
  }
}

const [cmd = 'list', ...flags] = process.argv.slice(2);
try {
  if (cmd === 'list') print(await catalogue());
  else if (cmd === 'add-trial') await addTrial(flags.includes('--dry-run'));
  else { console.error('usage: asc.mjs list | add-trial [--dry-run]'); process.exit(2); }
} catch (e) {
  console.error(e.message ?? e);
  process.exit(1);
}
