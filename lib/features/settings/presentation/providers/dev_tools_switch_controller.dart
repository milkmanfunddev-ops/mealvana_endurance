import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dev_tools_switch_store.dart';

part 'dev_tools_switch_controller.g.dart';

/// The Settings switch that turns the dev build's testing buttons off and on
/// (ticket 24, mp-271). The app shell watches it, so a flip takes effect at
/// once; the store remembers it for the next launch.
///
/// Only meaningful in the dev flavor. The shell never consults it in prod,
/// and Settings only shows the switch there, so a stray stored value on a
/// prod install changes nothing.
@Riverpod(keepAlive: true)
class DevToolsSwitchController extends _$DevToolsSwitchController {
  @override
  FutureOr<bool> build() => ref.watch(devToolsSwitchStoreProvider).read();

  Future<void> setVisible(bool visible) async {
    state = await AsyncValue.guard(() async {
      await ref.read(devToolsSwitchStoreProvider).write(visible);
      return visible;
    });
  }
}
