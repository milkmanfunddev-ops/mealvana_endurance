// What to type into a stock-photo search when you want a photograph of the
// finished dish.
//
// The tile bank searches by ingredient, and `providers.queryVariants` adds the
// food context a bare ingredient word needs ("chicken" is otherwise a live
// bird). A dish is the opposite problem. The name is already specific — the
// trouble is that it is specific about things no photographer ever tagged:
//
//   "Butternut squash \"mac & cheese\" (GF pasta, dairy-free)"
//   "Banana-oat pancakes, egg-free"
//   "Scott Jurek's blueberry smoothie"
//
// Searched verbatim these return nothing at all, and nothing is indistinguishable
// from "no photograph of this dish exists". So a name is cleaned down to the
// dish, then shortened a step at a time until a search answers.
//
// Ranking still scores candidate titles against `plainDishName`, so shortening
// the query widens the search without loosening the match — the same division
// the ingredient path uses.
//
// Pure: no network, no database, no model. Tested in `dish-query.test.mjs`.

/** Words that describe who may eat a dish, not what it looks like. */
const QUALIFIERS = new Set([
  'gluten-free', 'dairy-free', 'egg-free', 'nut-free', 'soy-free', 'lactose-free',
  'grain-free', 'low-fodmap', 'gf', 'df', 'vegan', 'vegetarian', 'paleo', 'keto',
  'rest-day', 'leftover', 'portion',
]);

/**
 * A leading personal name in the possessive: "Scott Jurek's blueberry smoothie".
 *
 * Two or more capitalised words, the last possessive. One word is not enough —
 * "Shepherd's pie" IS the dish, and dropping it leaves "pie".
 */
const PERSON_POSSESSIVE = /^(?:[A-Z][\p{L}.'-]*\s+)+[A-Z][\p{L}.-]*'s\s+/u;

/** Where the dish stops and its accompaniment starts. */
const ACCOMPANIMENT = /\s+(?:with|over|on|topped\s+with|and\s+a)\s+.+$/i;

/**
 * The meal's name with the things a photographer never tagged removed: the
 * parenthetical, the scare quotes, the diet list, the athlete it belongs to.
 *
 * This is what candidate titles are scored against, so it stays a description
 * of the food rather than becoming a search term.
 */
export function plainDishName(name) {
  let s = String(name ?? '')
    .replace(/\([^)]*\)/g, ' ')      // (GF pasta, dairy-free)
    .replace(/\[[^\]]*\]/g, ' ')
    .replace(/["“”]/g, '')           // "mac & cheese" — keep the words
    .replace(/\s*&\s*/g, ' and ')
    .replace(/\s+/g, ' ')
    .trim();

  s = s.replace(PERSON_POSSESSIVE, '');

  // Trailing qualifier segments, innermost first: "pancakes, egg-free, vegan".
  for (;;) {
    const cut = s.replace(/,\s*([^,]+)$/, (whole, tail) => (allQualifiers(tail) ? '' : whole));
    if (cut === s) break;
    s = cut;
  }

  return s.replace(/\s+/g, ' ').replace(/[\s,]+$/, '').trim();
}

function allQualifiers(segment) {
  const words = segment.toLowerCase().split(/[\s,]+/).filter(Boolean);
  return words.length > 0 && words.every((w) => QUALIFIERS.has(w));
}

/**
 * Searches to try for one dish, most specific first.
 *
 * Each step gives up something: the accompaniment, then everything after the
 * first comma, and finally the pretence that a stock library indexes this dish
 * at all — the last query asks for a recipe photograph of whatever is left.
 *
 * @returns {string[]} distinct queries; empty when the name says nothing about food
 */
export function dishQueryVariants(name) {
  const base = plainDishName(name);
  if (base.length < 3) return [];

  const shorter = [base];
  const push = (s) => {
    const v = s.replace(/[\s,]+$/, '').trim();
    if (v.length >= 3 && !shorter.includes(v)) shorter.push(v);
  };

  push(base.replace(ACCOMPANIMENT, ''));
  push(base.split(',')[0]);

  const shortest = shorter.reduce((a, b) => (b.length < a.length ? b : a));
  return [...shorter, `${shortest} recipe`];
}
