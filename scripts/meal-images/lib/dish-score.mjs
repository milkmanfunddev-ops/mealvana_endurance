// Ranking candidate photographs of a finished dish.
//
// This is `score.mjs` turned around. A tile wants one ingredient alone against
// a plain background, so that file penalises every sign of a composed plate. A
// dish photo wants exactly that plate: "served", "bowl of", "garnish" are the
// signals, and "isolated on white" now means someone photographed the raw
// ingredients instead of the food.
//
// What both files share is the reason they exist at all: a title is all a
// search API returns, and a title is a weak description of a picture. Neither
// ranking is trusted to be right — the judge is. Ranking only decides what the
// judge looks at first, and how few calls it takes to find something honest.
//
// Pure: no network, no database, no model. Tested in `dish-score.test.mjs`.
import { plainDishName } from './dish-query.mjs';
import { COLUMN, PANORAMA, PROVIDER_BONUS } from './score.mjs';

const STOPWORDS = new Set([
  'and', 'the', 'with', 'over', 'for', 'from', 'into', 'plus', 'style', 'made',
]);

/** Contexts that are the right words attached to the wrong photograph. */
const NEGATIVE = [
  [/packaging|package|carton|wrapper|barcode|\blabel\b|nutrition facts|ingredient list|\bbrand\b|canned|tinned|\btin of\b/, -60],
  [/logo|signage|billboard|poster|menu\b|screenshot|clipart|vector|\bicon\b|diagram|infographic/, -55],
  [/portrait|selfie|\bwoman\b|\bman\b|\bchild\b|\bpeople\b|\bperson\b|crowd|chef\b|waiter/, -45],
  [/supermarket|grocery|aisle|shelf|market stall|restaurant exterior|street food stall|food court/, -45],
  [/farm|field|crop|orchard|plantation|harvest|greenhouse|flower|blossom|foliage|\bplant\b/, -50],
  [/museum|monument|statue|\bcoin\b|\bstamp\b|banknote|\bflag\b|book cover/, -50],
  [/mold|mould|rotten|spoiled|decay|pest|insect/, -70],
  [/illustration|engraving|lithograph|painting|drawing|sketch|cartoon|3d render/, -45],
  // The tile-shaped mistake: the raw components photographed, not the food.
  [/isolated|on white|white background|cut ?out|\bingredients\b|\braw\b|uncooked/, -25],
];

/** The dish actually being on a plate, which is the whole point here. */
const POSITIVE = [
  [/\bserved\b|serving|plated|\bplate\b|\bplatter\b|\bbowl\b|garnish|topped with|drizzled/, 14],
  [/homemade|home[- ]cooked|freshly (made|baked|cooked)|traditional/, 12],
  [/recipe|\bdish\b|\bmeal\b|cuisine|delicious|tasty/, 8],
  [/close[- ]?up|closeup|top view|flat lay|overhead/, 6],
];

const clean = (s) =>
  String(s || '').toLowerCase().replace(/[_]+/g, ' ').replace(/\s+/g, ' ').trim();

/** Crude singular/plural fold, so "muffins" and "muffin" are one word. */
const stem = (w) => w.replace(/(?:ies)$/, 'y').replace(/(?:es|s)$/, '');

const words = (s) => clean(s).split(/[^\p{L}\p{N}'-]+/u).filter(Boolean);

const significant = (s) =>
  words(s).filter((w) => w.length > 2 && !STOPWORDS.has(w)).map(stem);

/**
 * The thing the photograph has to be OF.
 *
 * "Mushroom risotto with parmesan" is a picture of risotto; parmesan is a
 * detail. A candidate missing every other word can still be the dish, and a
 * candidate missing this one never is — which is why it is a gate below rather
 * than another few points.
 */
export function dishHeadNoun(name) {
  const head = plainDishName(name).replace(/\s+(?:with|over|on|in|and a)\s+.+$/i, '').split(',')[0];
  const w = significant(head);
  return w.length ? w[w.length - 1] : null;
}

/**
 * Score one candidate against the dish it is meant to show.
 *
 * @returns {number|null} null when the candidate must not be used at all
 */
export function scoreDishCandidate(cand, dishName) {
  const plain = plainDishName(dishName);
  const head = dishHeadNoun(plain);
  if (!head) return null;

  const title = clean(cand.title);
  const titleStems = new Set(significant(title));
  if (!titleStems.has(head)) return null;   // not a photograph of this dish

  const terms = significant(plain);
  const hits = terms.filter((t) => titleStems.has(t)).length;
  // A dish name is long and a stock title is short, so full coverage is rare
  // and demanding it would refuse every real photograph. Coverage ranks; the
  // head noun above is what gates.
  let score = 55 + 55 * (hits / terms.length);

  // The dish named as a phrase beats its words merely co-occurring.
  const phrase = plain.replace(/\s+(?:with|over|on|in|and a)\s+.+$/i, '').split(',')[0];
  if (phrase.length >= 4 && title.includes(clean(phrase))) score += 25;

  for (const [re, w] of NEGATIVE) if (re.test(title)) score += w;
  for (const [re, w] of POSITIVE) if (re.test(title)) score += w;

  const w = cand.width || 0, h = cand.height || 0;
  if (w && h) {
    // A dish photo is shown far larger than a 150px tile, so the floor is higher.
    if (Math.min(w, h) < 500) score -= 40;
    const ar = w / h;
    if (ar > PANORAMA || ar < COLUMN) score -= 35;
  }

  score += PROVIDER_BONUS[cand.provider] ?? 0;

  const n = title.split(' ').length;
  if (n <= 6) score += 8;
  if (n > 16) score -= 12;

  return score;
}

/** The floor a candidate must clear before the judge is asked to look at it. */
export const MIN_DISH_SCORE = 60;

/**
 * Every acceptable candidate, best first.
 *
 * The caller walks down this list asking the judge, so the order is the spend:
 * a better ranking is fewer paid calls before an `ok`, not a better outcome.
 */
export function rankDishCandidates(cands, dishName) {
  return cands
    .map((c) => ({ ...c, score: scoreDishCandidate(c, dishName) }))
    .filter((c) => c.score !== null && c.score >= MIN_DISH_SCORE)
    // Ties broken by URL so two runs over the same candidates spend the same.
    .sort((a, b) => b.score - a.score || String(a.url).localeCompare(String(b.url)));
}
