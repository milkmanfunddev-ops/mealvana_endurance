// Image providers for the ingredient tile bank. Wikimedia and Openverse need
// no key; Unsplash and Pexels activate as soon as their key is in the env.
import { take } from './ratelimit.mjs';

const UA = 'MealvanaBot/1.0 (https://mealvana.com; lee.b.martin@gmail.com)';

/**
 * Circuit breaker. A provider that is simply down (Openverse went dark mid-run
 * on 2026-09-08, hanging every request until the 20s timeout) must not cost
 * tries x timeout on every one of ~1,300 ingredients. After enough consecutive
 * failures the provider is dropped for the rest of the run.
 */
const FAILS = new Map();
const TRIP_AFTER = 8;
export const isTripped = (p) => (FAILS.get(p) ?? 0) >= TRIP_AFTER;
const noteFail = (p) => {
  const n = (FAILS.get(p) ?? 0) + 1;
  FAILS.set(p, n);
  if (n === TRIP_AFTER) console.log(`  [circuit] ${p} disabled for this run after ${n} consecutive failures`);
};
const noteOk = (p) => FAILS.set(p, 0);

// Openverse in particular returns sporadic 500/504s, so every provider call
// gets a short backoff rather than losing the ingredient.
const j = async (url, headers = {}, tries = 3, provider = null) => {
  if (provider && isTripped(provider)) return { results: [], query: { pages: {} } };
  let last;
  for (let i = 0; i < tries; i++) {
    try {
      // Without a timeout a single stalled connection hangs a worker for the
      // whole run, so every provider call is bounded.
      const res = await fetch(url, { headers: { 'User-Agent': UA, ...headers }, signal: AbortSignal.timeout(12_000) });
      if (res.ok) { if (provider) noteOk(provider); return res.json(); }
      last = new Error(`${res.status} ${url.slice(0, 90)}`);
      if (res.status < 500 && res.status !== 429) throw last;
    } catch (e) { last = e; }
    await new Promise((r) => setTimeout(r, 400 * (i + 1) ** 2));
  }
  if (provider) noteFail(provider);
  throw last;
};

// Licenses we will ship. Anything else is dropped rather than guessed at.
const OK_LICENSE = /^(cc0|public domain|pdm|cc by(-sa)?( \d(\.\d)?)?|unsplash|pexels)$/i;

export function licenseOk(name) {
  if (!name) return false;
  const n = String(name).toLowerCase().replace(/[_]/g, ' ').trim();
  if (/no derivatives|nd\b|noncommercial|non-commercial|nc\b|fair use|copyright/.test(n)) return false;
  return OK_LICENSE.test(n) || /^cc[- ]by([- ]sa)?[- ]?\d/.test(n);
}

export async function wikimedia(q) {
  await take('wikimedia');
  const url = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search'
    + `&gsrsearch=${encodeURIComponent(`filetype:bitmap ${q}`)}&gsrlimit=12&gsrnamespace=6`
    + '&prop=imageinfo&iiprop=url|extmetadata|size|mime&iiurlwidth=1024';
  const d = await j(url, {}, 3, 'wikimedia');
  return Object.values(d?.query?.pages ?? {}).map((p) => {
    const ii = p.imageinfo?.[0] ?? {};
    const md = ii.extmetadata ?? {};
    const strip = (v) => (v ? String(v.value).replace(/<[^>]*>/g, '').trim() : null);
    return {
      provider: 'wikimedia',
      title: p.title.replace(/^File:/, '').replace(/\.[a-z]+$/i, ''),
      url: ii.thumburl || ii.url,
      source_url: ii.descriptionurl,
      license: strip(md.LicenseShortName),
      creator: strip(md.Artist),
      width: ii.thumbwidth || ii.width, height: ii.thumbheight || ii.height,
      mime: ii.mime,
    };
  }).filter((c) => c.url);
}

export async function openverse(q) {
  await take('openverse');
  // Two tries only: a dead Openverse should trip the breaker fast.
  const d = await j(`https://api.openverse.org/v1/images/?q=${encodeURIComponent(q)}`
    + '&page_size=12&license_type=all-cc,commercial&mature=false', {}, 2, 'openverse');
  return (d.results ?? []).map((r) => ({
    provider: 'openverse',
    title: r.title ?? '',
    url: r.url,
    source_url: r.foreign_landing_url ?? r.url,
    license: `CC ${r.license}${r.license_version ? ' ' + r.license_version : ''}`.trim(),
    creator: r.creator ?? null,
    width: r.width, height: r.height,
  })).filter((c) => c.url);
}

export async function unsplash(q) {
  const k = process.env.UNSPLASH_ACCESS_KEY;
  if (!k) return [];
  await take('unsplash');
  const d = await j(`https://api.unsplash.com/search/photos?query=${encodeURIComponent(q)}&per_page=10&orientation=squarish&content_filter=high`,
    { Authorization: `Client-ID ${k}` }, 3, 'unsplash');
  return (d.results ?? []).map((r) => ({
    provider: 'unsplash',
    title: [r.description, r.alt_description].filter(Boolean).join(' '),
    url: `${r.urls.raw}&w=512&h=512&fit=crop&crop=entropy&fm=jpg&q=80`,
    source_url: r.links.html,
    license: 'Unsplash',
    creator: r.user?.name ?? null,
    width: 512, height: 512,
    // Unsplash API terms require pinging this when an image is used.
    download_location: r.links.download_location,
  }));
}

export async function pexels(q) {
  const k = process.env.PEXELS_API_KEY;
  if (!k) return [];
  await take('pexels');
  const d = await j(`https://api.pexels.com/v1/search?query=${encodeURIComponent(q)}&per_page=10&orientation=square`,
    { Authorization: k }, 3, 'pexels');
  return (d.photos ?? []).map((r) => ({
    provider: 'pexels',
    title: r.alt ?? '',
    url: `${r.src.original}?auto=compress&cs=tinysrgb&fit=crop&w=512&h=512`,
    source_url: r.url,
    license: 'Pexels',
    creator: r.photographer ?? null,
    width: r.width, height: r.height,
  }));
}

export const PROVIDERS = { wikimedia, openverse, unsplash, pexels };

/**
 * Whether a provider's image may be copied into our own storage.
 *
 * Unsplash's production checklist explicitly requires photos to be hotlinked
 * to the original Unsplash CDN URL and a download event to be triggered on
 * use; Pexels likewise expects hotlinking plus a link back. Mirroring those
 * would breach both. Creative Commons material from Wikimedia and Openverse
 * carries no such restriction, so we mirror it for speed and durability.
 */
export const MAY_MIRROR = { wikimedia: true, openverse: true, unsplash: false, pexels: false };

/**
 * Search terms to try for one ingredient, most food-biased first. Commons and
 * Openverse both rank the botanical organism highly for bare produce names, so
 * we ask for the food context explicitly and merge the results.
 */
export function queryVariants(name) {
  // "<name> food" keeps Commons off the botanical organism; "isolated" and
  // "fresh" pull subject-only shots rather than finished dishes.
  return [`${name} isolated`, `${name} food`, name, `fresh ${name}`];
}
