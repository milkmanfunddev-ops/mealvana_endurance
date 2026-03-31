// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tp_writeback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the TrainingPeaks write-back service.
/// keepAlive because the service is stateless and expensive to recreate
/// (requires async resolution of API client and OAuth service).

@ProviderFor(tpWritebackService)
const tpWritebackServiceProvider = TpWritebackServiceProvider._();

/// Provider for the TrainingPeaks write-back service.
/// keepAlive because the service is stateless and expensive to recreate
/// (requires async resolution of API client and OAuth service).

final class TpWritebackServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<TpWritebackService>,
          TpWritebackService,
          FutureOr<TpWritebackService>
        >
    with
        $FutureModifier<TpWritebackService>,
        $FutureProvider<TpWritebackService> {
  /// Provider for the TrainingPeaks write-back service.
  /// keepAlive because the service is stateless and expensive to recreate
  /// (requires async resolution of API client and OAuth service).
  const TpWritebackServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tpWritebackServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tpWritebackServiceHash();

  @$internal
  @override
  $FutureProviderElement<TpWritebackService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TpWritebackService> create(Ref ref) {
    return tpWritebackService(ref);
  }
}

String _$tpWritebackServiceHash() =>
    r'0215cd70d937462d5e8472d43c6b7e35d7587a1b';
