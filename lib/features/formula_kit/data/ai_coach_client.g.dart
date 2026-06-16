// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_coach_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiCoachClient)
const aiCoachClientProvider = AiCoachClientProvider._();

final class AiCoachClientProvider
    extends $FunctionalProvider<AiCoachClient, AiCoachClient, AiCoachClient>
    with $Provider<AiCoachClient> {
  const AiCoachClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiCoachClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiCoachClientHash();

  @$internal
  @override
  $ProviderElement<AiCoachClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiCoachClient create(Ref ref) {
    return aiCoachClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiCoachClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiCoachClient>(value),
    );
  }
}

String _$aiCoachClientHash() => r'49d0c902db07ca44a02429526d361cf49425f02d';
