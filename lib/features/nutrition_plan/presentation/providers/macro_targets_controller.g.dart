// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macro_targets_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns

@ProviderFor(MacroTargetsController)
const macroTargetsControllerProvider = MacroTargetsControllerProvider._();

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns
final class MacroTargetsControllerProvider
    extends $AsyncNotifierProvider<MacroTargetsController, MacroTargetsState> {
  /// Controller for distance page gut entry screen
  /// FOA COMPLIANT: Contains ALL business logic, no UI concerns
  const MacroTargetsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'macroTargetsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$macroTargetsControllerHash();

  @$internal
  @override
  MacroTargetsController create() => MacroTargetsController();
}

String _$macroTargetsControllerHash() =>
    r'bf9e71e68ab12d00219549ce3f42b9f21598df0e';

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns

abstract class _$MacroTargetsController
    extends $AsyncNotifier<MacroTargetsState> {
  FutureOr<MacroTargetsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<MacroTargetsState>, MacroTargetsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MacroTargetsState>, MacroTargetsState>,
              AsyncValue<MacroTargetsState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for DraftActivityCleanupService.
///
/// keepAlive so the service survives navigate-away (the [MacroTargetsController]
/// schedules cleanup in its onDispose, and the timer must outlive that
/// controller). Its own onDispose cancels any pending cleanup timers, which
/// fires only at scope/app teardown — also keeping widget tests timer-clean.

@ProviderFor(draftActivityCleanupService)
const draftActivityCleanupServiceProvider =
    DraftActivityCleanupServiceProvider._();

/// Provider for DraftActivityCleanupService.
///
/// keepAlive so the service survives navigate-away (the [MacroTargetsController]
/// schedules cleanup in its onDispose, and the timer must outlive that
/// controller). Its own onDispose cancels any pending cleanup timers, which
/// fires only at scope/app teardown — also keeping widget tests timer-clean.

final class DraftActivityCleanupServiceProvider
    extends
        $FunctionalProvider<
          DraftActivityCleanupService,
          DraftActivityCleanupService,
          DraftActivityCleanupService
        >
    with $Provider<DraftActivityCleanupService> {
  /// Provider for DraftActivityCleanupService.
  ///
  /// keepAlive so the service survives navigate-away (the [MacroTargetsController]
  /// schedules cleanup in its onDispose, and the timer must outlive that
  /// controller). Its own onDispose cancels any pending cleanup timers, which
  /// fires only at scope/app teardown — also keeping widget tests timer-clean.
  const DraftActivityCleanupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftActivityCleanupServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftActivityCleanupServiceHash();

  @$internal
  @override
  $ProviderElement<DraftActivityCleanupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DraftActivityCleanupService create(Ref ref) {
    return draftActivityCleanupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DraftActivityCleanupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DraftActivityCleanupService>(value),
    );
  }
}

String _$draftActivityCleanupServiceHash() =>
    r'405a19f493c2fc77b9a39db290924aec6f12cc97';
