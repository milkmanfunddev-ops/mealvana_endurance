// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'education_interest_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(educationInterestService)
const educationInterestServiceProvider = EducationInterestServiceProvider._();

final class EducationInterestServiceProvider
    extends
        $FunctionalProvider<
          EducationInterestService,
          EducationInterestService,
          EducationInterestService
        >
    with $Provider<EducationInterestService> {
  const EducationInterestServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'educationInterestServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$educationInterestServiceHash();

  @$internal
  @override
  $ProviderElement<EducationInterestService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EducationInterestService create(Ref ref) {
    return educationInterestService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EducationInterestService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EducationInterestService>(value),
    );
  }
}

String _$educationInterestServiceHash() =>
    r'e8d67f89f6efc327a362e4365e803fbd8a9cd079';
