// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_messaging_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(coachMessagingRepository)
const coachMessagingRepositoryProvider = CoachMessagingRepositoryProvider._();

final class CoachMessagingRepositoryProvider
    extends
        $FunctionalProvider<
          CoachMessagingRepository,
          CoachMessagingRepository,
          CoachMessagingRepository
        >
    with $Provider<CoachMessagingRepository> {
  const CoachMessagingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachMessagingRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachMessagingRepositoryHash();

  @$internal
  @override
  $ProviderElement<CoachMessagingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CoachMessagingRepository create(Ref ref) {
    return coachMessagingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachMessagingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachMessagingRepository>(value),
    );
  }
}

String _$coachMessagingRepositoryHash() =>
    r'592a2bba0648152a692ee0dc4783bc7a362e20ed';
