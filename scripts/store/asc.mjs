#!/usr/bin/env node
/**
 * App Store Connect: list the Mealvana Pro subscriptions, create the four
 * me_pro_* products (mp-452) and add the seven-day free introductory offer.
 *
 * Usage (no dependencies, Node 18+):
 *   node scripts/store/asc.mjs list [--prod]                 # read-only: groups, subscriptions, intro offers
 *   node scripts/store/asc.mjs add-trial [--prod] [--dry-run]
 *       creates ONE_WEEK FREE_TRIAL on every subscription lacking one (with --prod:
 *       only the four PRODUCTS below, never the retired mealvana_pro_*_prod)
 *   node scripts/store/asc.mjs create-products [--prod] [--dry-run]
 *       creates the PRODUCTS table below in the Mealvana Pro group: subscription,
 *       en-US localization, availability in every territory, the USA price plus
 *       Apple's equalized price in every other territory, then add-trial.
 *       Idempotent: skips whatever already exists, so it can be re-run.
 *
 * Targets: the DEV app by default. `--prod` is the only way to reach the PROD app
 * (6751113738, group 22351111): it sells the same product ids ending `_prod`
 * (mp-452; Apple product ids are team-unique). Nothing here submits for review.
 *
 * Env (defaults are the dev app):
 *   ASC_APP_ID      App Store Connect app id — without --prod the prod app (6751113738) is refused.
 *   ASC_KEY_ID      API key id (default 565CMLNU3G)
 *   ASC_ISSUER_ID   issuer id
 *   ASC_KEY_FILE    path to the .p8 (default secrets/apple/AuthKey_Codemagic_<key>.p8 in the main clone)
 */
import { createSign, createPrivateKey } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const PROD_APP_ID = '6751113738';
const DEV_APP_ID = '6756683509';

const argv = process.argv.slice(2);
const PROD = argv.includes('--prod');

/** "Mealvana Pro" group on each app; prod ids carry the `_prod` suffix (mp-452). */
const TARGET = PROD
  ? { appId: PROD_APP_ID, groupId: '22351111', suffix: '_prod' }
  : { appId: process.env.ASC_APP_ID ?? DEV_APP_ID, groupId: '22351029', suffix: '' };
if (PROD && process.env.ASC_APP_ID && process.env.ASC_APP_ID !== PROD_APP_ID) {
  console.error(`--prod targets ${PROD_APP_ID}; ASC_APP_ID=${process.env.ASC_APP_ID} contradicts it`);
  process.exit(2);
}
if (!PROD && TARGET.appId === PROD_APP_ID) {
  console.error(`refusing to touch the PROD app (${PROD_APP_ID}) without --prod`);
  process.exit(2);
}
const appId = TARGET.appId;
const PRO_GROUP_ID = TARGET.groupId;

/** Subscriptions create-products makes (paywall reprice, 2026-09-21). */
const PRODUCTS = [
  { productId: 'me_pro_monthly', name: 'Mealvana Pro Monthly 2026', period: 'ONE_MONTH', usaPrice: '24.99',
    displayName: 'Mealvana Pro Monthly', description: 'AI meal plans, shopping lists and cooking mode.' },
  { productId: 'me_pro_annual', name: 'Mealvana Pro Annual 2026', period: 'ONE_YEAR', usaPrice: '199.99',
    displayName: 'Mealvana Pro Annual', description: 'AI meal plans, shopping lists and cooking mode.' },
  { productId: 'me_pro_monthly_founding', name: 'Mealvana Pro Monthly Founding', period: 'ONE_MONTH', usaPrice: '12.49',
    displayName: 'Founding Monthly', description: 'Founding-member price for Mealvana Pro, monthly.' },
  { productId: 'me_pro_annual_founding', name: 'Mealvana Pro Annual Founding', period: 'ONE_YEAR', usaPrice: '99.99',
    displayName: 'Founding Annual', description: 'Founding-member price for Mealvana Pro, yearly.' },
].map((p) => ({ ...p, productId: p.productId + TARGET.suffix }));

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
      const prices = await pricesFor(s.id);
      group.subscriptions.push({
        id: s.id,
        ...s.attributes,
        prices,
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
      const usa = s.prices.find((p) => p.territory === 'USA');
      console.log(`      price USA ${usa ? usa.customerPrice : '(none)'} · priced in ${s.prices.length} territories`);
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

/** Current prices of a subscription: [{ territory, customerPrice, pricePointId }]. */
async function pricesFor(subscriptionId) {
  const out = [];
  let next = `/v1/subscriptions/${subscriptionId}/prices?include=subscriptionPricePoint,territory&fields[subscriptionPricePoints]=customerPrice&limit=200`;
  while (next) {
    const page = await api('GET', next);
    const points = new Map((page.included ?? []).map((i) => [i.id, i.attributes.customerPrice]));
    for (const p of page.data ?? []) {
      const pointId = p.relationships.subscriptionPricePoint.data.id;
      out.push({ territory: p.relationships.territory.data.id, customerPrice: points.get(pointId), pricePointId: pointId });
    }
    next = page.links?.next ?? null;
  }
  return out;
}

/** The subscription's USA price point for `price`, or the nearest two if there is no exact one. */
async function usaPricePoint(subscriptionId, price) {
  const points = await listAll(
    `/v1/subscriptions/${subscriptionId}/pricePoints?filter[territory]=USA&fields[subscriptionPricePoints]=customerPrice&limit=200`,
  );
  const exact = points.find((p) => Number(p.attributes.customerPrice) === Number(price));
  if (exact) return { exact };
  const nearest = [...points]
    .sort((a, b) => Math.abs(a.attributes.customerPrice - price) - Math.abs(b.attributes.customerPrice - price))
    .slice(0, 2)
    .map((p) => p.attributes.customerPrice);
  return { nearest };
}

async function createProducts(dryRun) {
  const groups = await listAll(`/v1/apps/${appId}/subscriptionGroups?fields[subscriptionGroups]=referenceName`);
  if (!groups.some((g) => g.id === PRO_GROUP_ID)) throw new Error(`group ${PRO_GROUP_ID} not on app ${appId}`);
  const existing = await listAll(
    `/v1/subscriptionGroups/${PRO_GROUP_ID}/subscriptions?fields[subscriptions]=name,productId,state,subscriptionPeriod`,
  );
  const allTerritories = (await listAll('/v1/territories?limit=200')).map((t) => t.id);
  console.log(`group ${PRO_GROUP_ID}: ${existing.length} subscriptions; ${allTerritories.length} territories`);

  // Check every price before creating anything: price tiers are the same for
  // every subscription, so an existing one in the group answers for a new one.
  const probeId = existing[0]?.id;
  for (const p of PRODUCTS) {
    const sub = existing.find((s) => s.attributes.productId === p.productId);
    const r = await usaPricePoint(sub?.id ?? probeId, p.usaPrice);
    if (!r.exact) throw new Error(`no USA price point ${p.usaPrice} for ${p.productId}; nearest: ${r.nearest.join(', ')}`);
  }

  for (const p of PRODUCTS) {
    if (p.description.length > 55) throw new Error(`${p.productId}: description over 55 chars`);
    let sub = existing.find((s) => s.attributes.productId === p.productId);
    if (!sub) {
      console.log(`${p.productId}: create subscription "${p.name}" ${p.period}`);
      if (dryRun) { console.log(`  [dry-run] then localization, availability in ${allTerritories.length}, price ${p.usaPrice} + equalizations`); continue; }
      sub = (await api('POST', '/v1/subscriptions', {
        data: {
          type: 'subscriptions',
          attributes: { name: p.name, productId: p.productId, subscriptionPeriod: p.period, familySharable: false },
          relationships: { group: { data: { type: 'subscriptionGroups', id: PRO_GROUP_ID } } },
        },
      })).data;
      console.log(`  created ${sub.id}`);
    } else {
      console.log(`${p.productId}: exists (${sub.id})`);
    }

    const locs = await listAll(`/v1/subscriptions/${sub.id}/subscriptionLocalizations`);
    if (!locs.some((l) => l.attributes.locale === 'en-US')) {
      console.log(`  ${dryRun ? '[dry-run] would create' : 'create'} en-US localization "${p.displayName}"`);
      if (!dryRun) await api('POST', '/v1/subscriptionLocalizations', {
        data: {
          type: 'subscriptionLocalizations',
          attributes: { locale: 'en-US', name: p.displayName, description: p.description },
          relationships: { subscription: { data: { type: 'subscriptions', id: sub.id } } },
        },
      });
    }

    let available = [];
    try { available = await territoriesFor(sub.id); } catch (e) { if (!/→ 404/.test(e.message)) throw e; }
    if (available.length < allTerritories.length) {
      console.log(`  ${dryRun ? '[dry-run] would set' : 'set'} availability: ${available.length} → ${allTerritories.length} territories`);
      if (!dryRun) await api('POST', '/v1/subscriptionAvailabilities', {
        data: {
          type: 'subscriptionAvailabilities',
          attributes: { availableInNewTerritories: true },
          relationships: {
            subscription: { data: { type: 'subscriptions', id: sub.id } },
            availableTerritories: { data: allTerritories.map((id) => ({ type: 'territories', id })) },
          },
        },
      });
    }

    // USA price point, then Apple's equalized point in every other territory.
    // Only the two relationships: attributes.preserveCurrentPrice makes Apple 409.
    const { exact: usa } = await usaPricePoint(sub.id, p.usaPrice);
    const equalized = await listAll(
      `/v1/subscriptionPricePoints/${usa.id}/equalizations?include=territory&fields[subscriptionPricePoints]=customerPrice,territory&limit=200`,
    );
    const wanted = [{ territory: 'USA', id: usa.id }, ...equalized.map((e) => ({ territory: e.relationships.territory.data.id, id: e.id }))];
    const priced = new Set((await pricesFor(sub.id)).map((x) => x.territory));
    const missing = wanted.filter((w) => !priced.has(w.territory));
    console.log(`  prices: ${priced.size} set, ${missing.length} to create (USA ${usa.attributes.customerPrice})`);
    if (dryRun || missing.length === 0) continue;
    let n = 0;
    for (const w of missing) {
      await api('POST', '/v1/subscriptionPrices', {
        data: {
          type: 'subscriptionPrices',
          relationships: {
            subscription: { data: { type: 'subscriptions', id: sub.id } },
            subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: w.id } },
          },
        },
      });
      if (++n % 25 === 0) console.log(`    ${n}/${missing.length}`);
    }
    console.log(`  created ${n} prices`);
  }

  console.log('\nIntroductory offers:');
  await addTrial(dryRun);
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
  for (const s of trialTargets(cat)) {
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

/**
 * Subscriptions add-trial works on. On prod only the PRODUCTS table: the
 * retired mealvana_pro_*_prod are never sold again (mp-452) and get no offer.
 */
function trialTargets(cat) {
  const all = cat.groups.flatMap((g) => g.subscriptions);
  if (!PROD) return all;
  const ids = new Set(PRODUCTS.map((p) => p.productId));
  return all.filter((s) => ids.has(s.productId));
}

/** One line per subscription: how many territories carry the free trial. */
function printSummary(cat) {
  for (const s of trialTargets(cat)) {
    const trials = s.introductoryOffers.filter((o) => o.offerMode === 'FREE_TRIAL' && o.duration === 'ONE_WEEK');
    console.log(`  ${s.productId}: ONE_WEEK FREE_TRIAL in ${trials.length} territories`);
  }
}

const [cmd = 'list', ...flags] = argv.filter((a) => a !== '--prod');
try {
  console.log(`target: ${PROD ? 'PROD' : 'dev'} app ${appId}, group ${PRO_GROUP_ID}`);
  if (cmd === 'list') print(await catalogue());
  else if (cmd === 'add-trial') await addTrial(flags.includes('--dry-run'));
  else if (cmd === 'create-products') await createProducts(flags.includes('--dry-run'));
  else { console.error('usage: asc.mjs list [--prod] | add-trial [--prod] [--dry-run] | create-products [--prod] [--dry-run]'); process.exit(2); }
} catch (e) {
  console.error(e.message ?? e);
  process.exit(1);
}
