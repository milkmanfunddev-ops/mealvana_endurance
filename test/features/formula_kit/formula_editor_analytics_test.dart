/// Unit tests for the Formula Kit editor component-mutation analytics added
/// by the analytics workstream (2026-07). Verifies the editor controller
/// fires formula_editor_component_added / _swapped / _removed with the
/// post-mutation draft shape, counts quantity edits without firing per tick,
/// and that invalid indices fire nothing.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_editor_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

const _food = Food(
  id: 'food-1',
  name: 'Banana',
  carbsPerServing: 27,
  caloriesPerServing: 105,
);

void main() {
  late RecordingAnalyticsTracker analytics;
  late ProviderContainer container;

  setUp(() {
    analytics = RecordingAnalyticsTracker();
    final userRepo = _MockUserRepository();
    when(() => userRepo.getCurrentUser()).thenAnswer((_) async => null);

    container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWith((ref) async => userRepo),
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: _MockSupabaseClient(),
          sentry: _MockSentryReporter(),
          logger: _MockAppLogger(),
          sharedPreferences: _MockSharedPreferences(),
        ),
      ),
    ]);
    addTearDown(container.dispose);
  });

  Future<FormulaEditorController> createEditor() async {
    final provider =
        formulaEditorControllerProvider(null, FormulaPhase.during);
    await container.read(provider.future);
    return container.read(provider.notifier);
  }

  group('formula editor component analytics', () {
    test('addComponent fires formula_editor_component_added with post-op '
        'shape', () async {
      final editor = await createEditor();

      editor.addComponent(_food, 2, isUserFood: false);
      await Future<void>.delayed(Duration.zero);

      final events = analytics.findEvents('formula_editor_component_added');
      expect(events.length, 1);
      final props = events.single.properties!;
      expect(props['phase'], 'during');
      expect(props['is_new_formula'], isTrue);
      expect(props['component_count'], 1);
      expect(props['is_user_food'], isFalse);
    });

    test('replaceComponent fires formula_editor_component_swapped', () async {
      final editor = await createEditor();
      editor.addComponent(_food, 1, isUserFood: false);

      editor.replaceComponent(0, _food, 3, isUserFood: true);
      await Future<void>.delayed(Duration.zero);

      final events = analytics.findEvents('formula_editor_component_swapped');
      expect(events.length, 1);
      final props = events.single.properties!;
      expect(props['component_count'], 1);
      expect(props['is_user_food'], isTrue);
    });

    test('removeComponent fires formula_editor_component_removed', () async {
      final editor = await createEditor();
      editor.addComponent(_food, 1, isUserFood: false);

      editor.removeComponent(0);
      await Future<void>.delayed(Duration.zero);

      final events = analytics.findEvents('formula_editor_component_removed');
      expect(events.length, 1);
      expect(events.single.properties!['component_count'], 0);
    });

    test('invalid indices fire nothing', () async {
      final editor = await createEditor();

      editor.replaceComponent(5, _food, 1, isUserFood: false);
      editor.removeComponent(-1);
      editor.updateComponentQuantity(9, 2);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.events, isEmpty);
    });

    test('quantity edits fire no per-tick events', () async {
      final editor = await createEditor();
      editor.addComponent(_food, 1, isUserFood: false);
      analytics.clear();

      editor.updateComponentQuantity(0, 2);
      editor.updateComponentQuantity(0, 3);
      editor.updateComponentQuantity(0, 4);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.events, isEmpty);
    });
  });
}
