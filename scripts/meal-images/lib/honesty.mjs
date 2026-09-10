// The honesty measure: what the library is actually showing, counted once.
//
// Coverage was the old headline — "1,816 of 1,922 meals have a picture, 94.5%"
// — and it counted a photograph of water as a covered meal. It is still worth
// printing, next to the honest number, so the gap between them is visible; it
// is no longer the number anyone quotes.
//
//   honesty = meals showing an image a judge rated `ok`
//           + meals honestly showing nothing (the blocked flag, with a reason)
//           ------------------------------------------------------------------
//           / every active meal
//
// A `weak` picture is not misleading but does not count as honest; a `wrong`
// one is the work queue. An unjudged meal counts as neither — it is unmeasured,
// and while any exist the figure is provisional (`complete: false`).
//
// Pure: no network, no database, no model, no mutation of its arguments. Pass 9
// is the impure shell that reads the rows and writes the document.

/** The rungs of the ladder, in print order. */
export const MODES = ['dish', 'mosaic', 'tile', 'none'];

/** The verdicts pass 8 can record. */
export const VERDICTS = ['ok', 'weak', 'wrong'];

/**
 * List price per million tokens, in USD, for the models these passes use.
 *
 * Only used to state what a run cost. An unpriced model reports null rather
 * than a confidently wrong number — the AI Gateway's own invoice is the
 * authority, and this is an estimate at list price.
 */
export const PRICES_USD_PER_MTOK = {
  'anthropic/claude-sonnet-5': { input: 2.00, output: 10.00 },
  'anthropic/claude-opus-5': { input: 5.00, output: 25.00 },
  'anthropic/claude-haiku-4.5': { input: 1.00, output: 5.00 },
  'anthropic/claude-haiku-4-5': { input: 1.00, output: 5.00 },
};

/**
 * What moves a library meal up a browse rail.
 *
 * `search_meals` orders by `score desc, id`, and on an unqueried browse every
 * library row scores the same 0.5 base — so `frequency` is the only thing that
 * separates them. Mirrored here rather than re-derived: if the SQL's bonuses
 * change, this changes with it.
 */
export const FREQUENCY_BONUS = { staple: 0.04, common: 0.02, occasional: 0 };

/**
 * Count what the library is showing.
 *
 * @param {Array<{id: string, image_mode: string, image_verdict: string|null,
 *                image_blocked: boolean, image_blocked_reason: string|null}>} rows
 *   Every active meal.
 * @returns {{total: number, honest: number, honestPct: number, coverage: number,
 *            coveragePct: number, unjudged: number, unaccounted: number,
 *            complete: boolean, byMode: Record<string, object>,
 *            blocked: number, blockedByReason: Record<string, number>,
 *            byVerdict: Record<string, number>}}
 */
export function summarise(rows) {
  const byMode = Object.fromEntries(
    MODES.map((m) => [m, { total: 0, ok: 0, weak: 0, wrong: 0, unjudged: 0 }]),
  );
  const byVerdict = { ok: 0, weak: 0, wrong: 0 };
  const blockedByReason = {};

  let honest = 0, coverage = 0, unjudged = 0, unaccounted = 0, blocked = 0;

  for (const row of rows) {
    const mode = MODES.includes(row.image_mode) ? row.image_mode : 'none';
    const bucket = byMode[mode];
    bucket.total++;

    if (mode === 'none') {
      // A meal showing nothing is honest when the ladder says so. Without the
      // flag the two passes disagree, and a disagreement must not be counted
      // as a success — it is unaccounted for, and shown as such.
      if (row.image_blocked) {
        blocked++;
        honest++;
        const reason = row.image_blocked_reason || 'unrecorded';
        blockedByReason[reason] = (blockedByReason[reason] ?? 0) + 1;
      } else {
        unaccounted++;
      }
      continue;
    }

    coverage++;
    const verdict = VERDICTS.includes(row.image_verdict) ? row.image_verdict : null;
    if (verdict === null) {
      bucket.unjudged++;
      unjudged++;
      continue;
    }
    bucket[verdict]++;
    byVerdict[verdict]++;
    if (verdict === 'ok') honest++;
  }

  const pct = (n) => (rows.length ? Number(((100 * n) / rows.length).toFixed(1)) : 0);
  return {
    total: rows.length,
    honest,
    honestPct: pct(honest),
    coverage,
    coveragePct: pct(coverage),
    unjudged,
    unaccounted,
    complete: unjudged === 0,
    blocked,
    blockedByReason,
    byMode,
    byVerdict,
  };
}

/**
 * Order meals by how often each surfaces to an athlete, most-surfaced first.
 *
 * There is no impression counter — nothing records how many times a meal has
 * been drawn on a screen. What there is, is the ordering the rails themselves
 * use, and it is deterministic, so "how often this surfaces" is derivable from
 * the row:
 *
 *   1. frequency — the only term that separates library rows in `search_meals`;
 *   2. contexts — the number of rails the meal is eligible for at all;
 *   3. allergens — every allergen hides the meal from the athletes who carry it;
 *   4. id — so the order is total and a re-run produces the same list.
 *
 * Fixing the top of this list repairs more screens than fixing the bottom.
 */
export function rankByReach(rows) {
  const key = (r) => [
    -(FREQUENCY_BONUS[r.frequency] ?? 0),
    -(r.contexts?.length ?? 0),
    r.allergens?.length ?? 0,
  ];
  return [...rows].sort((a, b) => {
    const ka = key(a), kb = key(b);
    for (let i = 0; i < ka.length; i++) if (ka[i] !== kb[i]) return ka[i] - kb[i];
    return String(a.id).localeCompare(String(b.id));
  });
}

/**
 * What a judging run cost, at list price, in USD.
 *
 * @returns {number|null} null when the model has no price recorded here.
 */
export function estimateSpend({ model, inputTokens = 0, outputTokens = 0 }) {
  const price = PRICES_USD_PER_MTOK[model];
  if (!price) return null;
  return (inputTokens * price.input + outputTokens * price.output) / 1_000_000;
}

const usd = (n) => (n === null || n === undefined ? '—' : `$${n.toFixed(2)}`);

/** The measure, as the document records it. */
export function renderReport({ summary: s, wrong = [], geometryVersion, at, wrongShown = 40 }) {
  const l = [];
  l.push(`_Measured ${at.slice(0, 10)}, against mosaic geometry v${geometryVersion}. Regenerated by`);
  l.push('`node scripts/meal-images/09-image-report.mjs --write`; do not edit by hand._');
  l.push('');
  l.push(`## Honesty: ${s.honestPct.toFixed(1)}%`);
  l.push('');
  l.push(`**${s.honest} of ${s.total} active meals** either show a picture a judge rated \`ok\`, or`);
  l.push(`honestly show nothing. ${s.coverage} of them (${s.coveragePct.toFixed(1)}%) have *a* picture —`);
  l.push('that is coverage, and the gap between the two numbers is the work.');
  if (!s.complete) {
    l.push('');
    l.push(`> **Provisional.** ${s.unjudged} meals showing a picture have no verdict yet, so the`);
    l.push('> figure above can only fall. Re-run pass 8.');
  }
  if (s.unaccounted) {
    l.push('');
    l.push(`> **${s.unaccounted} meals show nothing and are not flagged blocked.** Passes 3 and 8`);
    l.push('> disagree about them; they are counted as neither honest nor wrong. Re-run pass 3.');
  }
  l.push('');
  l.push('| mode | meals | ok | weak | wrong | unjudged |');
  l.push('|---|---:|---:|---:|---:|---:|');
  for (const mode of MODES) {
    const m = s.byMode[mode];
    if (mode === 'none') {
      l.push(`| \`none\` | ${m.total} | — | — | — | — |`);
      continue;
    }
    l.push(`| \`${mode}\` | ${m.total} | ${m.ok} | ${m.weak} | ${m.wrong} | ${m.unjudged} |`);
  }
  l.push('');
  l.push(`### Showing nothing — ${s.blocked} meals`);
  l.push('');
  l.push('| reason | meals |');
  l.push('|---|---:|');
  for (const [reason, n] of Object.entries(s.blockedByReason).sort((a, b) => b[1] - a[1])) {
    l.push(`| \`${reason}\` | ${n} |`);
  }
  l.push('');
  l.push(`### Showing something wrong — ${s.byVerdict.wrong} meals`);
  l.push('');
  l.push('Most-surfaced first: frequency, then how many rails the meal is eligible for, then how');
  l.push('few athletes an allergen hides it from. This is the work queue for tickets 04 and 05.');
  l.push('');
  if (wrong.length) {
    l.push('| # | meal | mode | what the picture shows |');
    l.push('|---:|---|---|---|');
    wrong.slice(0, wrongShown).forEach((w, i) => {
      const cell = (v) => String(v ?? '').replace(/\|/g, '\\|');
      l.push(`| ${i + 1} | ${cell(w.name)} | \`${w.image_mode}\` | ${cell(w.image_verdict_reason)} |`);
    });
    if (wrong.length > wrongShown) {
      l.push('');
      l.push(`_${wrong.length - wrongShown} more. The full list:_`);
      l.push('`node scripts/meal-images/09-image-report.mjs --wrong`');
    }
  } else {
    l.push('_None._');
  }
  return l.join('\n');
}

/** One row of the spend ledger pass 8 appends to. */
export function renderRunRow({ at, model, geometryVersion, judged, skipped, inputTokens, outputTokens, spendUsd }) {
  return `| ${at.slice(0, 16).replace('T', ' ')} | \`${model}\` | v${geometryVersion} | ` +
    `${judged} | ${skipped} | ${inputTokens.toLocaleString('en-US')} | ` +
    `${outputTokens.toLocaleString('en-US')} | ${usd(spendUsd)} |`;
}

/**
 * Replace the body of one generated region, leaving the rest of the document
 * exactly as it was.
 *
 * The alternative — regenerating the whole file — would delete anything a
 * person had written around the numbers, which is most of what makes the
 * document worth reading.
 */
export function spliceRegion(doc, name, body) {
  const begin = `<!-- ${name}:begin -->`;
  const end = `<!-- ${name}:end -->`;
  const from = doc.indexOf(begin);
  const to = doc.indexOf(end);
  if (from === -1 || to === -1 || to < from) {
    throw new Error(`no ${begin} … ${end} region in the document`);
  }
  return doc.slice(0, from + begin.length) + '\n' + body + '\n' + doc.slice(to);
}
