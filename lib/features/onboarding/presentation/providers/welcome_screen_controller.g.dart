// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'welcome_screen_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for welcome screen content

@ProviderFor(WelcomeScreenController)
const welcomeScreenControllerProvider = WelcomeScreenControllerProvider._();

/// Controller for welcome screen content
final class WelcomeScreenControllerProvider
    extends
        $AsyncNotifierProvider<WelcomeScreenController, WelcomeScreenState> {
  /// Controller for welcome screen content
  const WelcomeScreenControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'welcomeScreenControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$welcomeScreenControllerHash();

  @$internal
  @override
  WelcomeScreenController create() => WelcomeScreenController();
}

String _$welcomeScreenControllerHash() =>
    r'd142360cce64b90d6c0d2e3208f141ca9aebf13f';

/// Controller for welcome screen content

abstract class _$WelcomeScreenController
    extends $AsyncNotifier<WelcomeScreenState> {
  FutureOr<WelcomeScreenState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<WelcomeScreenState>, WelcomeScreenState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WelcomeScreenState>, WelcomeScreenState>,
              AsyncValue<WelcomeScreenState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
