// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_training_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConnectTrainingController)
const connectTrainingControllerProvider = ConnectTrainingControllerProvider._();

final class ConnectTrainingControllerProvider
    extends
        $AsyncNotifierProvider<
          ConnectTrainingController,
          ConnectTrainingState
        > {
  const ConnectTrainingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectTrainingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectTrainingControllerHash();

  @$internal
  @override
  ConnectTrainingController create() => ConnectTrainingController();
}

String _$connectTrainingControllerHash() =>
    r'592e82d773164182695fa13b6b566493e264274a';

abstract class _$ConnectTrainingController
    extends $AsyncNotifier<ConnectTrainingState> {
  FutureOr<ConnectTrainingState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<ConnectTrainingState>, ConnectTrainingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ConnectTrainingState>,
                ConnectTrainingState
              >,
              AsyncValue<ConnectTrainingState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
