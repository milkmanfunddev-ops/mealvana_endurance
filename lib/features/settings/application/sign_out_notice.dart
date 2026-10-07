import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sign_out_notice.g.dart';

/// One line the athlete sees after a sign-out whose pre-logout upload failed
/// (ticket 102, Finding 86-007): their unsynced changes stay on this phone
/// and sync the next time they sign in.
///
/// `SettingsController.signOut()` sets it; the Welcome screen, where the
/// auth listener routes every sign-out, shows it once with `MealvanaSnackbar`
/// and takes it. Kept alive: the settings controller is auto-dispose and gone
/// by the time the sign-out lands.
@Riverpod(keepAlive: true)
class SignOutNotice extends _$SignOutNotice {
  @override
  String? build() => null;

  void set(String? notice) => state = notice;

  /// Returns the pending line and clears it, so it shows once.
  String? take() {
    final notice = state;
    state = null;
    return notice;
  }
}
