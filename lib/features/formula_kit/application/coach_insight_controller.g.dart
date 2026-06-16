// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_insight_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single source of truth for the Formula Kit coach-insight panel.
///
/// State is the most recently fetched [CoachInsight] (or `null` before the
/// first fetch). The panel computes the live draft's [CoachInsightContext.staleMarker]
/// and compares it with `state.value?.staleMarker` to decide whether the shown
/// insight is current or outdated. Cached hits never re-call the edge function,
/// so each [generate] is one billable model call.
///
/// Auto-disposes with the editor screen that hosts it.

@ProviderFor(CoachInsightController)
const coachInsightControllerProvider = CoachInsightControllerProvider._();

/// Single source of truth for the Formula Kit coach-insight panel.
///
/// State is the most recently fetched [CoachInsight] (or `null` before the
/// first fetch). The panel computes the live draft's [CoachInsightContext.staleMarker]
/// and compares it with `state.value?.staleMarker` to decide whether the shown
/// insight is current or outdated. Cached hits never re-call the edge function,
/// so each [generate] is one billable model call.
///
/// Auto-disposes with the editor screen that hosts it.
final class CoachInsightControllerProvider
    extends $AsyncNotifierProvider<CoachInsightController, CoachInsight?> {
  /// Single source of truth for the Formula Kit coach-insight panel.
  ///
  /// State is the most recently fetched [CoachInsight] (or `null` before the
  /// first fetch). The panel computes the live draft's [CoachInsightContext.staleMarker]
  /// and compares it with `state.value?.staleMarker` to decide whether the shown
  /// insight is current or outdated. Cached hits never re-call the edge function,
  /// so each [generate] is one billable model call.
  ///
  /// Auto-disposes with the editor screen that hosts it.
  const CoachInsightControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachInsightControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachInsightControllerHash();

  @$internal
  @override
  CoachInsightController create() => CoachInsightController();
}

String _$coachInsightControllerHash() =>
    r'2ca31eb8c4e7624bfe9caf6bf08ff3c206d92aec';

/// Single source of truth for the Formula Kit coach-insight panel.
///
/// State is the most recently fetched [CoachInsight] (or `null` before the
/// first fetch). The panel computes the live draft's [CoachInsightContext.staleMarker]
/// and compares it with `state.value?.staleMarker` to decide whether the shown
/// insight is current or outdated. Cached hits never re-call the edge function,
/// so each [generate] is one billable model call.
///
/// Auto-disposes with the editor screen that hosts it.

abstract class _$CoachInsightController extends $AsyncNotifier<CoachInsight?> {
  FutureOr<CoachInsight?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CoachInsight?>, CoachInsight?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CoachInsight?>, CoachInsight?>,
              AsyncValue<CoachInsight?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
