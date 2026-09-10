// Pass 2: for every pending ingredient, search all available providers, pick
// the best-scoring properly-licensed photo, square it to a 512px tile with
// sips, mirror it into Supabase Storage and record full attribution.
// Idempotent: only rows with status='pending' are touched.
import { selectAll, rest, uploadImage } from './lib/db.mjs';
import { squareImage } from './lib/square-image.mjs';
import { PROVIDERS, licenseOk, queryVariants, MAY_MIRROR, isTripped } from './lib/providers.mjs';
import { rankCandidates, MIN_SCORE, TAIL_MIN_SCORE } from './lib/score.mjs';

const TILE = 512;
const LIMIT = Number(process.env.LIMIT ?? 0);
const CONCURRENCY = Number(process.env.CONCURRENCY ?? 5);

const hasUnsplash = !!process.env.UNSPLASH_ACCESS_KEY;
const hasPexels = !!process.env.PEXELS_API_KEY;
// Unsplash demo allows only 45 usable req/hour, so it is spent on the
// highest-frequency ingredients (which appear on the most meal cards) rather
// than burned on the long tail.
const UNSPLASH_TOP = Number(process.env.UNSPLASH_TOP ?? 250);
// Pexels allows 200 req/hour, i.e. 20s per ingredient. Spending it on all
// ~1,300 ingredients would take 7h, so the metered libraries lead only for the
// highest-frequency ingredients (the ones on the most meal cards) and act as a
// rescue for the long tail when the free archives find nothing usable.
const STOCK_TOP = Number(process.env.STOCK_TOP ?? 450);
console.log(`providers: wikimedia, openverse${hasPexels ? ', pexels' : ''}`
  + `${hasUnsplash ? ` , unsplash (top ${UNSPLASH_TOP} only)` : ''}`);

let pending = await selectAll('ingredient_images',
  'select=slug,display_name,rows_using,rejected_urls,attempts&status=eq.pending&order=rows_using.desc', { key: 'slug' });
pending = pending.map((p, i) => ({ ...p, rank: i + 1 }));
if (LIMIT) pending = pending.slice(0, LIMIT);
console.log(`pending ingredients: ${pending.length}\n`);

/** Download and centre-crop to a square TILE. The crop itself is shared with
 *  pass 10, which mirrors dish photographs the same way (`lib/square-image.mjs`). */
async function makeTile(url) {
  // Flickr (via Openverse) and some Commons mirrors reject bare requests, so
  // send a browser-shaped header set.
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'MealvanaBot/1.0 (https://mealvana.com; lee.b.martin@gmail.com)',
      Accept: 'image/avif,image/webp,image/jpeg,image/png,*/*',
      Referer: new URL(url).origin + '/',
    },
    signal: AbortSignal.timeout(25_000),
  });
  if (!res.ok) throw new Error(`download ${res.status}`);
  return squareImage(Buffer.from(await res.arrayBuffer()), TILE);
}

async function handle(ing) {
  const q = ing.display_name;
  const cands = [];
  const seen = new Set();
  const add = async (name, fn, variant) => {
    if (isTripped(name)) return;
    try {
      for (const c of await fn(variant)) {
        if (seen.has(c.url)) continue;
        seen.add(c.url); cands.push(c);
      }
    } catch (e) { process.stdout.write(`  (${name} fail: ${e.message.slice(0, 40)})\n`); }
  };

  // Common ingredients earn the benefit of the doubt; rare ones must be clearly right.
  const bar = ing.rows_using >= 8 ? MIN_SCORE : TAIL_MIN_SCORE;
  const topCand = () => rankCandidates(cands.filter((c) => licenseOk(c.license)), q)
    .filter((c) => c.score >= bar)[0];
  const strong = () => (topCand()?.score ?? 0) >= MIN_SCORE + 85;
  const priority = ing.rank <= STOCK_TOP;

  const archives = async () => {
    for (const variant of queryVariants(q)) {
      await add('wikimedia', PROVIDERS.wikimedia, variant);
      await add('openverse', PROVIDERS.openverse, variant);
      if (cands.length >= 30 || strong()) break;
    }
  };
  // Stock search is literal, and a bare ingredient word is ambiguous in ways
  // the archives are not: "chicken" returns a live bird, "salt" a beach,
  // "ginger" a can of ginger ale, "cinnamon" cinnamon-sugar cookies. Ask for
  // the food first and fall back to the bare word only if that finds nothing.
  // (Ranking still scores candidate titles against the bare `q`.)
  const stock = async () => {
    for (const variant of [`${q} food ingredient`, `${q} food`, q]) {
      if (hasPexels) await add('pexels', PROVIDERS.pexels, variant);
      if (hasUnsplash && ing.rank <= UNSPLASH_TOP && !strong()) {
        await add('unsplash', PROVIDERS.unsplash, variant);
      }
      if (cands.length >= 30 || strong()) break;
    }
  };

  if (priority) {
    await stock();                    // quality first on the ingredients that show most
    if (!strong()) await archives();
  } else {
    await archives();                 // unmetered first on the long tail
    if (!topCand()) await stock();    // metered rescue only when nothing was found
  }
  // A candidate already tried and rejected by vision must not be picked again,
  // or a retry round hands back the same photo of the wrong food.
  const blocked = new Set(ing.rejected_urls ?? []);
  const legal = cands.filter((c) => licenseOk(c.license) && !blocked.has(c.url));
  const ranked = rankCandidates(legal, q).filter((c) => c.score >= bar);

  const markNone = () => rest(`ingredient_images?slug=eq.${encodeURIComponent(ing.slug)}`, {
    method: 'PATCH', headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({
      status: 'none', match_query: q, attempts: (ing.attempts ?? 0) + 1,
      fetched_at: new Date().toISOString(),
    }),
  });

  if (!ranked.length) {
    await markNone();
    return { slug: ing.slug, ok: false, why: `no candidate (${cands.length} seen, ${legal.length} licensed)` };
  }

  // Walk down the ranking: the top pick is often a dead hotlink or a thumbnail
  // too small to crop, and the runner-up is usually just as good.
  let best, bytes, lastErr;
  for (const cand of ranked.slice(0, 6)) {
    try {
      if (MAY_MIRROR[cand.provider]) {
        bytes = await makeTile(cand.url);       // CC: mirror into our storage
      } else {
        // Unsplash/Pexels: their terms require serving from their CDN, so we
        // only verify the hotlink resolves and keep the URL as-is.
        const head = await fetch(cand.url, {
          method: 'GET', headers: { Range: 'bytes=0-2047' },
          signal: AbortSignal.timeout(20_000),
        });
        if (!head.ok) throw new Error(`hotlink ${head.status}`);
        bytes = null;
      }
      best = cand; break;
    } catch (e) { lastErr = e; }
  }
  if (!best) {
    await markNone();
    return { slug: ing.slug, ok: false, why: `all ${Math.min(ranked.length, 6)} candidates failed (${lastErr?.message.slice(0, 40)})` };
  }

  const publicUrl = bytes
    ? await uploadImage('meal-images', `ingredients/${ing.slug}.jpg`, bytes, 'image/jpeg')
    : best.url;

  // Unsplash's API terms require reporting a download when an image is used.
  if (best.download_location && process.env.UNSPLASH_ACCESS_KEY) {
    fetch(best.download_location, { headers: { Authorization: `Client-ID ${process.env.UNSPLASH_ACCESS_KEY}` } }).catch(() => {});
  }

  await rest(`ingredient_images?slug=eq.${encodeURIComponent(ing.slug)}`, {
    method: 'PATCH', headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({
      status: 'ok', image_url: publicUrl, origin_url: best.url, source_url: best.source_url,
      license: best.license, creator: best.creator, provider: best.provider,
      match_query: q, width: TILE, height: TILE, attempts: (ing.attempts ?? 0) + 1,
      fetched_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    }),
  });
  return { slug: ing.slug, ok: true, why: `${best.provider} ${Math.round(best.score)} ${best.license}` };
}

let done = 0, ok = 0;
const queue = [...pending];

// A transient network drop must not drain the queue. Losing connectivity once
// previously burned 1,110 ingredients in seconds, because each simply logged
// and moved on. Now an ingredient is retried, and a sustained outage parks
// every worker until the network answers again.
let consecutiveFailures = 0;
async function waitForNetwork() {
  for (let wait = 15_000; ; wait = Math.min(wait * 2, 300_000)) {
    await new Promise((r) => setTimeout(r, wait));
    try {
      const res = await fetch('https://commons.wikimedia.org/robots.txt', { signal: AbortSignal.timeout(10_000) });
      if (res.ok) { console.log('  [network] back up, resuming'); consecutiveFailures = 0; return; }
    } catch { /* still down */ }
    console.log('  [network] still down, waiting');
  }
}

await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
  while (queue.length) {
    const ing = queue.shift();
    let handled = false;
    for (let attempt = 1; attempt <= 3 && !handled; attempt++) {
      try {
        const r = await handle(ing);
        consecutiveFailures = 0;
        if (r.ok) ok++;
        done++; handled = true;
        if (done % 25 === 0 || !r.ok) console.log(`[${done}/${pending.length}] ${r.ok ? 'OK ' : '-- '} ${r.slug} :: ${r.why}`);
      } catch (e) {
        consecutiveFailures++;
        if (attempt === 3) {
          done++;
          console.log(`[${done}] ERR ${ing.slug}: ${e.message.slice(0, 80)} (left pending for a re-run)`);
        } else {
          await new Promise((r) => setTimeout(r, 2000 * attempt));
        }
        // Many failures in a row across workers means the network, not the row.
        if (consecutiveFailures >= 15) await waitForNetwork();
      }
    }
  }
}));
console.log(`\ndone: ${ok}/${pending.length} matched (${(100 * ok / pending.length).toFixed(1)}%)`);
