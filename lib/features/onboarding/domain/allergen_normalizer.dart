/// One allergen normaliser for every compare between the athlete's allergies
/// (`Allergy.dbValue`: `peanuts`, `tree_nuts`, ...) and a catalog's allergen
/// strings (`Peanut`, `Tree nut`, `Dairy`, ...). Testing-wave ticket 138,
/// Finding 116-001: the exact lower-case compares in the formula filter and
/// the pin-conflict label never matched `Peanut` against `peanuts`.
///
/// Canonical forms are the app's `Allergy.dbValue`s. Aliases fold singular
/// and plural, spacing and a few common names; an unknown token comes back
/// snake_cased so two spellings of the same unknown allergen still match.
library;

const Map<String, String> _aliases = {
  'peanut': 'peanuts',
  'peanuts': 'peanuts',
  'tree_nut': 'tree_nuts',
  'tree_nuts': 'tree_nuts',
  'treenut': 'tree_nuts',
  'treenuts': 'tree_nuts',
  // A catalog "Nuts" is read as tree nuts: hiding more is the safe side.
  'nut': 'tree_nuts',
  'nuts': 'tree_nuts',
  'egg': 'eggs',
  'eggs': 'eggs',
  'dairy': 'dairy',
  'milk': 'dairy',
  'lactose': 'dairy',
  'soy': 'soy',
  'soya': 'soy',
  'soybean': 'soy',
  'soybeans': 'soy',
  'gluten': 'gluten',
  // Wheat carries gluten; a gluten allergy hides it.
  'wheat': 'gluten',
  'fish': 'fish',
  'shellfish': 'shellfish',
  'sesame': 'sesame',
  'sesame_seed': 'sesame',
  'sesame_seeds': 'sesame',
};

/// The canonical form of one allergen string.
String normalizeAllergen(String raw) {
  var token = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'[^a-z_]'), '');
  final direct = _aliases[token];
  if (direct != null) return direct;
  // Unknown allergen: fold a plain plural onto its singular's alias, else
  // return the snake_cased token so equal spellings still meet.
  if (token.endsWith('s')) {
    final singular = token.substring(0, token.length - 1);
    final viaSingular = _aliases[singular];
    if (viaSingular != null) return viaSingular;
    token = singular;
  }
  return token;
}

/// The canonical set of many allergen strings.
Set<String> normalizeAllergens(Iterable<String> raw) =>
    raw.map(normalizeAllergen).toSet();

/// Whether any of [templateAllergens] names one of [athleteAllergies].
bool allergensConflict(
  Iterable<String> templateAllergens,
  Iterable<String> athleteAllergies,
) {
  final athlete = normalizeAllergens(athleteAllergies);
  if (athlete.isEmpty) return false;
  return templateAllergens.any((a) => athlete.contains(normalizeAllergen(a)));
}
