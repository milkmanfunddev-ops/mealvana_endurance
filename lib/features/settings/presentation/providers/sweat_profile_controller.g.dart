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
    r'edd4481947ffa5af83991b0d5de8c67b052a0c6a';

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
