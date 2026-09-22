/// A lapsed account cannot write a race checklist (mp-457 §4, mp-491,
/// ticket 12).
///
/// Through the real ChecklistController: each write path asks the write
/// guard first; refused, it opens the paywall once and never constructs the
/// repository or the services, so nothing is written or queued.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/race_checklist/data/checklist_repository.dart';
import 'package:mealvana_endurance/features/race_checklist/domain/checklist_item.dart';
import 'package:mealvana_endurance/features/race_checklist/presentation/providers/checklist_controller.dart';

import '../../helpers/write_access.dart';

class _Seeded extends ChecklistController {
  @override
  Future<List<ChecklistItem>> build(String eventId) async => const [];
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;
  final provider = checklistControllerProvider('e1');

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        checklistRepositoryProvider.overrideWith(
          untouched('checklistRepository'),
        ),
        eventsServiceProvider.overrideWith(untouched('eventsService')),
        gearTemplateServiceProvider.overrideWith(
          untouched('gearTemplateService'),
        ),
        userRepositoryProvider.overrideWith(untouched('userRepository')),
        checklistControllerProvider.overrideWith(_Seeded.new),
      ],
    );
    addTearDown(container.dispose);
  });

  ChecklistController ctrl() => container.read(provider.notifier);
  final paths = <String, Future<Object?> Function()>{
    'toggleItem': () => ctrl().toggleItem('i1', true),
    'addCustomItem': () => ctrl().addCustomItem('Salt tabs'),
    'deleteItem': () => ctrl().deleteItem('i1'),
    'regenerateChecklist': () => ctrl().regenerateChecklist(),
  };
  for (final entry in paths.entries) {
    test('lapsed: ${entry.key} opens the paywall and writes nothing', () async {
      await container.read(provider.future);
      await expectWriteRefused(opens, entry.value);
      expect(container.read(provider).value, isEmpty);
    });
  }
}
