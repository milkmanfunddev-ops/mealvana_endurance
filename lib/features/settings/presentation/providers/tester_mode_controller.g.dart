// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tester_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(TesterModeController)
const testerModeControllerProvider = TesterModeControllerProvider._();

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
final class TesterModeControllerProvider
    extends $AsyncNotifierProvider<TesterModeController, void> {
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
  const TesterModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'testerModeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$testerModeControllerHash();

  @$internal
  @override
  TesterModeController create() => TesterModeController();
}

String _$testerModeControllerHash() =>
    r'3008c3397930a34ff11ad962e3b5fae5b2540c14';

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

abstract class _$TesterModeController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
