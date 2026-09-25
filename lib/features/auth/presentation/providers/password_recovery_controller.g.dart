// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_recovery_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password

@ProviderFor(PasswordRecoveryController)
const passwordRecoveryControllerProvider =
    PasswordRecoveryControllerProvider._();

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
final class PasswordRecoveryControllerProvider
    extends $AsyncNotifierProvider<PasswordRecoveryController, void> {
  /// Controller for managing OTP-based password recovery flow
  /// Steps: 1) Send reset code  2) Verify code  3) Set new password
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
    r'b22b0a6e4b9d9d99e29f0ebb4251fc7e594b1e34';

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password

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
