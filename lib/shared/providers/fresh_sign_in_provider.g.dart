// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fresh_sign_in_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the session on this device came from a sign-in in THIS process
/// (`AuthChangeEvent.signedIn`), as opposed to a restored one
/// (`initialSession`). Marked by `AuthListenerService` the moment the event
/// arrives, cleared by the first reader that acted on it.
///
/// Testing-wave 134 (Finding 120-001): after Log In the Plan tab showed the
/// account's stale local draft for a second before the first pull replaced
/// it. `MealPlanController` reads this to wait for that pull instead; a
/// normal launch (restored session) stays local-first.

@ProviderFor(FreshSignIn)
const freshSignInProvider = FreshSignInProvider._();

/// Whether the session on this device came from a sign-in in THIS process
/// (`AuthChangeEvent.signedIn`), as opposed to a restored one
/// (`initialSession`). Marked by `AuthListenerService` the moment the event
/// arrives, cleared by the first reader that acted on it.
///
/// Testing-wave 134 (Finding 120-001): after Log In the Plan tab showed the
/// account's stale local draft for a second before the first pull replaced
/// it. `MealPlanController` reads this to wait for that pull instead; a
/// normal launch (restored session) stays local-first.
final class FreshSignInProvider extends $NotifierProvider<FreshSignIn, bool> {
  /// Whether the session on this device came from a sign-in in THIS process
  /// (`AuthChangeEvent.signedIn`), as opposed to a restored one
  /// (`initialSession`). Marked by `AuthListenerService` the moment the event
  /// arrives, cleared by the first reader that acted on it.
  ///
  /// Testing-wave 134 (Finding 120-001): after Log In the Plan tab showed the
  /// account's stale local draft for a second before the first pull replaced
  /// it. `MealPlanController` reads this to wait for that pull instead; a
  /// normal launch (restored session) stays local-first.
  const FreshSignInProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'freshSignInProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$freshSignInHash();

  @$internal
  @override
  FreshSignIn create() => FreshSignIn();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$freshSignInHash() => r'3c2d2477654116ae27724e8d931cdb9431c4dae8';

/// Whether the session on this device came from a sign-in in THIS process
/// (`AuthChangeEvent.signedIn`), as opposed to a restored one
/// (`initialSession`). Marked by `AuthListenerService` the moment the event
/// arrives, cleared by the first reader that acted on it.
///
/// Testing-wave 134 (Finding 120-001): after Log In the Plan tab showed the
/// account's stale local draft for a second before the first pull replaced
/// it. `MealPlanController` reads this to wait for that pull instead; a
/// normal launch (restored session) stays local-first.

abstract class _$FreshSignIn extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
