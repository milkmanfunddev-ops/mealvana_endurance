// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'education_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(educationRepository)
const educationRepositoryProvider = EducationRepositoryProvider._();

final class EducationRepositoryProvider
    extends
        $FunctionalProvider<
          EducationRepository,
          EducationRepository,
          EducationRepository
        >
    with $Provider<EducationRepository> {
  const EducationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'educationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$educationRepositoryHash();

  @$internal
  @override
  $ProviderElement<EducationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EducationRepository create(Ref ref) {
    return educationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EducationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EducationRepository>(value),
    );
  }
}

String _$educationRepositoryHash() =>
    r'28ed3ffe9b593ea1cbf8fe5bcd7ea886648729d6';
