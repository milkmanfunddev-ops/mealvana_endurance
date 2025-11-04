// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(emailService)
const emailServiceProvider = EmailServiceProvider._();

final class EmailServiceProvider
    extends $FunctionalProvider<EmailService, EmailService, EmailService>
    with $Provider<EmailService> {
  const EmailServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailServiceHash();

  @$internal
  @override
  $ProviderElement<EmailService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EmailService create(Ref ref) {
    return emailService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailService>(value),
    );
  }
}

String _$emailServiceHash() => r'4ace2e717046800d66aae36b39e44f46819d2303';
