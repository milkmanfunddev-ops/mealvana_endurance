#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write --allow-run --allow-env --allow-sys
/**
 * Pass 10 — find a photograph of the finished dish, and let the judge decide.
 *
 * Some meals can never be told by their parts. A raspberry-nectarine smoothie
 * is one pink liquid; photographs of raspberries and nectarines describe the
 * shopping list, not the drink. Pass 3 gives those meals `none` and raises
 * `image_blocked`, which is honest and shows the athlete nothing. The only way
 * off that rung is a picture of the finished thing.
 *
 * The change that matters is not the searching. It is WHERE THE JUDGE SITS.
 *
 * Every previous pass accepted on a text score and discovered the problem
 * afterwards, and pass 8's first measurement is what that produces: of the 708
 * meals already carrying a photograph, 539 are of the wrong food. A carton of
 * raw eggs for "Eggs & turkey bacon on toast". A food-court interior for
 * "Congee with pickled vegetables". Every one of those scored well on the words.
 *
 * So here the judge is the gate, not the audit. A candidate is fetched, composed
 * exactly as the athlete would see it, and shown to the same judge pass 8 grades
 * the library with (`lib/meal-image-judge.ts`). Only `ok` is stored — and it is
 * stored with the verdict that bought it, so the picture arrives already
 * measured and pass 8 has nothing to re-judge.
 *
 * BILLS REAL SPEND: up to MAX_JUDGED vision calls per meal, most of them
 * refusals. A refusal is worth keeping, so the URL goes into
 * `image_rejected_urls` and no later run ever pays for that verdict again.
 *
 *   set -a; source secrets/image_apis.env; source secrets/ai_gateway.env; set +a
 *   deno run --allow-net --allow-read --allow-write --allow-run --allow-env --allow-sys \
 *     scripts/meal-images/10-source-dish-photos.ts
 *
 * QUEUE=transformed  meals a mosaic can never serve (the default)
 *      =blocked      every meal the ladder found nothing for
 *      =wrong        meals whose current picture was judged `wrong`, any rung
 *      =recipes      recipes wearing ingredient tiles, whatever their verdict
 *      =all          blocked and wrong
 * Queues combine: QUEUE=wrong,recipes is ticket 05's population.
 * LIMIT=n to sample, DRY=1 to search and judge without writing, CONCURRENCY=n,
 * MAX_JUDGED=n candidates shown to the judge per meal, MAX_ATTEMPTS=n rounds
 * before a meal is left alone, SEPARABILITY=transformed|separable or
 * IDS=a,b,c to narrow a queue, USE_UNSPLASH=1 to add Unsplash as a last resort (slow — see
 * `candidatesFor`).
 *
 * Idempotent: a meal that ends with an `ok` photograph leaves every queue, and a
 * re-run retries only the failures — skipping the candidates already refused.
 *
 * A meal still showing a picture rated `wrong` when its rounds run out is
 * retired (`lib/retire.mjs`): it drops to the Mosaic it is entitled to, which is
 * judged here before the meal is left, or to its icon. A meal already out of
 * rounds is retired without searching again.
 *
 * No two meals are given the same photograph: see `taken` below.
 */
import { rest, selectAll, uploadImage } from './lib/db.mjs';
import { licenseOk, MAY_MIRROR, PROVIDERS } from './lib/providers.mjs';
import { dishQueryVariants, plainDishName } from './lib/dish-query.mjs';
import { rankDishCandidates } from './lib/dish-score.mjs';
import { resolveMealImage } from './lib/ladder.mjs';
import { rememberRejected, retire, showsWrongPicture } from './lib/retire.mjs';
import { CANVAS, composeMosaic } from './lib/compose-mosaic.mjs';
import { createTileFetcher } from './lib/fetch-tile.mjs';
import { squareImage } from './lib/square-image.mjs';
import { estimateSpend, renderRunRow } from './lib/honesty.mjs';
import { appendRun } from './lib/report-doc.mjs';
import { DEFAULT_JUDGE_MODEL, judgeMealImage } from './lib/meal-image-judge.ts';

const MODEL = DEFAULT_JUDGE_MODEL;
const QUEUE = Deno.env.get('QUEUE') ?? 'transformed';
const LIMIT = Number(Deno.env.get('LIMIT') ?? 0);
const CONCURRENCY = Number(Deno.env.get('CONCURRENCY') ?? 3);
const DRY = Deno.env.get('DRY') === '1';
/** How many candidates are worth paying to look at before a dish is given up on. */
const MAX_JUDGED = Number(Deno.env.get('MAX_JUDGED') ?? 3);
/**
 * How many rounds a meal gets before this pass leaves it alone. One, by default.
 *
 * The ingredient bank retries because pass 2 stops at the first candidate that
 * downloads, so a second round genuinely reaches a different picture. Nothing
 * like that is true here: a round already walks MAX_JUDGED candidates, and the
 * next one re-runs the same queries against the same libraries and gets the same
 * answers — every one of them already refused. It would cost hours of provider
 * budget to re-learn what the first round learned.
 *
 * So a second round is worth buying only when THIS PASS has changed — a better
 * query builder, another provider — and then it is a maintainer raising this
 * deliberately, not a default quietly spending on repetition.
 */
const MAX_ATTEMPTS = Number(Deno.env.get('MAX_ATTEMPTS') ?? 1);
/** The square a mirrored photograph is stored at — a dish is shown far larger than a tile. */
const STORED_PX = 1024;
/** See `candidatesFor`: Unsplash's hourly budget costs more wall-clock than it returns. */
const USE_UNSPLASH = Deno.env.get('USE_UNSPLASH') === '1' && !!Deno.env.get('UNSPLASH_ACCESS_KEY');

if (!Deno.env.get('AI_GATEWAY_API_KEY')) {
  console.error('AI_GATEWAY_API_KEY missing — set -a; source secrets/ai_gateway.env; set +a');
  Deno.exit(1);
}

/** Each queue as one PostgREST `or=(…)` term, so any of them can be combined. */
const FILTERS: Record<string, string> = {
  // A mosaic would lie about these, so a photograph is the only thing that can
  // help — including the ones already wearing a photograph of something else.
  transformed: 'and(separability.eq.transformed,or(image_verdict.is.null,image_verdict.neq.ok))',
  blocked: 'and(image_blocked.is.true,image_url.is.null)',
  // Showing a picture of something else — a photograph, a grid or one tile.
  wrong: 'image_verdict.eq.wrong',
  // The meals most likely to have a real photograph somewhere, and the ones a
  // grid of ingredients describes worst: a recipe is a method, not a pile.
  recipes: 'and(kind.eq.recipe,image_mode.in.(mosaic,tile))',
};
const QUEUES = QUEUE === 'all' ? ['blocked', 'wrong'] : QUEUE.split(',').map((q) => q.trim());
if (!QUEUES.length || QUEUES.some((q) => !FILTERS[q])) {
  console.error(`QUEUE must be all, or a comma-separated list of ${Object.keys(FILTERS).join(', ')}`);
  Deno.exit(2);
}

type Row = {
  id: string;
  name: string;
  ingredients: string | null;
  ingredients_json: Array<{ name: string; role?: string }> | null;
  separability: string | null;
  image_mode: string | null;
  image_url: string | null;
  image_tiles: Array<{ url: string }> | null;
  image_verdict: string | null;
  image_rejected_urls: string[] | null;
  image_rejected_mosaics: string[] | null;
  image_attempts: number | null;
};

/**
 * Narrow any queue to one separability, so a round can be spent on the meals a
 * mosaic can never serve without re-searching the ones it can.
 */
const ONLY = Deno.env.get('SEPARABILITY') ?? '';

/**
 * Or to a named handful. `MAX_ATTEMPTS` is a blunt instrument for repair work:
 * raising it to give five known meals another round hands one to every meal
 * that has had one, and re-buys a hundred refusals to fix five rows.
 */
const IDS = (Deno.env.get('IDS') ?? '').split(',').map((s) => s.trim()).filter(Boolean);

const queued: Row[] = await selectAll(
  'meal_library',
  'select=id,name,ingredients,ingredients_json,separability,image_mode,image_url,image_tiles,' +
    'image_verdict,image_rejected_urls,image_rejected_mosaics,image_attempts' +
    `&is_active=eq.true&or=(${QUEUES.map((q) => FILTERS[q]).join(',')})` +
    `${ONLY ? `&separability=eq.${ONLY}` : ''}` +
    `${IDS.length ? `&id=in.(${IDS.map(encodeURIComponent).join(',')})` : ''}&order=id`,
);

/**
 * A meal with a round left is searched. A meal out of rounds is not searched
 * again — the libraries would give the same answers — but if it is still
 * showing a picture the judge rated wrong, it is retired all the same: the
 * spec's rule does not lapse because the meal was unlucky earlier.
 */
const hasRound = (r: Row) => (r.image_attempts ?? 0) < MAX_ATTEMPTS;
let rows = queued.filter(hasRound);
let spent = queued.filter((r) => !hasRound(r) && showsWrongPicture(r));
if (LIMIT) {
  rows = rows.slice(0, LIMIT);
  spent = spent.slice(0, Math.max(0, LIMIT - rows.length));
}

console.log(`model: ${MODEL}`);
console.log(`queue: ${QUEUES.join(' + ')} — ${rows.length} meals, up to ${MAX_JUDGED} candidates each` +
  (spent.length ? `; ${spent.length} out of rounds and still wrong, to retire` : ''));
console.log(`providers: wikimedia, openverse${Deno.env.get('PEXELS_API_KEY') ? ', pexels' : ''}` +
  `${USE_UNSPLASH ? ', unsplash' : ''}\n`);
if (!rows.length && !spent.length) Deno.exit(0);

/**
 * The verified tile bank, so the ladder can answer honestly about any meal.
 *
 * Asking `resolveMealImage` with an empty bank is the same mistake as asking it
 * with no ingredients: a separable meal whose photograph is taken away would
 * come back `no_bank_tile` — "no tile exists for any ingredient" — while its
 * tiles sit in the bank, and a maintainer reading the report could not tell that
 * population from the real one. The bank is 362 rows; reading it once costs a
 * request.
 */
type BankTile = {
  slug: string;
  display_name: string;
  image_url: string;
  license: string;
  creator: string;
  source_url: string;
  provider: string;
};

const bank = new Map<string, BankTile>(
  (await selectAll(
    'ingredient_images',
    'select=slug,display_name,image_url,license,creator,source_url,provider&status=eq.ok',
    { key: 'slug' },
  )).map((r: BankTile) => [r.slug, r]),
);

/**
 * Every photograph the library is already showing, so no two meals get the same one.
 *
 * Stock search is narrow: ask three green-smoothie meals for a green smoothie
 * and all three are offered the same top-ranked picture. On the first run of
 * this pass that happened twice, and four meals ended up sharing one photograph
 * of a blueberry shake — a rail that reads as though it is repeating itself,
 * which is the thing the spec's seventh user story asks us not to do.
 *
 * Cheaper to prevent here than to de-duplicate at render: this is one query and
 * a set membership test, against a rail that would otherwise have to reason
 * about what its neighbours are showing.
 *
 * Compared without the query string, because a stock CDN's resize parameters
 * are not part of the picture's identity.
 */
const identity = (url: string) => url.split('?')[0];
const taken = new Set<string>(
  (await selectAll(
    'meal_library',
    'select=id,image_url&is_active=eq.true&image_url=not.is.null',
  )).map((r: { image_url: string }) => identity(r.image_url)),
);
console.log(`already in use: ${taken.size} distinct photographs\n`);

const dir = await Deno.makeTempDir({ prefix: 'mvdish-' });
const fetchTile = createTileFetcher();

type Candidate = {
  provider: string;
  title: string;
  url: string;
  source_url: string;
  license: string;
  creator: string | null;
  width?: number;
  height?: number;
  download_location?: string;
  /** The search that surfaced it — a wrong photo is usually a wrong query. */
  query: string;
  score: number;
};

/**
 * Everything licensed that any provider offers for this dish, best first.
 *
 * Order is dictated by the metered providers, and it was measured rather than
 * guessed. Pexels allows 180 requests an hour — a twenty-second gap enforced in
 * `ratelimit.mjs` and shared across every worker, so raising CONCURRENCY only
 * lengthens the queue. Asking it first put 70 to 150 seconds of waiting in front
 * of every meal, against one to two seconds of searching and under ten of
 * judging (TIMING=1 prints this).
 *
 * So the unmetered archives go first, across every variant, and Pexels is asked
 * only for the dishes they could not answer. Ranking is not the point of the
 * ordering — the judge decides what is kept either way — so the archives being
 * a worse bet costs a few more refused candidates at a fraction of a cent each,
 * which is the cheaper side of the trade by hours.
 *
 * Unsplash is off by default (USE_UNSPLASH=1). Its 45 an hour is an 80-second
 * gap, and a budget that small cannot serve a library of this size at all.
 */
async function candidatesFor(row: Row): Promise<{ cands: Candidate[]; queries: string[] }> {
  const variants = dishQueryVariants(row.name);
  const plain = plainDishName(row.name);
  // By identity, like `taken`: a refusal at one resize is a refusal at all of them.
  const refused = new Set((row.image_rejected_urls ?? []).map(identity));
  const seen = new Set<string>();
  const pool: Candidate[] = [];
  const queries: string[] = [];

  const ask = async (name: keyof typeof PROVIDERS, q: string) => {
    queries.push(`${name}:${q}`);
    try {
      for (const c of await PROVIDERS[name](q)) {
        if (!c.url || seen.has(c.url) || refused.has(identity(c.url))) continue;
        // Another meal is already showing this one.
        if (taken.has(identity(c.url))) continue;
        if (!licenseOk(c.license)) continue;
        seen.add(c.url);
        pool.push({ ...c, query: q } as Candidate);
      }
    } catch (e) {
      console.log(`  (${name} fail: ${(e as Error).message.slice(0, 44)})`);
    }
  };

  // Ranking the whole pool is cheap but not free, and the search loop asks
  // "have we enough yet?" after every provider — so rank once per answer and
  // keep it, rather than re-sorting the pool three times per variant.
  let ranked = [] as Candidate[];
  const enough = async (name: keyof typeof PROVIDERS, q: string) => {
    await ask(name, q);
    ranked = rankDishCandidates(pool, plain) as Candidate[];
    return ranked.length >= MAX_JUDGED;
  };

  for (const q of variants) {
    await enough('wikimedia', q);
    if (await enough('openverse', q)) break;
  }
  if (ranked.length < MAX_JUDGED && Deno.env.get('PEXELS_API_KEY')) {
    for (const q of variants.slice(0, 2)) {
      if (await enough('pexels', q)) break;
    }
  }
  if (!ranked.length && USE_UNSPLASH) await enough('unsplash', variants[0]);

  return { cands: ranked, queries };
}

/**
 * The picture as the athlete would see it.
 *
 * A dish photo is drawn into the same square the mosaic fills, with the same
 * cover fit, by the same compositor — so the judge grades the picture on the
 * card rather than the photographer's full frame. Pass 8 renders every rung
 * exactly this way, which is what makes the verdict stored here interchangeable
 * with the one it would have reached.
 */
async function compose(id: string, sources: Uint8Array[]): Promise<Uint8Array> {
  const files = sources.map((_, i) => `${dir}/${id}_${i}.src`);
  const out = `${dir}/${id}.jpg`;
  for (const [i, bytes] of sources.entries()) await Deno.writeFile(files[i], bytes);
  try {
    await composeMosaic({ files, out, width: CANVAS, height: CANVAS });
    return await Deno.readFile(out);
  } finally {
    for (const f of [...files, out]) await Deno.remove(f).catch(() => {});
  }
}

const usage = { inputTokens: 0, outputTokens: 0 };

/** Store an accepted photograph, with the verdict that accepted it. */
async function accept(
  row: Row,
  cand: Candidate,
  reason: string,
  bytes: Uint8Array,
  refused: string[],
) {
  // Claimed before the upload, so two workers racing on the same candidate
  // cannot both take it.
  taken.add(identity(cand.url));

  let url = cand.url;
  if ((MAY_MIRROR as Record<string, boolean>)[cand.provider] && !DRY) {
    // Archive material is ours to serve; stock providers require their CDN.
    // The floor rises with the target: cropping a 300px source up to 1024 is an
    // upscale that looks worse than the icon it replaces.
    const square = await squareImage(bytes, STORED_PX, { minSourcePx: STORED_PX / 2 });
    url = await uploadImage('meal-images', `meals/${row.id}.jpg`, square, 'image/jpeg');
  } else if (cand.download_location && USE_UNSPLASH) {
    // Unsplash's API terms require reporting a download when an image is used.
    fetch(cand.download_location, {
      headers: { Authorization: `Client-ID ${Deno.env.get('UNSPLASH_ACCESS_KEY')}` },
    }).catch(() => {});
  }

  // The rung is the ladder's to decide, here as everywhere: a meal with a dish
  // photograph shows the photograph, and is no longer blocked. `tiles` comes
  // back null, so a replaced Mosaic's tiles are cleared rather than left
  // lying beneath the photograph.
  const rung = resolveMealImage({ ...row, image_url: url }, bank);
  const now = new Date().toISOString();

  await patch(row, {
    image_url: url,
    image_source_url: cand.source_url,
    image_license: cand.license,
    image_creator: cand.creator,
    image_provider: cand.provider,
    image_credit: creditLine(cand),
    image_match_query: cand.query,
    image_at: now,
    image_mode: rung.mode,
    image_tiles: rung.tiles,
    image_blocked: rung.blocked,
    image_blocked_reason: rung.blocked ? rung.reason : null,
    // Sourced from a provider whose licence we recorded, so the prototype's
    // unlicensed-hotlink debt does not grow here.
    image_unlicensed: false,
    image_verdict: 'ok',
    image_verdict_reason: reason,
    image_verdict_at: now,
    // The refusals bought on the way to this one. Kept even in success: if this
    // photograph is ever retired, the run that replaces it must not re-judge
    // the pictures already rejected for this meal — nor fall back to the grid
    // this photograph just replaced, if the judge had rated that wrong.
    image_rejected_urls: refused,
    image_rejected_mosaics: rememberRejected(row).image_rejected_mosaics,
    image_attempts: (row.image_attempts ?? 0) + 1,
  });
}

/** What the card shows beneath the picture. Ticket 06 turns this into a link. */
function creditLine(cand: Candidate): string {
  const platform = cand.provider.charAt(0).toUpperCase() + cand.provider.slice(1);
  return cand.creator ? `${cand.creator} / ${platform}` : platform;
}

async function patch(row: Row, body: Record<string, unknown>) {
  if (DRY) return;
  await rest(`meal_library?id=eq.${encodeURIComponent(row.id)}`, {
    method: 'PATCH',
    headers: { Prefer: 'return=minimal' },
    body: JSON.stringify(body),
  });
}

type Outcome = { ok: boolean; why: string; judged: number; retired?: string };

/**
 * Where a meal's wall-clock actually went, for the first few meals of a run.
 *
 * Every provider budget in `ratelimit.mjs` is a global gap rather than a
 * per-worker one, so raising CONCURRENCY does not necessarily raise throughput
 * — and which of search, fetch and judgement is holding the run up is not
 * guessable from the outside. TIMING=1 keeps printing it.
 */
const TIMING = Deno.env.get('TIMING') === '1';
let timed = 0;
function timing(row: Row, search: number, fetch: number, judge: number) {
  if (!TIMING && timed >= 6) return;
  timed++;
  const s = (ms: number) => `${(ms / 1000).toFixed(1)}s`;
  console.log(
    `  [time] ${row.name.slice(0, 34).padEnd(36)}search ${s(search)}  fetch ${s(fetch)}  judge ${s(judge)}`,
  );
}

/**
 * Take the meal's wrong picture away, and do not leave until what it shows
 * instead has been judged.
 *
 * `retire` (lib/retire.mjs) is the ladder answering again without the picture,
 * with every refusal remembered. The next rung down may be a Mosaic this meal
 * has never been judged on — a meal whose photograph was of the wrong food may
 * be entitled to a perfectly good grid — so it is judged here, the same way
 * pass 8 would judge it. Only `ok` keeps it: a meal that was showing the wrong
 * food does not get to keep a thin grid in its place (Lee, 2026-09-10), so a
 * `weak` grid is refused like a wrong one. Retiring again lands on the icon,
 * because the ladder now knows both refusals.
 *
 * A grid that cannot be drawn (a tile host down) is left unjudged rather than
 * guessed at; pass 8 picks it up and pass 9 reports the figure as provisional
 * until it has.
 */
async function retireAndSettle(row: Row): Promise<Record<string, unknown>> {
  let next = retire(row, bank) as Record<string, unknown>;
  const mode = next.image_mode as string;
  if (mode !== 'mosaic' && mode !== 'tile') return next;

  let bytes: Uint8Array;
  try {
    const tiles = next.image_tiles as Array<{ url: string }>;
    bytes = await compose(row.id, await Promise.all(tiles.map((t) => fetchTile(t.url))));
  } catch (e) {
    console.log(`  (${row.name.slice(0, 40)}: fallback ${mode} not drawable — ${(e as Error).message.slice(0, 40)})`);
    return next;
  }
  const { verdict, usage: used } = await judgeMealImage({ meal: row, mode, bytes, model: MODEL });
  usage.inputTokens += used.inputTokens;
  usage.outputTokens += used.outputTokens;
  fallbacksJudged++;

  if (verdict.verdict !== 'ok') {
    next = retire({ ...row, ...next } as Row, bank, { refuse: true }) as Record<string, unknown>;
  } else {
    next = {
      ...next,
      image_verdict: verdict.verdict,
      image_verdict_reason: verdict.reason,
      image_verdict_at: new Date().toISOString(),
    };
  }
  return next;
}

let fallbacksJudged = 0;

async function handle(row: Row): Promise<Outcome> {
  const t0 = Date.now();
  const { cands, queries } = await candidatesFor(row);
  const tSearch = Date.now() - t0;
  let tFetch = 0, tJudge = 0;
  // Starts with the picture being replaced, if it was rated wrong: a later run
  // must never find it again and pay the judge to refuse it twice.
  const refused = rememberRejected(row).image_rejected_urls;
  let judged = 0;

  for (const cand of cands.slice(0, MAX_JUDGED)) {
    let raw: Uint8Array, composed: Uint8Array;
    const tf = Date.now();
    try {
      raw = await fetchTile(cand.url);
      composed = await compose(row.id, [raw]);
      tFetch += Date.now() - tf;
    } catch {
      tFetch += Date.now() - tf;
      // Undownloadable or undecodable: not the judge's problem, and not worth
      // remembering — the next run may find the same picture serving fine.
      continue;
    }

    const tj = Date.now();
    const { verdict, usage: used } = await judgeMealImage({
      meal: row,
      mode: 'dish',
      bytes: composed,
      model: MODEL,
    });
    tJudge += Date.now() - tj;
    usage.inputTokens += used.inputTokens;
    usage.outputTokens += used.outputTokens;
    judged++;

    if (verdict.verdict === 'ok') {
      // The bytes the judge saw are the bytes we store, so an accepted meal is
      // never a second download of something that may have changed.
      await accept(row, cand, verdict.reason, raw, refused);
      timing(row, tSearch, tFetch, tJudge);
      return { ok: true, why: `${cand.provider} ${Math.round(cand.score)} — ${verdict.reason.slice(0, 60)}`, judged };
    }
    // A verdict that was paid for. Kept so no later run buys it again.
    refused.push(cand.url);
  }

  const outOfRounds = (row.image_attempts ?? 0) + 1 >= MAX_ATTEMPTS;
  // A meal showing a picture of the wrong food, with nothing better found and
  // no rounds left, drops down the ladder instead. That is the spec's rule
  // rather than this pass's opinion — a wrong picture is worse than an icon —
  // and it is the only way a meal already wearing one can reach an honest state.
  // A recipe whose grid is `ok` or `weak` keeps it: this pass was looking for
  // something better, not repairing something wrong.
  const retireNow = outOfRounds && showsWrongPicture(row);
  const settled = retireNow ? await retireAndSettle({ ...row, image_rejected_urls: refused }) : null;
  await patch(row, {
    image_rejected_urls: refused,
    image_attempts: (row.image_attempts ?? 0) + 1,
    ...(settled ?? {}),
  });
  timing(row, tSearch, tFetch, tJudge);
  return {
    ok: false,
    why: judged
      ? `${judged} candidate${judged > 1 ? 's' : ''} judged, none ok`
      : `no licensed candidate (${queries.length} searches)`,
    judged,
    retired: settled ? landing(settled) : undefined,
  };
}

/** Where a retired meal came to rest, as the run's summary counts it. */
function landing(p: Record<string, unknown>): string {
  if (p.image_mode === 'none') return `icon (${p.image_blocked_reason})`;
  return `${p.image_mode} rated ${p.image_verdict ?? 'unjudged'}`;
}

let done = 0, served = 0, judgedTotal = 0, failed = 0, spentFailed = 0;
const retiredTo: Record<string, number> = {};
const tallyRetired = (where: string) => (retiredTo[where] = (retiredTo[where] ?? 0) + 1);
const wins: string[] = [];
const queue = [...rows];

// Out of rounds and still wrong: no search, straight down the ladder.
for (const row of spent) {
  try {
    const next = await retireAndSettle(row);
    await patch(row, next);
    tallyRetired(landing(next));
  } catch (e) {
    spentFailed++;
    console.log(`  ERR  ${row.name.slice(0, 46)} — ${(e as Error).message.slice(0, 60)}`);
  }
}

await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
  while (queue.length) {
    const row = queue.shift()!;
    let out: Outcome | null = null;
    for (let attempt = 1; attempt <= 2 && !out; attempt++) {
      try {
        out = await handle(row);
      } catch (e) {
        if (attempt === 2) {
          failed++;
          console.log(`  ERR  ${row.name.slice(0, 46)} — ${(e as Error).message.slice(0, 60)}`);
        } else await new Promise((r) => setTimeout(r, 2000));
      }
    }
    done++;
    if (!out) continue;

    judgedTotal += out.judged;
    if (out.retired) tallyRetired(out.retired);
    if (out.ok) {
      served++;
      wins.push(`${row.name.slice(0, 44).padEnd(46)}${out.why}`);
      console.log(`[${done}/${rows.length}] OK  ${row.name.slice(0, 44).padEnd(46)}${out.why}`);
    } else if (done % 10 === 0) {
      console.log(`[${done}/${rows.length}] ${served} served, ${judgedTotal} candidates judged`);
    }
  }
}));

await Deno.remove(dir, { recursive: true }).catch(() => {});

console.log(
  `\nserved ${served}/${rows.length}` +
    ` (${rows.length ? (100 * served / rows.length).toFixed(1) : '0.0'}%), ${judgedTotal} candidates judged` +
    (fallbacksJudged ? `, ${fallbacksJudged} fallback grids judged` : '') +
    (failed ? `, ${failed} meals errored` : '') +
    (spentFailed ? `, ${spentFailed} out-of-rounds meals errored before retiring` : ''),
);
// Deliberately not "keep their icon": an unserved meal keeps the picture it had
// unless that picture was wrong and it ran out of rounds, and saying otherwise
// would misreport the one thing this pass exists to change.
console.log(`${rows.length - served - failed} meals were not served.`);
const retiredTotal = Object.values(retiredTo).reduce((a, b) => a + b, 0);
if (retiredTotal) {
  console.log(`${retiredTotal} wrong pictures retired; the meals now show:`);
  for (const [where, n] of Object.entries(retiredTo).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${where.padEnd(34)} ${String(n).padStart(5)}`);
  }
}

const spendUsd = estimateSpend({ model: MODEL, ...usage });
const at = new Date().toISOString();
console.log(
  `\ntokens: ${usage.inputTokens.toLocaleString('en-US')} in / ` +
    `${usage.outputTokens.toLocaleString('en-US')} out` +
    (spendUsd === null ? '  (no list price recorded for this model)' : `  ≈ $${spendUsd.toFixed(2)}`),
);

if (DRY) {
  console.log('\nDRY=1 — nothing written');
  Deno.exit(0);
}

// Same ledger as pass 8, because it is the same spend on the same question.
const row = renderRunRow({
  at,
  model: MODEL,
  pass: '10',
  judged: judgedTotal + fallbacksJudged,
  skipped: failed + spentFailed,
  ...usage,
  spendUsd,
});
if (await appendRun(row)) console.log('spend appended to docs/meal-images/honesty.md');
console.log('\nnow: node scripts/meal-images/09-image-report.mjs --write');
