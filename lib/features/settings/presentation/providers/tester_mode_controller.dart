import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/analytics/internal_user_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../data/tester_account_store.dart';

part 'tester_mode_controller.g.dart';

/// Whether the signed-in account agreed with a flip of the Tester switch.
enum TesterAccountSync {
  /// `users.is_internal` now matches the switch.
  saved,

  /// Nobody is signed in, so only this device changed.
  notSignedIn,

  /// The device changed but the account did not — photo saves will be refused
  /// until the switch is flipped again with a connection.
  failed,
}

/// The 7-tap "Mark this device as internal" switch: the device flag and the
/// account's `users.is_internal`, together.
///
/// The device flag always applies, even when the account write fails: it is
/// what the switch has always done, and a Tester without signal still wants
/// the controls drawn. The account write is reported rather than thrown, so the
/// screen can say plainly that the server did not take it.
///
/// Only an explicit flip writes the account. A debug build is Tester by
/// default ([InternalDeviceFlagNotifier.isForced]) and must not quietly mark
/// every account it signs into.
@riverpod
class TesterModeController extends _$TesterModeController {
  @override
  FutureOr<void> build() {}

  Future<TesterAccountSync> setTester(bool value) async {
    await ref.read(internalDeviceFlagProvider.notifier).setInternal(value);

    var result = TesterAccountSync.failed;
    state = await AsyncValue.guard(() async {
      final wrote = await ref.read(testerAccountStoreProvider).write(value);
      result = wrote ? TesterAccountSync.saved : TesterAccountSync.notSignedIn;
    });
    if (state.hasError) {
      ref
          .read(appExternalDepsProvider)
          .logger
          .warning(
            'Tester switch: users.is_internal write failed: ${state.error}',
            context: 'SETTINGS',
          );
    }
    return result;
  }
}
