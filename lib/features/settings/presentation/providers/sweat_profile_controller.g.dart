// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sweat_profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the Sweat Profile settings screen.
///
/// Follows Andrea Bizzotto's AsyncNotifier pattern. Loads the current
/// [UserProfile] on build and exposes mutation methods that accumulate
/// state locally until [save] is called.

@ProviderFor(SweatProfileController)
const sweatProfileControllerProvider = SweatProfileControllerProvider._();

/// Controller for the Sweat Profile settings screen.
///
/// Follows Andrea Bizzotto's AsyncNotifier pattern. Loads the current
/// [UserProfile] on build and exposes mutation methods that accumulate
/// state locally until [save] is called.
final class SweatProfileControllerProvider
    extends $AsyncNotifierProvider<SweatProfileController, SweatProfileState> {
  /// Controller for the Sweat Profile settings screen.
  ///
  /// Follows Andrea Bizzotto's AsyncNotifier pattern. Loads the current
  /// [UserProfile] on build and exposes mutation methods that accumulate
  /// state locally until [save] is called.
  const SweatProfileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sweatProfileControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sweatProfileControllerHash();

  @$internal
  @override
  SweatProfileController create() => SweatProfileController();
}

String _$sweatProfileControllerHash() =>
    r'c76fe6ed14dcb95462034a88046528b8e0e2f600';

/// Controller for the Sweat Profile settings screen.
///
/// Follows Andrea Bizzotto's AsyncNotifier pattern. Loads the current
/// [UserProfile] on build and exposes mutation methods that accumulate
/// state locally until [save] is called.

abstract class _$SweatProfileController
    extends $AsyncNotifier<SweatProfileState> {
  FutureOr<SweatProfileState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<SweatProfileState>, SweatProfileState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SweatProfileState>, SweatProfileState>,
              AsyncValue<SweatProfileState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
