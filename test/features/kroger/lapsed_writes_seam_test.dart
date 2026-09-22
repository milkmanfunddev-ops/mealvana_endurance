/// A lapsed account cannot build or send a Kroger order (mp-457 §4, mp-491,
/// ticket 12).
///
/// Through the real KrogerController: each edit of the order draft, the
/// account link and the export ask the write guard first; refused, they
/// open the paywall once and never construct the repository or the shopping
/// list, so nothing is written locally or sent to Kroger. Reads (refresh,
/// loadCloud, search) and the hand-off to the Kroger app stay open.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_controller.dart';
import 'package:mealvana_endurance/features/kroger/data/kroger_repository.dart';
import 'package:mealvana_endurance/features/kroger/domain/kroger_models.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';

import '../../helpers/write_access.dart';

class _FakeState extends Fake implements KrogerState {}

class _Seeded extends KrogerController {
  @override
  Future<KrogerState> build(String planId) async => _FakeState();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;
  final provider = krogerControllerProvider('p1');

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        krogerRepositoryProvider.overrideWith(untouched('krogerRepository')),
        shoppingListControllerProvider.overrideWith(
          () => throw StateError('shoppingList was touched by a refused write'),
        ),
        krogerControllerProvider.overrideWith(_Seeded.new),
      ],
    );
    addTearDown(container.dispose);
  });

  KrogerController ctrl() => container.read(provider.notifier);
  const product = KrogerProduct(upc: '0001', name: 'Rice');
  final paths = <String, Future<Object?> Function()>{
    'setArea': () => ctrl().setArea('30301'),
    'connect': () => ctrl().connect(),
    'disconnect': () => ctrl().disconnect(),
    'matchAll': () => ctrl().matchAll(),
    'choose': () => ctrl().choose('l1', product),
    'approve': () => ctrl().approve('l1'),
    'approveAll': () => ctrl().approveAll(),
    'quantity': () => ctrl().quantity('l1', 2),
    'exclude': () => ctrl().exclude('l1', true),
    'addManual': () => ctrl().addManual('rice'),
    'export': () => ctrl().export(),
  };
  for (final entry in paths.entries) {
    test('lapsed: ${entry.key} opens the paywall and writes nothing', () async {
      await container.read(provider.future);
      await expectWriteRefused(opens, entry.value);
      expect(container.read(provider).hasError, isFalse);
    });
  }
}
