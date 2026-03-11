// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(coachService)
const coachServiceProvider = CoachServiceProvider._();

final class CoachServiceProvider
    extends $FunctionalProvider<CoachService, CoachService, CoachService>
    with $Provider<CoachService> {
  const CoachServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachServiceHash();

  @$internal
  @override
  $ProviderElement<CoachService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoachService create(Ref ref) {
    return coachService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachService>(value),
    );
  }
}

String _$coachServiceHash() => r'672aacee6034d24a9fb4f59a2f370914549eb845';
