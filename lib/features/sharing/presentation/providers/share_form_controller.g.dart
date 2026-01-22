// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ShareFormController)
const shareFormControllerProvider = ShareFormControllerFamily._();

final class ShareFormControllerProvider
    extends $AsyncNotifierProvider<ShareFormController, ShareFormState> {
  const ShareFormControllerProvider._({
    required ShareFormControllerFamily super.from,
    required NutritionPlan super.argument,
  }) : super(
         retry: null,
         name: r'shareFormControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$shareFormControllerHash();

  @override
  String toString() {
    return r'shareFormControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ShareFormController create() => ShareFormController();

  @override
  bool operator ==(Object other) {
    return other is ShareFormControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$shareFormControllerHash() =>
    r'b7e70f438cfa80b16ff089b1d2a9c9571f456670';

final class ShareFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ShareFormController,
          AsyncValue<ShareFormState>,
          ShareFormState,
          FutureOr<ShareFormState>,
          NutritionPlan
        > {
  const ShareFormControllerFamily._()
    : super(
        retry: null,
        name: r'shareFormControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ShareFormControllerProvider call(NutritionPlan nutritionPlan) =>
      ShareFormControllerProvider._(argument: nutritionPlan, from: this);

  @override
  String toString() => r'shareFormControllerProvider';
}

abstract class _$ShareFormController extends $AsyncNotifier<ShareFormState> {
  late final _$args = ref.$arg as NutritionPlan;
  NutritionPlan get nutritionPlan => _$args;

  FutureOr<ShareFormState> build(NutritionPlan nutritionPlan);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<ShareFormState>, ShareFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ShareFormState>, ShareFormState>,
              AsyncValue<ShareFormState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
