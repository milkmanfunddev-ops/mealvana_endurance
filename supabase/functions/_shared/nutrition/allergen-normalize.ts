/**
 * One allergen normaliser for every compare between an athlete's allergies
 * (`users.allergies`: `peanuts`, `tree_nuts`, ...) and a catalog's allergen
 * strings (`Peanut`, `Tree nut`, `Dairy`, ...).
 *
 * Testing-wave ticket 138, Finding 116-001: the solvers compared
 * `a.toLowerCase()` on both sides, so a `peanuts` allergy never matched a
 * template tagged `Peanut`. Dart twin:
 * `lib/features/onboarding/domain/allergen_normalizer.dart` (same aliases,
 * same canonical forms: the app's `Allergy.dbValue`s).
 */

const ALIASES: Record<string, string> = {
  peanut: "peanuts",
  peanuts: "peanuts",
  tree_nut: "tree_nuts",
  tree_nuts: "tree_nuts",
  treenut: "tree_nuts",
  treenuts: "tree_nuts",
  // A catalog "Nuts" is read as tree nuts: hiding more is the safe side.
  nut: "tree_nuts",
  nuts: "tree_nuts",
  egg: "eggs",
  eggs: "eggs",
  dairy: "dairy",
  milk: "dairy",
  lactose: "dairy",
  soy: "soy",
  soya: "soy",
  soybean: "soy",
  soybeans: "soy",
  gluten: "gluten",
  // Wheat carries gluten; a gluten allergy hides it.
  wheat: "gluten",
  fish: "fish",
  shellfish: "shellfish",
  sesame: "sesame",
  sesame_seed: "sesame",
  sesame_seeds: "sesame",
};

/** The canonical form of one allergen string. */
export function normalizeAllergen(raw: string): string {
  let token = raw
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_")
    .replace(/[^a-z_]/g, "");
  const direct = ALIASES[token];
  if (direct !== undefined) return direct;
  if (token.endsWith("s")) {
    const singular = token.slice(0, -1);
    const viaSingular = ALIASES[singular];
    if (viaSingular !== undefined) return viaSingular;
    token = singular;
  }
  return token;
}

/** The canonical set of many allergen strings. */
export function normalizeAllergens(raw: Iterable<string>): Set<string> {
  return new Set(Array.from(raw, normalizeAllergen));
}

/** Whether any of `templateAllergens` names one of `athleteAllergies`. */
export function allergensConflict(
  templateAllergens: Iterable<string>,
  athleteAllergies: Iterable<string>,
): boolean {
  const athlete = normalizeAllergens(athleteAllergies);
  if (athlete.size === 0) return false;
  for (const a of templateAllergens) {
    if (athlete.has(normalizeAllergen(a))) return true;
  }
  return false;
}
