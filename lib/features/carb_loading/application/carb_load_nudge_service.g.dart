// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_load_nudge_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadNudgeService)
const carbLoadNudgeServiceProvider = CarbLoadNudgeServiceProvider._();

final class CarbLoadNudgeServiceProvider
    extends
        $FunctionalProvider<
          CarbLoadNudgeService,
          CarbLoadNudgeService,
          CarbLoadNudgeService
        >
    with $Provider<CarbLoadNudgeService> {
  const CarbLoadNudgeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadNudgeServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadNudgeServiceHash();

  @$internal
  @override
  $ProviderElement<CarbLoadNudgeService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadNudgeService create(Ref ref) {
    return carbLoadNudgeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadNudgeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadNudgeService>(value),
    );
  }
}

String _$carbLoadNudgeServiceHash() =>
    r'78917460de9432e6d3f4e71f6078dda78df38763';
