// CONTROLLER-LEVEL test for the dev-tools switch (ticket 24, mp-271): the real
// DevToolsSwitchController through a ProviderContainer over a real
// SharedPreferences instance, so the default, the write and the read-back on
// the "next launch" (a fresh container over the same prefs) are all exercised.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/settings/data/dev_tools_switch_store.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/dev_tools_switch_controller.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('defaults to on when nothing is stored', () async {
    final container = makeContainer();
    final visible = await container.read(devToolsSwitchControllerProvider.future);
    expect(visible, isTrue);
  });

  test('setVisible(false) updates state and persists per device', () async {
    final container = makeContainer();
    await container.read(devToolsSwitchControllerProvider.future);

    await container
        .read(devToolsSwitchControllerProvider.notifier)
        .setVisible(false);

    expect(container.read(devToolsSwitchControllerProvider).value, isFalse);
    expect(prefs.getBool(DevToolsSwitchStore.key), isFalse);
  });

  test('a stored off survives a relaunch (fresh container, same prefs)', () async {
    final first = makeContainer();
    await first.read(devToolsSwitchControllerProvider.future);
    await first.read(devToolsSwitchControllerProvider.notifier).setVisible(false);

    final relaunch = makeContainer();
    final visible = await relaunch.read(devToolsSwitchControllerProvider.future);
    expect(visible, isFalse);
  });

  test('setVisible(true) restores the buttons and stores true', () async {
    final container = makeContainer();
    final notifier = container.read(devToolsSwitchControllerProvider.notifier);
    await container.read(devToolsSwitchControllerProvider.future);

    await notifier.setVisible(false);
    await notifier.setVisible(true);

    expect(container.read(devToolsSwitchControllerProvider).value, isTrue);
    expect(prefs.getBool(DevToolsSwitchStore.key), isTrue);
  });
}
