// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_sync_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingSyncHandler)
const carbLoadingSyncHandlerProvider = CarbLoadingSyncHandlerProvider._();

final class CarbLoadingSyncHandlerProvider
    extends
        $FunctionalProvider<
          CarbLoadingSyncHandler,
          CarbLoadingSyncHandler,
          CarbLoadingSyncHandler
        >
    with $Provider<CarbLoadingSyncHandler> {
  const CarbLoadingSyncHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingSyncHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingSyncHandlerHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingSyncHandler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingSyncHandler create(Ref ref) {
    return carbLoadingSyncHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingSyncHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingSyncHandler>(value),
    );
  }
}

String _$carbLoadingSyncHandlerHash() =>
    r'fc800e4e010df14e1ba83f7e8971a6821160a939';
