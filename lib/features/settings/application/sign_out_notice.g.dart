// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_notice.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One line the athlete sees after a sign-out whose pre-logout upload failed
/// (ticket 102, Finding 86-007): their unsynced changes stay on this phone
/// and sync the next time they sign in.
///
/// `SettingsController.signOut()` sets it; the Welcome screen, where the
/// auth listener routes every sign-out, shows it once with `MealvanaSnackbar`
/// and takes it. Kept alive: the settings controller is auto-dispose and gone
/// by the time the sign-out lands.

@ProviderFor(SignOutNotice)
const signOutNoticeProvider = SignOutNoticeProvider._();

/// One line the athlete sees after a sign-out whose pre-logout upload failed
/// (ticket 102, Finding 86-007): their unsynced changes stay on this phone
/// and sync the next time they sign in.
///
/// `SettingsController.signOut()` sets it; the Welcome screen, where the
/// auth listener routes every sign-out, shows it once with `MealvanaSnackbar`
/// and takes it. Kept alive: the settings controller is auto-dispose and gone
/// by the time the sign-out lands.
final class SignOutNoticeProvider
    extends $NotifierProvider<SignOutNotice, String?> {
  /// One line the athlete sees after a sign-out whose pre-logout upload failed
  /// (ticket 102, Finding 86-007): their unsynced changes stay on this phone
  /// and sync the next time they sign in.
  ///
  /// `SettingsController.signOut()` sets it; the Welcome screen, where the
  /// auth listener routes every sign-out, shows it once with `MealvanaSnackbar`
  /// and takes it. Kept alive: the settings controller is auto-dispose and gone
  /// by the time the sign-out lands.
  const SignOutNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signOutNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signOutNoticeHash();

  @$internal
  @override
  SignOutNotice create() => SignOutNotice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$signOutNoticeHash() => r'39b99257f11ac99178f3effdd1c032a615aeba70';

/// One line the athlete sees after a sign-out whose pre-logout upload failed
/// (ticket 102, Finding 86-007): their unsynced changes stay on this phone
/// and sync the next time they sign in.
///
/// `SettingsController.signOut()` sets it; the Welcome screen, where the
/// auth listener routes every sign-out, shows it once with `MealvanaSnackbar`
/// and takes it. Kept alive: the settings controller is auto-dispose and gone
/// by the time the sign-out lands.

abstract class _$SignOutNotice extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
