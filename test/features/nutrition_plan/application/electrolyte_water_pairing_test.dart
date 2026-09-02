import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/electrolyte_water_pairing.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_food.dart';

/// Dart mirror of
/// `supabase/functions/_shared/nutrition/electrolyte-water-pairing.test.ts`.
/// Product rule: an electrolyte item is never recommended alone — water
/// always goes with it.

FoodItemData item({
  String id = 'gel',
  String name = 'Energy Gel',
  double carbs = 25,
  double sodium = 0,
  double fluids = 0,
  bool isDrink = false,
  TimingCategory category = TimingCategory.quickConsume,
}) {
  return FoodItemData(
    id: id,
    name: name,
    quantity: '1',
    nutritionalInfo: NutritionalInfo(
      calories: 100,
      carbs: carbs.round(),
      sodium: sodium.round(),
      fluids: fluids,
    ),
    isDrink: isDrink,
    timingCategory: category,
  );
}

/// A dry electrolyte tablet: sodium, zero fluid of its own.
FoodItemData electrolyteTablet() => item(
  id: 'salt-tab',
  name: 'Electrolyte Tablet',
  carbs: 0,
  sodium: 300,
  fluids: 0,
  category: TimingCategory.electrolyte,
);

SolverFood waterFood({double fluidMl = 240, int maxServings = 10}) =>
    SolverFood(
      id: 'water',
      name: 'water',
      displayName: 'Water',
      carbsG: 0,
      proteinG: 0,
      fatG: 0,
      sodiumMg: 0,
      fluidMl: fluidMl,
      calories: 0,
      maxServings: maxServings,
      preferenceScore: 50,
      isEssential: true,
      // The essential water row is not reliably flagged is_liquid — the pass
      // must not depend on it.
      isLiquid: false,
    );

double totalFluid(List<FoodItemData> items) =>
    items.fold(0.0, (s, i) => s + (i.nutritionalInfo?.fluids ?? 0));

void main() {
  final pool = [waterFood()];

  group('detection', () {
    test('keys off timingCategory, not display names', () {
      expect(isElectrolyteItem(electrolyteTablet()), isTrue);
      expect(isElectrolyteItem(item()), isFalse);
      // Named like an electrolyte but categorised as a gel — not matched.
      expect(isElectrolyteItem(item(name: 'Electrolyte Drink Mix')), isFalse);
    });

    test('water locked in solid food is not drinkable fluid', () {
      expect(deliversDrinkableFluid(item(fluids: 88)), isFalse);
      expect(deliversDrinkableFluid(item(fluids: 500, isDrink: true)), isTrue);
    });
  });

  group('core invariant', () {
    test('electrolyte alone gets water added', () {
      final items = [item(), electrolyteTablet()];
      expect(needsWaterPairing(items), isTrue);

      final res = ensureElectrolyteWaterPairing(items, pool);

      expect(res.changed, isTrue);
      expect(res.conflict, isNull);
      expect(res.items.length, 3);
      expect(res.items.last.id, 'water');
      expect(res.items.last.isDrink, isTrue);
      expect(res.items.last.timingCategory, TimingCategory.sipThroughout);
      expect(
        totalFluid(res.items),
        greaterThanOrEqualTo(kDefaultPairingVolumeMl),
      );
      expect(needsWaterPairing(res.items), isFalse);
    });

    test('whole-food water does not satisfy the pairing', () {
      // A banana's 88ml is not something you take a tablet with.
      final items = [
        item(id: 'banana', name: 'Banana', fluids: 88),
        electrolyteTablet(),
      ];
      final res = ensureElectrolyteWaterPairing(items, pool);
      expect(res.changed, isTrue);
      expect(res.items.any((i) => i.id == 'water'), isTrue);
    });

    test('electrolyte carrying its own water is NOT re-paired', () {
      // Adding more water here would double-count the phase's fluid.
      final mix = item(
        id: 'drink-mix',
        name: 'Electrolyte Drink Mix',
        carbs: 0,
        sodium: 400,
        fluids: 500,
        isDrink: true,
        category: TimingCategory.electrolyte,
      );
      final items = [item(), mix];

      expect(needsWaterPairing(items), isFalse);
      final res = ensureElectrolyteWaterPairing(items, pool);

      expect(res.changed, isFalse);
      expect(res.items.length, 2);
      expect(totalFluid(res.items), 500);
    });

    test('a dry tablet next to a sports drink needs nothing extra', () {
      final items = [
        item(id: 'sports-drink', fluids: 600, isDrink: true),
        electrolyteTablet(),
      ];
      expect(needsWaterPairing(items), isFalse);
      expect(ensureElectrolyteWaterPairing(items, pool).changed, isFalse);
    });

    test('no electrolyte present is a no-op', () {
      final items = [item(), item(id: 'bar', carbs: 40)];
      expect(needsWaterPairing(items), isFalse);
      expect(ensureElectrolyteWaterPairing(items, pool).changed, isFalse);
    });
  });

  group('fluid ceiling', () {
    test('pairing never breaches the fluid ceiling', () {
      // 900ml already used, ceiling 950ml — even half a 240ml serving is over.
      final items = [
        item(id: 'melon', carbs: 30, fluids: 900),
        electrolyteTablet(),
      ];
      final res = ensureElectrolyteWaterPairing(
        items,
        pool,
        fluidCeilingMl: 950,
      );

      expect(res.changed, isFalse);
      expect(res.conflict, ElectrolytePairingConflict.fluidCeiling);
      expect(totalFluid(res.items), 900);
    });

    test('pairing fits inside available headroom', () {
      final items = [
        item(id: 'melon', carbs: 30, fluids: 900),
        electrolyteTablet(),
      ];
      final res = ensureElectrolyteWaterPairing(
        items,
        pool,
        fluidCeilingMl: 1100,
      );

      expect(res.changed, isTrue);
      expect(res.conflict, isNull);
      expect(totalFluid(res.items), lessThanOrEqualTo(1100));
      expect(totalFluid(res.items), greaterThan(900));
    });

    test('no water source reports an honest conflict', () {
      final res = ensureElectrolyteWaterPairing([
        item(),
        electrolyteTablet(),
      ], const []);
      expect(res.changed, isFalse);
      expect(res.conflict, ElectrolytePairingConflict.noWaterSource);
      expect(res.items.length, 2);
    });
  });

  group('idempotency', () {
    test('running the pass twice does not add water twice', () {
      final items = [item(), electrolyteTablet()];

      final once = ensureElectrolyteWaterPairing(items, pool);
      final twice = ensureElectrolyteWaterPairing(once.items, pool);
      final thrice = ensureElectrolyteWaterPairing(twice.items, pool);

      expect(once.changed, isTrue);
      expect(twice.changed, isFalse);
      expect(thrice.changed, isFalse);
      expect(thrice.items.length, once.items.length);
      expect(totalFluid(thrice.items), totalFluid(once.items));
      expect(thrice.items.where((i) => i.id == 'water').length, 1);
    });

    test('input list is never mutated', () {
      final items = [item(), electrolyteTablet()];
      ensureElectrolyteWaterPairing(items, pool);
      expect(items.length, 2);
    });
  });

  // C2 scope extension — docs/ssot/spec/domain/catalog-conventions.md
  // (RULED Xuan 2026-09-01): every DRY requires-water item is covered, not
  // only electrolyte-flagged ones. With the C1 catalog zeros a carb drink
  // mix row is dry — nobody chews drink mix. Twin of the TS C2 tests.
  group('C2 — dry requires-water scope', () {
    test('a dry carb drink mix (no electrolyte flags) gets water', () {
      final dryMix = item(
        id: 'carb-mix',
        name: 'Carb Drink Mix',
        carbs: 45,
        fluids: 0, // C1: dry as catalogued
        category: TimingCategory.fuelDrink,
      );
      expect(needsWaterPairing([dryMix]), isTrue);
      final res = ensureElectrolyteWaterPairing([dryMix], pool);
      expect(res.changed, isTrue);
      expect(res.items.any(deliversDrinkableFluid), isTrue);
    });

    test('a hydrated sports drink is self-satisfying (no double count)', () {
      final mixed = item(
        id: 'sports-drink',
        name: 'Sports Drink',
        carbs: 30,
        fluids: 500,
        isDrink: true,
        category: TimingCategory.fuelDrink,
      );
      expect(ensureElectrolyteWaterPairing([mixed], pool).changed, isFalse);
    });

    test('a plain solid food stays outside the pairing scope', () {
      final banana = item(
        id: 'banana',
        name: 'Banana',
        carbs: 27,
        fluids: 0,
        category: TimingCategory.slowConsume,
      );
      expect(unpairedElectrolyteItems([banana]), isEmpty);
      expect(needsWaterPairing([banana]), isFalse);
    });
  });
}
