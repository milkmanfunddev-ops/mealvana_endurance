import 'product_type_mapper.dart';

/// Endurance-fuel `product_type` codes. Everything NOT in this set (notably
/// `real_food` and `import`) is treated as general food.
///
/// This is the single source of truth for the endurance-vs-general separation
/// (audit §3): fuel types surface in plan add/swap; general food surfaces in
/// meal-logging Discover. Kept as a whitelist so a new general type never
/// leaks into fuel-only surfaces by default.
const Set<String> kFuelProductTypeCodes = {
  'gel',
  'chew',
  'drink_mix',
  'bar',
  'waffle',
  'sports_drink',
  'electrolyte_only',
  'electrolytes_fluids',
  'hydration_with_carbs',
  'quick_carbs',
  'solid_carb_snacks',
  'real_food_carbs',
  'recovery_shake',
  'protein_recovery',
  'capsule',
};

/// True when [productTypeIdOrCode] identifies an endurance fuel product.
///
/// Accepts either a legacy `product_type_id` UUID or an enum code — both are
/// normalized via [normalizeProductType] first. Null / unknown / unclassified
/// values are treated as **general** (not fuel), so a fuel-only surface never
/// shows an unclassified item by accident.
bool isFuelProductType(String? productTypeIdOrCode) {
  final code = normalizeProductType(productTypeIdOrCode);
  if (code == null) return false;
  return kFuelProductTypeCodes.contains(code);
}
