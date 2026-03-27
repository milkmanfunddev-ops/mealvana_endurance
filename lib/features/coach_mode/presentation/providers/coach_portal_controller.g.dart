// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_portal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for coach portal UI state (selected athlete, active section)

@ProviderFor(CoachPortalController)
const coachPortalControllerProvider = CoachPortalControllerProvider._();

/// Controller for coach portal UI state (selected athlete, active section)
final class CoachPortalControllerProvider
    extends $NotifierProvider<CoachPortalController, CoachPortalState> {
  /// Controller for coach portal UI state (selected athlete, active section)
  const CoachPortalControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachPortalControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachPortalControllerHash();

  @$internal
  @override
  CoachPortalController create() => CoachPortalController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachPortalState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachPortalState>(value),
    );
  }
}

String _$coachPortalControllerHash() =>
    r'51517d2835df7a9d373591ac3fc982b9e72a88e8';

/// Controller for coach portal UI state (selected athlete, active section)

abstract class _$CoachPortalController extends $Notifier<CoachPortalState> {
  CoachPortalState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CoachPortalState, CoachPortalState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoachPortalState, CoachPortalState>,
              CoachPortalState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
