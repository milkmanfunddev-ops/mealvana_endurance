// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_day_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CarbLoadingDayDetailController)
const carbLoadingDayDetailControllerProvider =
    CarbLoadingDayDetailControllerFamily._();

final class CarbLoadingDayDetailControllerProvider
    extends
        $AsyncNotifierProvider<
          CarbLoadingDayDetailController,
          CarbLoadingDayDetailState
        > {
  const CarbLoadingDayDetailControllerProvider._({
    required CarbLoadingDayDetailControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carbLoadingDayDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingDayDetailControllerHash();

  @override
  String toString() {
    return r'carbLoadingDayDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CarbLoadingDayDetailController create() => CarbLoadingDayDetailController();

  @override
  bool operator ==(Object other) {
    return other is CarbLoadingDayDetailControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbLoadingDayDetailControllerHash() =>
    r'bf35b5de2f5394797e9f0d579487e0f98492bdeb';

final class CarbLoadingDayDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CarbLoadingDayDetailController,
          AsyncValue<CarbLoadingDayDetailState>,
          CarbLoadingDayDetailState,
          FutureOr<CarbLoadingDayDetailState>,
          String
        > {
  const CarbLoadingDayDetailControllerFamily._()
    : super(
        retry: null,
        name: r'carbLoadingDayDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CarbLoadingDayDetailControllerProvider call(String carbLoadingDayId) =>
      CarbLoadingDayDetailControllerProvider._(
        argument: carbLoadingDayId,
        from: this,
      );

  @override
  String toString() => r'carbLoadingDayDetailControllerProvider';
}

abstract class _$CarbLoadingDayDetailController
    extends $AsyncNotifier<CarbLoadingDayDetailState> {
  late final _$args = ref.$arg as String;
  String get carbLoadingDayId => _$args;

  FutureOr<CarbLoadingDayDetailState> build(String carbLoadingDayId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<
              AsyncValue<CarbLoadingDayDetailState>,
              CarbLoadingDayDetailState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CarbLoadingDayDetailState>,
                CarbLoadingDayDetailState
              >,
              AsyncValue<CarbLoadingDayDetailState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
