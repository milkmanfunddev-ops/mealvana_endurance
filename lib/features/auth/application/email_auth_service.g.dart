// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_auth_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for handling Email/Password authentication
/// Uses Supabase's built-in updateUser() to link email to anonymous account
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod

@ProviderFor(EmailAuthService)
const emailAuthServiceProvider = EmailAuthServiceProvider._();

/// Service for handling Email/Password authentication
/// Uses Supabase's built-in updateUser() to link email to anonymous account
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
final class EmailAuthServiceProvider
    extends $AsyncNotifierProvider<EmailAuthService, void> {
  /// Service for handling Email/Password authentication
  /// Uses Supabase's built-in updateUser() to link email to anonymous account
  /// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
  const EmailAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailAuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailAuthServiceHash();

  @$internal
  @override
  EmailAuthService create() => EmailAuthService();
}

String _$emailAuthServiceHash() => r'8c55168ae4cab0c283ab0d6b9e793aa73684719c';

/// Service for handling Email/Password authentication
/// Uses Supabase's built-in updateUser() to link email to anonymous account
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod

abstract class _$EmailAuthService extends $AsyncNotifier<void> {
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
