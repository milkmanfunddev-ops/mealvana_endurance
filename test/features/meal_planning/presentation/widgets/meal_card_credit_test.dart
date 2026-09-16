import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_card.dart';

import '../helpers/test_content.dart';

/// A card's thumbnail is too small for a credit line, so the credit rides on
/// its semantics instead. The visible line lives on the recipe screen. A photo
/// with no credit announces none — no empty label (ADR 0003, story 15).
void main() {
  MealRef meal(Map<String, dynamic> photo, {String name = 'Avocado toast'}) =>
      MealLibraryRemoteDataSource.rowToMealRef({
        'source': 'library',
        'id': 'AB-001',
        'name': name,
        'meal_type': 'breakfast',
        ...photo,
      })!;

  final credited = meal({
    'photo_url': 'https://upload.wikimedia.org/avocado.jpg',
    'photo_credit': 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
    'photo_credit_url': 'https://commons.wikimedia.org/wiki/File:Avocado.jpg',
  });

  final ours = meal({
    'photo_url': 'https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/object/'
        'public/meal-images/photos/AB-002.jpg',
  }, name: 'Steel-cut oats with peanut butter');

  Future<void> pump(WidgetTester tester, List<MealRef> meals) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in meals)
                  MealCard(meal: m, onTap: () {}, trailing: const Text('Add')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a Dish photo carries its credit line for screen readers, and '
      'shows none on the card', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, [credited]);

    expect(
      find.bySemanticsLabel(
        RegExp('Photo by Jami430 on Wikimedia Commons'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Photo by'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a photo with no credit announces none', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, [ours]);

    expect(find.bySemanticsLabel(RegExp('Photo by')), findsNothing);
    final label = tester
        .getSemantics(find.text('Steel-cut oats with peanut butter'))
        .label;
    expect(label, isNot(contains('Photo')));
    semantics.dispose();
  });

  testWidgets('the list lays out at the smallest supported width', (
    tester,
  ) async {
    await pump(tester, [credited, ours, credited]);

    expect(tester.takeException(), isNull);
    expect(find.byType(MealCard), findsNWidgets(3));
    expect(tester.getSize(find.byType(MealCard).first).width, 320 - 32);
  });
}
