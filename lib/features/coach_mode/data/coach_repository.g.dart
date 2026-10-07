// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(coachRepository)
const coachRepositoryProvider = CoachRepositoryProvider._();

final class CoachRepositoryProvider
    extends
        $FunctionalProvider<CoachRepository, CoachRepository, CoachRepository>
    with $Provider<CoachRepository> {
  const CoachRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachRepositoryHash();

  @$internal
  @override
  $ProviderElement<CoachRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoachRepository create(Ref ref) {
    return coachRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachRepository>(value),
    );
  }
}

String _$coachRepositoryHash() => r'b526f2d6fba7acf41f3cf666e0965db3c6723c42';
