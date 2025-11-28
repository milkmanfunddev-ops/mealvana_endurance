import '../logging_service.dart';

// Mapping of legacy product_type_id UUIDs to the current product_type enum codes
const Map<String, String> _legacyProductTypeIdToEnum = {
  '8a847f4f-8c26-41ef-a1e2-132b404be95e': 'gel',
  'fc915f1b-d541-45fa-ae5c-695ee41073db': 'chew',
  'd3908cb2-a21d-4ef1-8d33-c999d29eefcc': 'drink_mix',
  '09930546-1942-485e-9728-bced1cf933a2': 'electrolyte_only',
  'b27bc986-1402-4e20-b022-a65b5ffbd4d2': 'sports_drink',
  '6102eea1-2dfe-44cf-8863-b258c27262ef': 'bar',
  '666408c5-6d5b-4fc6-bda3-d6428e8362b9': 'waffle',
  '52a0ff7c-a0f5-4e26-b409-2a7ce3298f4d': 'capsule',
  '76c16c67-1746-47d7-adea-e5fc9dcd1f4d': 'real_food',
  'cbcfd036-127c-43fb-88d5-34a9d9ba5db4': 'recovery_shake',
  '3b5d6f2e-3d3a-4b6a-9e3b-5c7a1f0d7a10': 'quick_carbs',
  '8f4f2c73-9a65-4d5a-b3be-9d5f9e2a1c2d': 'solid_carb_snacks',
  'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1': 'real_food_carbs',
  'c7e2a1d4-5b6c-4f9d-8e2a-1a7c9b3e5d2f': 'hydration_with_carbs',
  'a1e2c3d4-b5a6-4c7d-8e9f-0a1b2c3d4e5f': 'electrolytes_fluids',
  'd4c3b2a1-6e5d-4c3b-8a9f-1e2d3c4b5a6f': 'protein_recovery',
  'cdd6a8f1-750c-4c78-93f7-ab706285ac7b': 'import',
};

final _uuidPattern = RegExp(r'^[0-9a-fA-F-]{36}$');

/// Convert legacy product_type_id values to the new product_type enum codes.
/// Returns null when we can't confidently map the value to avoid enum errors upstream.
String? normalizeProductType(
  dynamic rawValue, {
  AppLogger? logger,
}) {
  final value = rawValue?.toString();
  if (value == null || value.isEmpty) return null;

  final mapped = _legacyProductTypeIdToEnum[value];
  if (mapped != null) return mapped;

  // If it's not a UUID, assume it's already an enum code
  if (!_uuidPattern.hasMatch(value)) return value;

  // Unknown legacy UUID - drop it to keep sync/upload from failing
  logger?.warning(
    'Dropping unmapped legacy product_type_id',
    context: 'ProductTypeMapper',
    data: {'productTypeId': value},
  );
  return null;
}
