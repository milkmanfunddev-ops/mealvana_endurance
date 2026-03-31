// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'education_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(educationService)
const educationServiceProvider = EducationServiceProvider._();

final class EducationServiceProvider
    extends
        $FunctionalProvider<
          EducationService,
          EducationService,
          EducationService
        >
    with $Provider<EducationService> {
  const EducationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'educationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$educationServiceHash();

  @$internal
  @override
  $ProviderElement<EducationService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EducationService create(Ref ref) {
    return educationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EducationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EducationService>(value),
    );
  }
}

String _$educationServiceHash() => r'488a8c46c83c0659455b7c898112cc35c1f035c6';
