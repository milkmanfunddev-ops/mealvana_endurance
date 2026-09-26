// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_recovery_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
///
/// The right reset code signs the phone in (GoTrue's recovery OTP opens a
/// session). That session is only ever a means to Set New Password
/// (testing-wave 124-003, Lee 2026-09-26): [verifyResetCode] sets the
/// [recoveryPendingKey] marker, [setNewPassword] clears it, and
/// [cancelRecovery] (Cancel, back) signs the session out. A marker still set
/// at startup means the app was quit on Set New Password:
/// `AppStartupService.endAbandonedRecovery` signs out before routing, so the
/// relaunch lands on Log In.

@ProviderFor(PasswordRecoveryController)
const passwordRecoveryControllerProvider =
    PasswordRecoveryControllerProvider._();

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
///
/// The right reset code signs the phone in (GoTrue's recovery OTP opens a
/// session). That session is only ever a means to Set New Password
/// (testing-wave 124-003, Lee 2026-09-26): [verifyResetCode] sets the
/// [recoveryPendingKey] marker, [setNewPassword] clears it, and
/// [cancelRecovery] (Cancel, back) signs the session out. A marker still set
/// at startup means the app was quit on Set New Password:
/// `AppStartupService.endAbandonedRecovery` signs out before routing, so the
/// relaunch lands on Log In.
final class PasswordRecoveryControllerProvider
    extends $AsyncNotifierProvider<PasswordRecoveryController, void> {
  /// Controller for managing OTP-based password recovery flow
  /// Steps: 1) Send reset code  2) Verify code  3) Set new password
  ///
  /// The right reset code signs the phone in (GoTrue's recovery OTP opens a
  /// session). That session is only ever a means to Set New Password
  /// (testing-wave 124-003, Lee 2026-09-26): [verifyResetCode] sets the
  /// [recoveryPendingKey] marker, [setNewPassword] clears it, and
  /// [cancelRecovery] (Cancel, back) signs the session out. A marker still set
  /// at startup means the app was quit on Set New Password:
  /// `AppStartupService.endAbandonedRecovery` signs out before routing, so the
  /// relaunch lands on Log In.
  const PasswordRecoveryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passwordRecoveryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passwordRecoveryControllerHash();

  @$internal
  @override
  PasswordRecoveryController create() => PasswordRecoveryController();
}

String _$passwordRecoveryControllerHash() =>
    r'b99f79b0357640714a28bda8ae14f5cf657b814a';

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
///
/// The right reset code signs the phone in (GoTrue's recovery OTP opens a
/// session). That session is only ever a means to Set New Password
/// (testing-wave 124-003, Lee 2026-09-26): [verifyResetCode] sets the
/// [recoveryPendingKey] marker, [setNewPassword] clears it, and
/// [cancelRecovery] (Cancel, back) signs the session out. A marker still set
/// at startup means the app was quit on Set New Password:
/// `AppStartupService.endAbandonedRecovery` signs out before routing, so the
/// relaunch lands on Log In.

abstract class _$PasswordRecoveryController extends $AsyncNotifier<void> {
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
