// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_insight_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single source of truth for the Formula Kit coach-insight panel.
///
/// Family provider keyed by [formulaId]. For existing formulas, [build] hydrates
/// the persisted insight from the Drift row so it survives navigation. For new
/// formulas ([formulaId] == null), starts blank.
///
/// On [generate], the insight is auto-persisted to the formula's row so it
/// survives navigating away and back without an explicit Save.

@ProviderFor(CoachInsightController)
const coachInsightControllerProvider = CoachInsightControllerFamily._();

/// Single source of truth for the Formula Kit coach-insight panel.
///
/// Family provider keyed by [formulaId]. For existing formulas, [build] hydrates
/// the persisted insight from the Drift row so it survives navigation. For new
/// formulas ([formulaId] == null), starts blank.
///
/// On [generate], the insight is auto-persisted to the formula's row so it
/// survives navigating away and back without an explicit Save.
final class CoachInsightControllerProvider
    extends $AsyncNotifierProvider<CoachInsightController, CoachInsight?> {
  /// Single source of truth for the Formula Kit coach-insight panel.
  ///
  /// Family provider keyed by [formulaId]. For existing formulas, [build] hydrates
  /// the persisted insight from the Drift row so it survives navigation. For new
  /// formulas ([formulaId] == null), starts blank.
  ///
  /// On [generate], the insight is auto-persisted to the formula's row so it
  /// survives navigating away and back without an explicit Save.
  const CoachInsightControllerProvider._({
    required CoachInsightControllerFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'coachInsightControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coachInsightControllerHash();

  @override
  String toString() {
    return r'coachInsightControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CoachInsightController create() => CoachInsightController();

  @override
  bool operator ==(Object other) {
    return other is CoachInsightControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coachInsightControllerHash() =>
    r'a44c08814ceb2a4ee94de9f3116fb23585ed2eea';

/// Single source of truth for the Formula Kit coach-insight panel.
///
/// Family provider keyed by [formulaId]. For existing formulas, [build] hydrates
/// the persisted insight from the Drift row so it survives navigation. For new
/// formulas ([formulaId] == null), starts blank.
///
/// On [generate], the insight is auto-persisted to the formula's row so it
/// survives navigating away and back without an explicit Save.

final class CoachInsightControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CoachInsightController,
          AsyncValue<CoachInsight?>,
          CoachInsight?,
          FutureOr<CoachInsight?>,
          String?
        > {
  const CoachInsightControllerFamily._()
    : super(
        retry: null,
        name: r'coachInsightControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Single source of truth for the Formula Kit coach-insight panel.
  ///
  /// Family provider keyed by [formulaId]. For existing formulas, [build] hydrates
  /// the persisted insight from the Drift row so it survives navigation. For new
  /// formulas ([formulaId] == null), starts blank.
  ///
  /// On [generate], the insight is auto-persisted to the formula's row so it
  /// survives navigating away and back without an explicit Save.

  CoachInsightControllerProvider call(String? formulaId) =>
      CoachInsightControllerProvider._(argument: formulaId, from: this);

  @override
  String toString() => r'coachInsightControllerProvider';
}

/// Single source of truth for the Formula Kit coach-insight panel.
///
/// Family provider keyed by [formulaId]. For existing formulas, [build] hydrates
/// the persisted insight from the Drift row so it survives navigation. For new
/// formulas ([formulaId] == null), starts blank.
///
/// On [generate], the insight is auto-persisted to the formula's row so it
/// survives navigating away and back without an explicit Save.

abstract class _$CoachInsightController extends $AsyncNotifier<CoachInsight?> {
  late final _$args = ref.$arg as String?;
  String? get formulaId => _$args;

  FutureOr<CoachInsight?> build(String? formulaId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
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
