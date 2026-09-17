// CONTROLLER-LEVEL test for the 7-tap Tester switch (Lee, 2026-09-17): the real
// TesterModeController through a ProviderContainer, with a recording device
// flag and a recording account store behind it. What is asserted is what the
// switch leaves behind — the device flag and the one account write — and what
// it tells the screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/settings/data/tester_account_store.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/tester_mode_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/internal_user_service.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../meal_planning/helpers/container.dart';
import '../meal_planning/helpers/fakes.dart';

/// Stands in for the Keychain-backed flag, recording every flip.
class _RecordingFlag extends InternalDeviceFlagNotifier {
  final flips = <bool>[];

  @override
  bool build() => false;

  @override
  Future<void> setInternal(bool value) async {
    flips.add(value);
    state = value;
  }
}

/// Records what would have reached `users.is_internal`.
class _RecordingAccount implements TesterAccountStore {
  final writes = <bool>[];
  bool signedIn = true;
  Object? failWith;

  @override
  Future<bool> write(bool isTester) async {
    writes.add(isTester);
    if (failWith case final e?) throw e;
    return signedIn;
  }
}

void main() {
  late _RecordingFlag flag;
  late _RecordingAccount account;
  late ProviderContainer container;

  setUp(() {
    flag = _RecordingFlag();
    account = _RecordingAccount();
    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          testDeps(logger: FakeLogger()),
        ),
        internalDeviceFlagProvider.overrideWith(() => flag),
        testerAccountStoreProvider.overrideWithValue(account),
      ],
    );
    addTearDown(container.dispose);
    container.listen(testerModeControllerProvider, (_, __) {});
  });

  TesterModeController notifier() =>
      container.read(testerModeControllerProvider.notifier);

  test('turning it on marks the device and the account, once each', () async {
    final result = await notifier().setTester(true);

    expect(result, TesterAccountSync.saved);
    expect(flag.flips, [true]);
    expect(account.writes, [true]);
    expect(container.read(internalDeviceFlagProvider), isTrue);
  });

  test('turning it off clears the account too', () async {
    final result = await notifier().setTester(false);

    expect(result, TesterAccountSync.saved);
    expect(flag.flips, [false]);
    expect(account.writes, [false]);
  });

  test('signed out, only the device changes, and the screen is told', () async {
    account.signedIn = false;

    final result = await notifier().setTester(true);

    expect(result, TesterAccountSync.notSignedIn);
    expect(container.read(internalDeviceFlagProvider), isTrue);
  });

  test('a failed account write still switches the device, and says so', () async {
    account.failWith = const PostgrestException(message: 'network down');

    final result = await notifier().setTester(true);

    // Reported, not thrown: the Tester is told the server did not take it.
    expect(result, TesterAccountSync.failed);
    expect(container.read(internalDeviceFlagProvider), isTrue);
    expect(account.writes, [true]);
  });
}
