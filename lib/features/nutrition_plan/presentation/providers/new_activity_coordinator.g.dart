// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_activity_coordinator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// New Activity Coordinator
///
/// Manages tab selection state and coordinates shared state (date/time) across
/// all three sport-specific controllers (running, cycling, swimming).
///
/// This is a thin coordination layer that delegates business logic to existing
/// well-tested sport-specific controllers.
///
/// Status: Phase 0 - File structure created

@ProviderFor(NewActivityCoordinator)
const newActivityCoordinatorProvider = NewActivityCoordinatorProvider._();

/// New Activity Coordinator
///
/// Manages tab selection state and coordinates shared state (date/time) across
/// all three sport-specific controllers (running, cycling, swimming).
///
/// This is a thin coordination layer that delegates business logic to existing
/// well-tested sport-specific controllers.
///
/// Status: Phase 0 - File structure created
final class NewActivityCoordinatorProvider
    extends
        $NotifierProvider<NewActivityCoordinator, NewActivityCoordinatorState> {
  /// New Activity Coordinator
  ///
  /// Manages tab selection state and coordinates shared state (date/time) across
  /// all three sport-specific controllers (running, cycling, swimming).
  ///
  /// This is a thin coordination layer that delegates business logic to existing
  /// well-tested sport-specific controllers.
  ///
  /// Status: Phase 0 - File structure created
  const NewActivityCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newActivityCoordinatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newActivityCoordinatorHash();

  @$internal
  @override
  NewActivityCoordinator create() => NewActivityCoordinator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NewActivityCoordinatorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NewActivityCoordinatorState>(value),
    );
  }
}

String _$newActivityCoordinatorHash() =>
    r'0a997b83da80de0db4022663c169252e93914310';

/// New Activity Coordinator
///
/// Manages tab selection state and coordinates shared state (date/time) across
/// all three sport-specific controllers (running, cycling, swimming).
///
/// This is a thin coordination layer that delegates business logic to existing
/// well-tested sport-specific controllers.
///
/// Status: Phase 0 - File structure created

abstract class _$NewActivityCoordinator
    extends $Notifier<NewActivityCoordinatorState> {
  NewActivityCoordinatorState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<NewActivityCoordinatorState, NewActivityCoordinatorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                NewActivityCoordinatorState,
                NewActivityCoordinatorState
              >,
              NewActivityCoordinatorState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
