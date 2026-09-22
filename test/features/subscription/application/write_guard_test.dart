/// The write guard every write controller calls first (mp-457 §4, mp-491).
///
/// `ref.canWrite()` answers from `writeAccessProvider`: true and the
/// controller writes; false and the paywall has been asked to open (through
/// `paywallOpenerProvider`, the one opener) so the controller returns
/// without writing. `requireWriteAccess` is the same check for a method that
/// must answer with a value: it throws [WriteAccessDenied] after opening.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/subscription/application/write_guard.dart';
import 'package:mealvana_endurance/features/subscription/domain/write_access_denied.dart';

import '../../../helpers/write_access.dart';

void main() {
  group('ref.canWrite()', () {
    test('open: true, and the paywall is not opened', () async {
      final opens = PaywallOpens();
      final c = ProviderContainer(overrides: [writesAllowed(), opens.override]);
      addTearDown(c.dispose);
      final probe = c.read(_probeProvider.notifier);
      expect(await probe.tryWrite(), isTrue);
      expect(opens.count, 0);
    });

    test('lapsed: false, and the paywall is opened once', () async {
      final opens = PaywallOpens();
      final c = ProviderContainer(overrides: [writesRefused(), opens.override]);
      addTearDown(c.dispose);
      final probe = c.read(_probeProvider.notifier);
      expect(await probe.tryWrite(), isFalse);
      expect(opens.count, 1);
    });

    test('the helper override answers writes allowed', () async {
      final c = ProviderContainer(overrides: [writesAllowed()]);
      addTearDown(c.dispose);
      expect(await c.read(_probeProvider.notifier).tryWrite(), isTrue);
    });
  });

  group('requireWriteAccess', () {
    test('open: returns', () async {
      final c = ProviderContainer(overrides: [writesAllowed()]);
      addTearDown(c.dispose);
      await c.read(_probeProvider.notifier).mustWrite();
    });

    test('lapsed: opens the paywall, then throws WriteAccessDenied', () async {
      final opens = PaywallOpens();
      final c = ProviderContainer(overrides: [writesRefused(), opens.override]);
      addTearDown(c.dispose);
      await expectLater(
        c.read(_probeProvider.notifier).mustWrite(),
        throwsA(isA<WriteAccessDenied>()),
      );
      expect(opens.count, 1);
    });
  });

  test('openPaywall without a widgets binding is a no-op', () {
    // A bare controller test: no binding, no navigator. The default opener
    // must return quietly rather than throw.
    expect(openPaywall, returnsNormally);
  });

  testWidgets('openPaywall without a mounted navigator is a no-op', (_) async {
    expect(openPaywall, returnsNormally);
  });
}

/// A stand-in write controller: what every real one does first.
final _probeProvider = NotifierProvider<_Probe, int>(_Probe.new);

class _Probe extends Notifier<int> {
  @override
  int build() => 0;

  Future<bool> tryWrite() async {
    if (!await ref.canWrite()) return false;
    state++;
    return true;
  }

  Future<void> mustWrite() async {
    await requireWriteAccess(ref);
    state++;
  }
}
