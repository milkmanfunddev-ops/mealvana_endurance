// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_food_selection_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CarbLoadingFoodSelectionController)
const carbLoadingFoodSelectionControllerProvider =
    CarbLoadingFoodSelectionControllerFamily._();

final class CarbLoadingFoodSelectionControllerProvider
    extends
        $AsyncNotifierProvider<
          CarbLoadingFoodSelectionController,
          CarbLoadingFoodSelectionState
        > {
  const CarbLoadingFoodSelectionControllerProvider._({
    required CarbLoadingFoodSelectionControllerFamily super.from,
    required CarbLoadingFoodSelectionParams super.argument,
  }) : super(
         retry: null,
         name: r'carbLoadingFoodSelectionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$carbLoadingFoodSelectionControllerHash();

  @override
  String toString() {
    return r'carbLoadingFoodSelectionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CarbLoadingFoodSelectionController create() =>
      CarbLoadingFoodSelectionController();

  @override
  bool operator ==(Object other) {
    return other is CarbLoadingFoodSelectionControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbLoadingFoodSelectionControllerHash() =>
    r'272c13079c55b2e42e9c8b9dcfcd365477416900';

final class CarbLoadingFoodSelectionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CarbLoadingFoodSelectionController,
          AsyncValue<CarbLoadingFoodSelectionState>,
          CarbLoadingFoodSelectionState,
          FutureOr<CarbLoadingFoodSelectionState>,
          CarbLoadingFoodSelectionParams
        > {
  const CarbLoadingFoodSelectionControllerFamily._()
    : super(
        retry: null,
        name: r'carbLoadingFoodSelectionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CarbLoadingFoodSelectionControllerProvider call(
    CarbLoadingFoodSelectionParams params,
  ) => CarbLoadingFoodSelectionControllerProvider._(
    argument: params,
    from: this,
  );

  @override
  String toString() => r'carbLoadingFoodSelectionControllerProvider';
}

abstract class _$CarbLoadingFoodSelectionController
    extends $AsyncNotifier<CarbLoadingFoodSelectionState> {
  late final _$args = ref.$arg as CarbLoadingFoodSelectionParams;
  CarbLoadingFoodSelectionParams get params => _$args;

  FutureOr<CarbLoadingFoodSelectionState> build(
    CarbLoadingFoodSelectionParams params,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<
              AsyncValue<CarbLoadingFoodSelectionState>,
              CarbLoadingFoodSelectionState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CarbLoadingFoodSelectionState>,
                CarbLoadingFoodSelectionState
              >,
              AsyncValue<CarbLoadingFoodSelectionState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
