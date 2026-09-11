// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_moment_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the platform asks for reduced motion. Overridden in tests.

@ProviderFor(vanaReducedMotion)
const vanaReducedMotionProvider = VanaReducedMotionProvider._();

/// Whether the platform asks for reduced motion. Overridden in tests.

final class VanaReducedMotionProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the platform asks for reduced motion. Overridden in tests.
  const VanaReducedMotionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaReducedMotionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaReducedMotionHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return vanaReducedMotion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$vanaReducedMotionHash() => r'be3f50d988892972361197837f036a26267ea8e9';

/// The moment on the launcher (vana-moment spec). Global and per day, like
/// the launcher: it stays as the athlete moves between screens until it
/// retires.
///
/// Resolves [resolveVanaMoment] from today's activities and meal logs when
/// either changes and every [vanaMomentResolveInterval]. A raised moment
/// waits until the launcher's host calls [ring] with a launcher on screen, so
/// it never spends its one ring where nobody can see it. What rang, what was
/// answered and where each opening sits persist per user per day, so a
/// restart neither rings again nor loses the thread.

@ProviderFor(VanaMomentController)
const vanaMomentControllerProvider = VanaMomentControllerProvider._();

/// The moment on the launcher (vana-moment spec). Global and per day, like
/// the launcher: it stays as the athlete moves between screens until it
/// retires.
///
/// Resolves [resolveVanaMoment] from today's activities and meal logs when
/// either changes and every [vanaMomentResolveInterval]. A raised moment
/// waits until the launcher's host calls [ring] with a launcher on screen, so
/// it never spends its one ring where nobody can see it. What rang, what was
/// answered and where each opening sits persist per user per day, so a
/// restart neither rings again nor loses the thread.
final class VanaMomentControllerProvider
    extends $AsyncNotifierProvider<VanaMomentController, VanaMomentState> {
  /// The moment on the launcher (vana-moment spec). Global and per day, like
  /// the launcher: it stays as the athlete moves between screens until it
  /// retires.
  ///
  /// Resolves [resolveVanaMoment] from today's activities and meal logs when
  /// either changes and every [vanaMomentResolveInterval]. A raised moment
  /// waits until the launcher's host calls [ring] with a launcher on screen, so
  /// it never spends its one ring where nobody can see it. What rang, what was
  /// answered and where each opening sits persist per user per day, so a
  /// restart neither rings again nor loses the thread.
  const VanaMomentControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaMomentControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaMomentControllerHash();

  @$internal
  @override
  VanaMomentController create() => VanaMomentController();
}

String _$vanaMomentControllerHash() =>
    r'ce12772e80c7f865e627dca23f67e6bb7b4219b7';

/// The moment on the launcher (vana-moment spec). Global and per day, like
/// the launcher: it stays as the athlete moves between screens until it
/// retires.
///
/// Resolves [resolveVanaMoment] from today's activities and meal logs when
/// either changes and every [vanaMomentResolveInterval]. A raised moment
/// waits until the launcher's host calls [ring] with a launcher on screen, so
/// it never spends its one ring where nobody can see it. What rang, what was
/// answered and where each opening sits persist per user per day, so a
/// restart neither rings again nor loses the thread.

abstract class _$VanaMomentController extends $AsyncNotifier<VanaMomentState> {
  FutureOr<VanaMomentState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<VanaMomentState>, VanaMomentState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VanaMomentState>, VanaMomentState>,
              AsyncValue<VanaMomentState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
