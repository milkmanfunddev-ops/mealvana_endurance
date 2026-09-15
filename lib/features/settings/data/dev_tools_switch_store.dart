import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/prefs_provider.dart';

part 'dev_tools_switch_store.g.dart';

/// Whether the dev build's testing buttons (the blue wrench and, in debug,
/// the red accessibility checker) are shown on this device.
///
/// Per device, not per user: a tester hides the buttons for the phone in
/// their hand, whoever is signed in. Nothing stored reads as on
/// (decision mp-271: defaults to on, remembered across launches).
class DevToolsSwitchStore {
  const DevToolsSwitchStore(this._prefs);

  final SharedPreferences _prefs;

  static const String key = 'dev.tools_visible';

  bool read() => _prefs.getBool(key) ?? true;

  Future<void> write(bool visible) => _prefs.setBool(key, visible);
}

@riverpod
DevToolsSwitchStore devToolsSwitchStore(Ref ref) =>
    DevToolsSwitchStore(ref.watch(sharedPreferencesProvider));
