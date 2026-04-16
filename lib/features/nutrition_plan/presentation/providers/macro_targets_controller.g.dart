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
    r'a220ac377a819424208c0a441e1effab855eb665';

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

/// Provider for DraftActivityCleanupService

@ProviderFor(draftActivityCleanupService)
const draftActivityCleanupServiceProvider =
    DraftActivityCleanupServiceProvider._();

/// Provider for DraftActivityCleanupService

final class DraftActivityCleanupServiceProvider
    extends
        $FunctionalProvider<
          DraftActivityCleanupService,
          DraftActivityCleanupService,
          DraftActivityCleanupService
        >
    with $Provider<DraftActivityCleanupService> {
  /// Provider for DraftActivityCleanupService
  const DraftActivityCleanupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftActivityCleanupServiceProvider',
        isAutoDispose: true,
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
    r'7acc74026b98fea0a8e028a578c1ff466754f5a0';
