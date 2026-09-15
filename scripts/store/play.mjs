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

async function addTrial(dryRun) {
  const cat = await catalogue();
  print(cat);
  for (const s of cat) {
    for (const bp of s.basePlans) {
      if (bp.offers.some(hasFreeWeek)) {
        console.log(`${s.productId}/${bp.basePlanId}: already has a P7D free offer, skipping`);
        continue;
      }
      const regions = (bp.regionalConfigs ?? []).filter((r) => r.newSubscriberAvailability).map((r) => r.regionCode);
      console.log(`${dryRun ? '[dry-run] would create' : 'creating'} offer ${OFFER_ID} on ${s.productId}/${bp.basePlanId} (${regions.length} regions + other regions)`);
      if (dryRun) continue;
      const body = {
        packageName: pkg,
        productId: s.productId,
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
        otherRegionsConfig: { newSubscriberAvailability: true },
      };
      const existing = bp.offers.find((o) => o.offerId === OFFER_ID);
      if (!existing) {
        await api('POST', `/subscriptions/${s.productId}/basePlans/${bp.basePlanId}/offers?offerId=${OFFER_ID}&regionsVersion.version=${REGIONS_VERSION}`, body);
        console.log('  created');
      }
      // Activation is eventually consistent (04-entitlement.md): retry a few times.
      for (let attempt = 1; attempt <= 5; attempt++) {
        try {
          await api('POST', `/subscriptions/${s.productId}/basePlans/${bp.basePlanId}/offers/${OFFER_ID}:activate`, {});
          console.log('  activated');
          break;
        } catch (e) {
          if (attempt === 5) throw e;
          console.log(`  activate attempt ${attempt} failed, retrying…`);
          await new Promise((r) => setTimeout(r, 3000 * attempt));
        }
      }
    }
  }
  console.log('\nAfter:');
  print(await catalogue());
}

const [cmd = 'list', ...flags] = process.argv.slice(2);
try {
  if (cmd === 'list') print(await catalogue());
  else if (cmd === 'add-trial') await addTrial(flags.includes('--dry-run'));
  else { console.error('usage: play.mjs list | add-trial [--dry-run]'); process.exit(2); }
} catch (e) {
  console.error(e.message ?? e);
  process.exit(1);
}
