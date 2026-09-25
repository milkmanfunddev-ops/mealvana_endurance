// G21-B seam L2 (Xuan, 2026-09-25 — fork option B): the slot page's
// "Recommended for {slot}" section reads the EXISTING carb_loading_foods
// store via getFoodsByMealType. PRODUCER-SHAPED rows: exactly what the
// shipping sync path writes locally — meal_types as a Postgres array literal
// of NAMES ('{breakfast,lunch}'), the wire shape of the server's text[]
// column — never the app's own enum serialization. Second red: empty store →
// the section renders its empty state, not a crash.
//
// D-022: the S9 one-store unification is the ruled follow-up; when it lands,
// THIS test flips its data source (the resume pointer's named red).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_food_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/meal_type.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_slot_screen.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

String _todayYmd() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  late AppDatabase db;
  late CarbLoadingFoodRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = MockAppLogger();
    when(() => logger.debug(any(),
        context: any(named: 'context'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.warning(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.error(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    repo = CarbLoadingFoodRepository(
      database: db,
      supabase: MockSupabaseClient(),
      logger: logger,
    );
    addTearDown(db.close);
  });

  // The sync path's local write, verbatim shape (carb_loading_food_sync_
  // service: '{${names.join(',')}}' from the server's text[] of names).
  Future<void> seedFood(
    String id,
    String name,
    String displayName,
    double carbs,
    String? mealTypesLiteral,
  ) =>
      db.into(db.carbLoadingFoodsTable).insert(
            CarbLoadingFoodsTableCompanion.insert(
              id: id,
              name: name,
              displayName: displayName,
              carbsPerServing: carbs,
              mealTypes: Value(mealTypesLiteral),
            ),
          );

  Widget host() => ProviderScope(
        overrides: [
          carbLoadingFoodRepositoryProvider.overrideWithValue(repo),
          // No plan needed: card == null renders the slot page in its
          // today posture, which is where the section lives.
          carbDashboardForDateProvider.overrideWith((ref, dateStr) async => null),
        ],
        child: MaterialApp(
          home: CarbSlotScreen(slot: MealType.breakfast, dateStr: _todayYmd()),
        ),
      );

  testWidgets(
      'G21-B: producer-shaped store rows render, suitability-filtered, '
      'fixed curation order', (tester) async {
    // Out-of-curation insertion order on purpose: the section must sort by
    // the store's curation key (name asc), never by arrival order.
    await seedFood('f-cereal', 'cereal', 'Cereal (1/2 cup dry)', 30,
        '{breakfast}');
    await seedFood('f-bagel', 'bagel', 'Bagel with Jam', 55,
        '{breakfast,lunch}');
    await seedFood('f-sports', 'sports_drink', 'Sports Drink, 20 oz', 34,
        '{lunch,afternoon_snack}');
    // Null meal_types = suitable everywhere (the store's shipped tolerance).
    await seedFood('f-juice', 'apple_juice', 'Apple Juice, 12 oz', 42, null);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('carb_slot.recommended_section')),
        findsOneWidget);
    // Suitability: breakfast-tagged + null-tagged render; lunch-only does not.
    expect(find.text('Cereal (1/2 cup dry)'), findsOneWidget);
    expect(find.text('Bagel with Jam'), findsOneWidget);
    expect(find.text('Apple Juice, 12 oz'), findsOneWidget);
    expect(find.text('Sports Drink, 20 oz'), findsNothing);
    // Prototype-verbatim sub copy.
    expect(find.text('55 g carbs per serving'), findsOneWidget);

    // Fixed curation order: name asc → apple_juice, bagel, cereal.
    final ys = [
      for (final id in ['f-juice', 'f-bagel', 'f-cereal'])
        tester
            .getTopLeft(find.byKey(ValueKey('carb_slot.rec_$id')))
            .dy,
    ];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue,
        reason: 'rows render in curation order, not insertion order');

    expect(
        find.byKey(const ValueKey('carb_slot.recommended_empty')),
        findsNothing);
  });

  testWidgets('G21-B: empty store renders the empty state, not a crash',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('carb_slot.recommended_section')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('carb_slot.recommended_empty')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
