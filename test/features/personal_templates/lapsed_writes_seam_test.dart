/// A lapsed account cannot write personal templates (mp-457 §4, mp-491,
/// ticket 12).
///
/// Through the real PersonalTemplatesController: each write path asks the
/// write guard first; refused, it opens the paywall once and never
/// constructs the repository, so nothing is written or queued.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/personal_templates/data/personal_templates_repository.dart';
import 'package:mealvana_endurance/features/personal_templates/domain/personal_template.dart';
import 'package:mealvana_endurance/features/personal_templates/presentation/providers/personal_templates_controller.dart';

import '../../helpers/write_access.dart';

class _FakeActivity extends Fake implements Activity {}

class _FakePlan extends Fake implements NutritionPlan {}

class _Seeded extends PersonalTemplatesController {
  @override
  FutureOr<List<PersonalTemplate>> build() => const [];
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        personalTemplatesRepositoryProvider.overrideWith(
          untouched('personalTemplatesRepository'),
        ),
        personalTemplatesControllerProvider.overrideWith(_Seeded.new),
      ],
    );
    addTearDown(container.dispose);
  });

  PersonalTemplatesController ctrl() =>
      container.read(personalTemplatesControllerProvider.notifier);
  final paths = <String, Future<Object?> Function()>{
    'saveTemplate': () => ctrl().saveTemplate(
      activity: _FakeActivity(),
      nutritionPlan: _FakePlan(),
      templateName: 'Long run',
    ),
    'renameTemplate': () => ctrl().renameTemplate('t1', 'Longer run'),
    'deleteTemplate': () => ctrl().deleteTemplate('t1'),
  };
  for (final entry in paths.entries) {
    test('lapsed: ${entry.key} opens the paywall and writes nothing', () async {
      await expectWriteRefused(opens, entry.value);
      expect(
        container.read(personalTemplatesControllerProvider).value,
        isEmpty,
      );
    });
  }
}
