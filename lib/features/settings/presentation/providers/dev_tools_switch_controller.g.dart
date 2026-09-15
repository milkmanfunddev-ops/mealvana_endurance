// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dev_tools_switch_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Settings switch that turns the dev build's testing buttons off and on
/// (ticket 24, mp-271). The app shell watches it, so a flip takes effect at
/// once; the store remembers it for the next launch.
///
/// Only meaningful in the dev flavor. The shell never consults it in prod,
/// and Settings only shows the switch there, so a stray stored value on a
/// prod install changes nothing.

@ProviderFor(DevToolsSwitchController)
const devToolsSwitchControllerProvider = DevToolsSwitchControllerProvider._();

/// The Settings switch that turns the dev build's testing buttons off and on
/// (ticket 24, mp-271). The app shell watches it, so a flip takes effect at
/// once; the store remembers it for the next launch.
///
/// Only meaningful in the dev flavor. The shell never consults it in prod,
/// and Settings only shows the switch there, so a stray stored value on a
/// prod install changes nothing.
final class DevToolsSwitchControllerProvider
    extends $AsyncNotifierProvider<DevToolsSwitchController, bool> {
  /// The Settings switch that turns the dev build's testing buttons off and on
  /// (ticket 24, mp-271). The app shell watches it, so a flip takes effect at
  /// once; the store remembers it for the next launch.
  ///
  /// Only meaningful in the dev flavor. The shell never consults it in prod,
  /// and Settings only shows the switch there, so a stray stored value on a
  /// prod install changes nothing.
  const DevToolsSwitchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devToolsSwitchControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devToolsSwitchControllerHash();

  @$internal
  @override
  DevToolsSwitchController create() => DevToolsSwitchController();
}

String _$devToolsSwitchControllerHash() =>
    r'c48125aca8741dd75c3ec4f3c876dcb2ef60c960';

/// The Settings switch that turns the dev build's testing buttons off and on
/// (ticket 24, mp-271). The app shell watches it, so a flip takes effect at
/// once; the store remembers it for the next launch.
///
/// Only meaningful in the dev flavor. The shell never consults it in prod,
/// and Settings only shows the switch there, so a stray stored value on a
/// prod install changes nothing.

abstract class _$DevToolsSwitchController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
