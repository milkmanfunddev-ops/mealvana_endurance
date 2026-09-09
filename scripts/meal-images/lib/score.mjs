// Relevance scoring for candidate ingredient photos.
// Fully-automatic selection means this file is the only thing standing between
// the library and "rolled oats under a microscope", so it rejects hard.

// Contexts that are technically the right subject but wrong for a food tile.
const NEGATIVE = [
  [/microscope|micrograph|magnif|cross[- ]section|anatomy|diagram|chart|graph|infographic/, -80],
  [/\bmap\b|logo|signage|\bsign\b|billboard|poster|banner|label|packaging|package|carton|wrapper|barcode/, -60],
  [/factory|plantation|harvest|farm|field|crop|orchard|greenhouse|nursery|seedling|sapling|growing|cultivat/, -50],
  // Commons indexes the BOTANICAL organism: "sweet potato" surfaces the
  // Ipomoea flower, "olive oil" the mill. Food tiles must never show the plant.
  [/flower|blossom|bloom|petal|stamen|pollen|inflorescen|foliage|leaves|leaf\b|vine|shrub|\btree\b|branch|root system|tuber\b|bulb\b|stalk|sprouting/, -95],
  [/mill|press|refinery|distiller|silo|machinery|equipment|industrial|laboratory|\btank\b/, -70],
  [/botanic|herbarium|specimen|taxonom|species|genus|illustration|engraving|lithograph|painting|drawing|sketch|artwork|\bart\b/, -50],
  [/portrait|man\b|woman\b|child|people|person|crowd|worker|farmer|chef holding|selfie/, -35],
  [/museum|monument|statue|church|building|street|shop|store|market stall|restaurant exterior/, -35],
  [/coin|stamp|banknote|flag|book cover|screenshot|\bicon\b|clipart|vector/, -60],
  // Tail failures seen on 2026-09-08: "vegan yogurt" -> a Silk carton,
  // "fusilli" -> bare hands on a table. Brand packaging and empty scenes both
  // score well on the words and show nothing edible.
  [/\bbrand\b|supermarket|grocery|aisle|shelf|product shot|bottle of|\bbox of\b|\btub\b|\bcan\b|tetra|container/, -55],
  [/hand|hands|holding|table\b|kitchen|counter|cutting board|utensil|spoon|fork|knife/, -25],
  [/dog|cat|bird|animal feed|livestock|pet food/, -50],
  [/mold|mould|rotten|spoiled|decay|pest|disease|insect/, -70],
  [/nutrition facts|ingredient list|recipe card|text\b/, -40],
  [/wine glass|cocktail|beer|liquor|whisky|wine\b/, -45],
];

// What makes a good INGREDIENT tile: the subject alone, clearly readable at
// 150px. This is the opposite of what makes a good finished-dish photo, and
// getting it backwards is what produced spinach -> spinach pastry and
// tofu -> a plated meat-looking dish.
const POSITIVE = [
  [/isolated|white background|plain background|studio|cut ?out|on white/, 34],
  [/close[- ]?up|closeup|macro|detail|texture/, 12],
  [/fresh|raw|ripe|whole|pile|heap|bunch|handful|scattered|pieces|slices/, 18],
  [/\bbowl of\b|\bjar of\b|\bcup of\b|\bglass of\b/, 10],
];

// Markers of a composed, finished dish. Correct for a hero photo of a meal,
// wrong for a tile that must read as one ingredient.
const COMPOSED = [
  /\bserved\b|serving|garnish|plated|\bplatter\b|topped with|drizzled|sauce\b/,
  /recipe|casserole|bake\b|roast\b|stew|curry|soup\b|salad\b|sandwich|wrap\b|pastry|pie\b|roll\b|bread\b/,
  /breakfast|lunch|dinner|\bmeal\b|\bdish\b|cuisine|restaurant/,
];

const clean = (s) => String(s || '').toLowerCase().replace(/[_\-]+/g, ' ').replace(/\s+/g, ' ').trim();

/**
 * Score one candidate against the ingredient it is meant to depict.
 * Returns null when the candidate must not be used at all.
 */
export function scoreCandidate(cand, ingredient) {
  const title = clean(cand.title);
  const terms = clean(ingredient).split(' ').filter((t) => t.length > 2);
  if (!terms.length) return null;

  // EVERY word of the ingredient must appear. Partial coverage is what lets
  // "black bean" match "roasted coffee beans" and "white rice" match a rice
  // drink: the head noun alone is not the subject.
  const hits = terms.filter((t) => title.includes(t)).length;
  if (hits < terms.length) return null;

  let score = 100;
  // The whole phrase adjacent ("black bean", not "black pepper and beans")
  // is a materially better match than the words merely co-occurring.
  if (title.includes(clean(ingredient))) score += 30;

  for (const [re, w] of NEGATIVE) if (re.test(title)) score += w;
  for (const [re, w] of POSITIVE) if (re.test(title)) score += w;
  // Each composed-dish signal pushes the candidate further from "one ingredient".
  for (const re of COMPOSED) if (re.test(title)) score -= 22;

  const w = cand.width || 0, h = cand.height || 0;
  if (w && h) {
    if (w < 320 || h < 320) score -= 40;              // too small to crop
    const ar = w / h;
    if (ar > 2.4 || ar < 0.42) score -= 35;           // panorama / column crops badly
    if (ar > 0.75 && ar < 1.4) score += 12;           // near-square tiles best
  }

  // Stylistic consistency: stock food photography beats archival Commons shots.
  score += { unsplash: 26, pexels: 22, wikimedia: 6, openverse: 0 }[cand.provider] ?? 0;

  // A shorter title naming the subject is usually a cleaner subject shot.
  if (title.split(' ').length <= 5) score += 8;
  if (title.split(' ').length > 14) score -= 12;

  // Subject purity. Stock alt-text is descriptive, so a title that leads with
  // the ingredient ("Fresh spinach on white") is a tile; one that buries it in
  // a list ("tomatoes, boiled eggs, herbs and bread") is a composed scene and
  // reads as the wrong food at 150px.
  const head = title.replace(/^(a|an|the|fresh|raw|close[- ]?up of|closeup of|top view of|flat lay of)\s+/g, '');
  if (head.startsWith(terms[0])) score += 20;
  const others = (title.match(/,/g) || []).length + (title.match(/\band\b/g) || []).length;
  score -= Math.min(others, 4) * 14;
  if (/\b(with|featuring|served with|topped with|alongside)\b/.test(title)) score -= 10;

  return score;
}

export const MIN_SCORE = 55;

/**
 * The bar for low-frequency ingredients.
 *
 * A wrong photo is worse than no photo (Lee, 2026-09-08), and the long tail is
 * exactly where the free archives return something that merely shares a word.
 * Rare ingredients must clear a higher bar or get no tile at all.
 */
export const TAIL_MIN_SCORE = 105;

/** All acceptable candidates, best first, so callers can fall down the list
 *  when a higher-ranked one turns out to be undownloadable or too small. */
export function rankCandidates(cands, ingredient) {
  return cands
    .map((c) => ({ ...c, score: scoreCandidate(c, ingredient) }))
    .filter((c) => c.score !== null && c.score >= MIN_SCORE)
    .sort((a, b) => b.score - a.score);
}

export function pickBest(cands, ingredient) {
  return rankCandidates(cands, ingredient)[0] ?? null;
}
