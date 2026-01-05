// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_directory_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoachDirectoryController)
const coachDirectoryControllerProvider = CoachDirectoryControllerProvider._();

final class CoachDirectoryControllerProvider
    extends
        $AsyncNotifierProvider<CoachDirectoryController, CoachDirectoryState> {
  const CoachDirectoryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachDirectoryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachDirectoryControllerHash();

  @$internal
  @override
  CoachDirectoryController create() => CoachDirectoryController();
}

String _$coachDirectoryControllerHash() =>
    r'526b801b5ebe45d88cfcdc6442f5853b7e6b89eb';

abstract class _$CoachDirectoryController
    extends $AsyncNotifier<CoachDirectoryState> {
  FutureOr<CoachDirectoryState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<CoachDirectoryState>, CoachDirectoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CoachDirectoryState>, CoachDirectoryState>,
              AsyncValue<CoachDirectoryState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
