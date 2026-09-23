#!/usr/bin/env node
/**
 * Google Play: list the DEV package's subscriptions and add the seven-day free
 * introductory offer to each base plan (mp-279: same product ids, an offer on
 * the existing base plans).
 *
 * Usage (no dependencies, Node 18+):
 *   node scripts/store/play.mjs list                 # read-only: subscriptions, base plans, offers
 *   node scripts/store/play.mjs add-trial            # creates + activates offer `free-week` on every base plan lacking a free phase
 *   node scripts/store/play.mjs add-trial --dry-run
 *   node scripts/store/play.mjs show <productId>     # read-only: raw subscription JSON
 *   node scripts/store/play.mjs create-products [--dry-run]
 *        creates the PRODUCTS table below (subscription + base plan + free-week offer),
 *        activates each, skips whatever already exists
 *
 * Env:
 *   PLAY_PACKAGE     defaults to com.milkman.mealvanaendurance.dev — the prod package is refused.
 *   PLAY_SA_FILE     service-account JSON (default secrets/google/mealvanaendurance-61d62e739439.json in the main clone)
 */
import { createSign, createPrivateKey } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const PROD_PACKAGE = 'com.milkman.mealvanaendurance';
const DEV_PACKAGE = 'com.milkman.mealvanaendurance.dev';
const OFFER_ID = 'free-week';
const REGIONS_VERSION = '2022/02';

const pkg = process.env.PLAY_PACKAGE ?? DEV_PACKAGE;
if (pkg === PROD_PACKAGE) {
  console.error(`refusing to touch the PROD package (${PROD_PACKAGE}); intro offers on prod are a release-day act`);
  process.exit(2);
}
const saFile = process.env.PLAY_SA_FILE ?? firstExisting([
  resolve('secrets/google/mealvanaendurance-61d62e739439.json'),
  resolve(process.env.HOME ?? '', 'development/mealvana_endurance/secrets/google/mealvanaendurance-61d62e739439.json'),
]);
function firstExisting(paths) {
  for (const p of paths) if (existsSync(p)) return p;
  console.error(`no service-account JSON found; tried:\n  ${paths.join('\n  ')}`);
  process.exit(2);
}
const sa = JSON.parse(readFileSync(saFile, 'utf8'));

function b64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

let cachedToken = null;
async function token() {
  if (cachedToken && cachedToken.exp > Date.now() / 1000 + 60) return cachedToken.value;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  }));
  const signer = createSign('RSA-SHA256');
  signer.update(`${header}.${payload}`);
  const assertion = `${header}.${payload}.${b64url(signer.sign(createPrivateKey(sa.private_key)))}`;
  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`token: ${res.status} ${JSON.stringify(json)}`);
  cachedToken = { value: json.access_token, exp: now + json.expires_in };
  return cachedToken.value;
}

const BASE = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}`;
async function api(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON */ }
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status}\n${text}`);
  return json;
}

async function catalogue() {
  const subs = (await api('GET', '/subscriptions'))?.subscriptions ?? [];
  const out = [];
  for (const s of subs) {
    const plans = [];
    for (const bp of s.basePlans ?? []) {
      const offers = (await api('GET', `/subscriptions/${s.productId}/basePlans/${bp.basePlanId}/offers`))?.subscriptionOffers ?? [];
      plans.push({ ...bp, offers });
    }
    out.push({ productId: s.productId, basePlans: plans });
  }
  return out;
}

function summarisePhase(p) {
  const kind = p.otherRegionsConfig?.free ? 'free'
    : p.otherRegionsConfig?.relativeDiscount != null ? `-${p.otherRegionsConfig.relativeDiscount * 100}%`
    : p.otherRegionsConfig?.absoluteDiscount ? 'absolute'
    : p.regionalConfigs?.some((r) => r.free) ? 'free(regional)' : 'priced';
  return `${p.duration}×${p.recurrenceCount} ${kind}`;
}

function print(cat) {
  console.log(`Package ${pkg}`);
  for (const s of cat) {
    console.log(`  ${s.productId}`);
    for (const bp of s.basePlans) {
      const period = bp.autoRenewingBasePlanType?.billingPeriodDuration ?? bp.prepaidBasePlanType?.billingPeriodDuration;
      const regions = bp.regionalConfigs?.filter((r) => r.newSubscriberAvailability).length ?? 0;
      console.log(`    base plan ${bp.basePlanId} · ${period} · ${bp.state} · grace ${bp.autoRenewingBasePlanType?.gracePeriodDuration ?? '-'} · ${regions} regions`);
      if (bp.offers.length === 0) console.log('      offers: none');
      for (const o of bp.offers) {
        console.log(`      offer ${o.offerId} · ${o.state} · phases [${(o.phases ?? []).map(summarisePhase).join(', ')}]`);
      }
    }
  }
}

function hasFreeWeek(offer) {
  return (offer.phases ?? []).some((p) =>
    p.duration === 'P7D' && (p.otherRegionsConfig?.free || p.regionalConfigs?.every((r) => r.free))
  );
}

// Regions Play refuses in an offer at regions version 2022/02 (seen: MN)
// fall under otherRegionsConfig instead of a regional entry.
const NOT_BILLABLE_IN_OFFER = new Set(['MN']);

/** Creates (if missing) and activates offer `free-week` on one base plan. */
async function ensureFreeWeek(productId, bp, dryRun) {
  const offers = bp.offers ?? [];
  const existing = offers.find((o) => o.offerId === OFFER_ID);
  if (existing?.state === 'ACTIVE' && hasFreeWeek(existing)) {
    console.log(`  ${productId}/${bp.basePlanId}: offer ${OFFER_ID} already ACTIVE, skipping`);
    return;
  }
  if (!existing && offers.some(hasFreeWeek)) {
    console.log(`  ${productId}/${bp.basePlanId}: already has a P7D free offer, skipping`);
    return;
  }
  const regions = (bp.regionalConfigs ?? [])
    .filter((r) => r.newSubscriberAvailability && !NOT_BILLABLE_IN_OFFER.has(r.regionCode))
    .map((r) => r.regionCode);
  console.log(`  ${dryRun ? '[dry-run] would create/activate' : 'creating/activating'} offer ${OFFER_ID} on ${productId}/${bp.basePlanId} (${regions.length} regions + other regions)`);
  if (dryRun) return;
  const body = {
    packageName: pkg,
    productId,
    basePlanId: bp.basePlanId,
    offerId: OFFER_ID,
    // Store eligibility rule (mp-279 §2): one intro offer per new subscriber
    // to any subscription in the app — a cancelled trial is not repeated.
    targeting: { acquisitionRule: { scope: { anySubscriptionInApp: {} } } },
    phases: [{
      duration: 'P7D',
      recurrenceCount: 1,
      regionalConfigs: regions.map((regionCode) => ({ regionCode, free: {} })),
      otherRegionsConfig: { free: {} },
    }],
    regionalConfigs: regions.map((regionCode) => ({ regionCode, newSubscriberAvailability: true })),
    otherRegionsConfig: { otherRegionsNewSubscriberAvailability: true },
  };
  const base = `/subscriptions/${productId}/basePlans/${bp.basePlanId}/offers`;
  if (!existing) {
    await untilOk(`create offer ${productId}/${bp.basePlanId}/${OFFER_ID}`, () =>
      api('POST', `${base}?offerId=${OFFER_ID}&regionsVersion.version=${REGIONS_VERSION}`, body));
    console.log('    offer created');
  }
  await untilOk(`activate offer ${productId}/${bp.basePlanId}/${OFFER_ID}`, () =>
    api('POST', `${base}/${OFFER_ID}:activate`, {
      packageName: pkg, productId, basePlanId: bp.basePlanId, offerId: OFFER_ID,
      latencyTolerance: 'PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_SENSITIVE',
    }));
  console.log('    offer activated');
}

/**
 * Play writes are eventually consistent: a just-created base plan or offer
 * 404s on activate for a while (04-entitlement.md). Retry 404/409/5xx for up
 * to ~5 minutes; any other error is real and thrown at once.
 */
async function untilOk(label, fn, { tries = 30, delayMs = 10000 } = {}) {
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn();
    } catch (e) {
      const status = Number(/→ (\d{3})/.exec(e.message ?? '')?.[1]);
      const transient = status === 404 || status === 409 || status >= 500;
      if (!transient || attempt >= tries) throw e;
      console.log(`    ${label}: ${status}, retry ${attempt}/${tries - 1} in ${delayMs / 1000}s`);
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
}

// Standard and founding Pro tiers from Xuan's RevenueCat spec (docs/revenuecat-spec-for-lee.md).
// One auto-renewing base plan each, US price as listed, other regions converted.
const PRODUCTS = [
  { productId: 'me_pro_monthly', basePlanId: 'monthly', period: 'P1M', usd: '24.99', title: 'Mealvana Pro Monthly' },
  { productId: 'me_pro_annual', basePlanId: 'annual', period: 'P1Y', usd: '199.99', title: 'Mealvana Pro Annual' },
  { productId: 'me_pro_monthly_founding', basePlanId: 'monthly', period: 'P1M', usd: '12.49', title: 'Founding Monthly' },
  { productId: 'me_pro_annual_founding', basePlanId: 'annual', period: 'P1Y', usd: '99.99', title: 'Founding Annual' },
];
// Copied from mealvana_pro_monthly's listing so the store page reads the same.
const LISTING = {
  languageCode: 'en-US',
  description: 'Mealvana Endurance Pro: AI meal planning with Vana, weekly plans and shopping lists built around your training.',
  benefits: ['Weekly meal plans built with Vana', 'Shopping lists in one tap', 'Cooking mode with timers'],
};

function money(currencyCode, decimal) {
  const [units, frac = ''] = decimal.split('.');
  const nanos = Number((frac + '000000000').slice(0, 9));
  return nanos ? { currencyCode, units, nanos } : { currencyCode, units };
}
function fmt(m) {
  return m ? `${m.units ?? 0}.${String(Math.round((m.nanos ?? 0) / 1e7)).padStart(2, '0')} ${m.currencyCode}` : '-';
}

/**
 * Mirrors mealvana_pro_monthly:monthly: a regional config for US at the list
 * price plus otherRegionsConfig with USD + EUR (converted) prices. That plan
 * also has MN, but Play refuses MN at regions version 2022/02 (400 "not
 * billable"), so MN falls under otherRegionsConfig here.
 */
async function basePlanBody(p) {
  const usd = money('USD', p.usd);
  const conv = await api('POST', '/pricing:convertRegionPrices', { price: usd });
  const eur = conv.convertedOtherRegionsPrice?.eurPrice;
  if (!eur) throw new Error(`convertRegionPrices gave no EUR price for ${p.usd} USD`);
  return {
    basePlanId: p.basePlanId,
    regionalConfigs: [{ regionCode: 'US', newSubscriberAvailability: true, price: usd }],
    autoRenewingBasePlanType: {
      billingPeriodDuration: p.period,
      gracePeriodDuration: 'P7D',
      resubscribeState: 'RESUBSCRIBE_STATE_ACTIVE',
      prorationMode: 'SUBSCRIPTION_PRORATION_MODE_CHARGE_ON_NEXT_BILLING_DATE',
      legacyCompatible: true,
    },
    otherRegionsConfig: { usdPrice: usd, eurPrice: eur, newSubscriberAvailability: true },
  };
}

async function createProducts(dryRun) {
  const existing = new Map(((await api('GET', '/subscriptions'))?.subscriptions ?? []).map((s) => [s.productId, s]));
  for (const p of PRODUCTS) {
    console.log(`${p.productId}:${p.basePlanId} · ${p.period} · ${p.usd} USD`);
    let sub = existing.get(p.productId);
    if (!sub) {
      const bp = await basePlanBody(p);
      console.log(`  ${dryRun ? '[dry-run] would create' : 'creating'} subscription (US ${fmt(bp.regionalConfigs[0].price)}, other regions ${fmt(bp.otherRegionsConfig.usdPrice)} / ${fmt(bp.otherRegionsConfig.eurPrice)})`);
      if (dryRun) {
        console.log(`  [dry-run] would activate base plan ${p.basePlanId}, then create/activate offer ${OFFER_ID}`);
        continue;
      }
      sub = await api('POST', `/subscriptions?productId=${p.productId}&regionsVersion.version=${REGIONS_VERSION}`, {
        packageName: pkg,
        productId: p.productId,
        listings: [{ ...LISTING, title: p.title }],
        basePlans: [bp],
        taxAndComplianceSettings: { eeaWithdrawalRightType: 'WITHDRAWAL_RIGHT_SERVICE' },
      });
      console.log('  subscription created');
    } else {
      console.log('  subscription exists');
    }
    const bp = (sub.basePlans ?? []).find((b) => b.basePlanId === p.basePlanId);
    if (!bp) throw new Error(`${p.productId} exists without base plan ${p.basePlanId}; add it by hand or delete the draft`);
    const livePrice = bp.regionalConfigs?.find((r) => r.regionCode === 'US')?.price;
    if (fmt(livePrice) !== fmt(money('USD', p.usd))) {
      console.log(`  WARNING: US price on Play is ${fmt(livePrice)}, table says ${p.usd} USD (not changed)`);
    }
    if (bp.state === 'ACTIVE') {
      console.log(`  base plan ${p.basePlanId} already ACTIVE`);
    } else if (dryRun) {
      console.log(`  [dry-run] would activate base plan ${p.basePlanId} (now ${bp.state})`);
    } else {
      await untilOk(`activate base plan ${p.productId}/${p.basePlanId}`, () =>
        api('POST', `/subscriptions/${p.productId}/basePlans/${p.basePlanId}:activate`, {
          packageName: pkg, productId: p.productId, basePlanId: p.basePlanId,
          latencyTolerance: 'PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_SENSITIVE',
        }));
      console.log(`  base plan ${p.basePlanId} activated`);
    }
    const offers = (await api('GET', `/subscriptions/${p.productId}/basePlans/${p.basePlanId}/offers`))?.subscriptionOffers ?? [];
    await ensureFreeWeek(p.productId, { ...bp, offers }, dryRun);
  }
  if (!dryRun) {
    console.log('\nAfter:');
    print(await catalogue());
  }
}

async function addTrial(dryRun) {
  const cat = await catalogue();
  print(cat);
  for (const s of cat) {
    for (const bp of s.basePlans) {
      if (bp.offers.some(hasFreeWeek)) {
        console.log(`${s.productId}/${bp.basePlanId}: already has a P7D free offer, skipping`);
        continue;
      }
      await ensureFreeWeek(s.productId, bp, dryRun);
    }
  }
  console.log('\nAfter:');
  print(await catalogue());
}

const [cmd = 'list', ...flags] = process.argv.slice(2);
try {
  if (cmd === 'list') print(await catalogue());
  else if (cmd === 'show') console.log(JSON.stringify(await api('GET', `/subscriptions/${flags[0]}`), null, 2));
  else if (cmd === 'add-trial') await addTrial(flags.includes('--dry-run'));
  else if (cmd === 'create-products') await createProducts(flags.includes('--dry-run'));
  else { console.error('usage: play.mjs list | show <productId> | add-trial [--dry-run] | create-products [--dry-run]'); process.exit(2); }
} catch (e) {
  console.error(e.message ?? e);
  process.exit(1);
}
