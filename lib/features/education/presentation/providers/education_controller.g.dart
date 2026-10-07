// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'education_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EducationController)
const educationControllerProvider = EducationControllerProvider._();

final class EducationControllerProvider
    extends
        $AsyncNotifierProvider<EducationController, EducationContentGroups> {
  const EducationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'educationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$educationControllerHash();

  @$internal
  @override
  EducationController create() => EducationController();
}

String _$educationControllerHash() =>
    r'a3d7ae7339aef81e87086b5eef00b8c070b1e6f5';

abstract class _$EducationController
    extends $AsyncNotifier<EducationContentGroups> {
  FutureOr<EducationContentGroups> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<EducationContentGroups>, EducationContentGroups>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<EducationContentGroups>,
                EducationContentGroups
              >,
              AsyncValue<EducationContentGroups>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
