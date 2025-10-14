// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_rating_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for handling nutrition plan ratings
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern

@ProviderFor(PlanRatingController)
const planRatingControllerProvider = PlanRatingControllerProvider._();

/// Controller for handling nutrition plan ratings
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern
final class PlanRatingControllerProvider
    extends $AsyncNotifierProvider<PlanRatingController, PlanRatingState> {
  /// Controller for handling nutrition plan ratings
  /// Following Andrea Bizzotto's FOA AsyncNotifier pattern
  const PlanRatingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planRatingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planRatingControllerHash();

  @$internal
  @override
  PlanRatingController create() => PlanRatingController();
}

String _$planRatingControllerHash() =>
    r'b503bbc7e8d8814d42b4b397eb95575d5bb80987';

/// Controller for handling nutrition plan ratings
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern

abstract class _$PlanRatingController extends $AsyncNotifier<PlanRatingState> {
  FutureOr<PlanRatingState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<PlanRatingState>, PlanRatingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PlanRatingState>, PlanRatingState>,
              AsyncValue<PlanRatingState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
