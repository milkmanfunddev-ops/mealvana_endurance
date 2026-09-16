// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_auth_handoff.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How the email login and signup screens tell the Log In screen beneath
/// them that they finished (2026-09-16: the first login came back to the
/// Log In screen and only the second went through).
///
/// The screens used to `pop(true)` and the Log In screen awaited the future
/// its `push` returned. That future is not reliable: whenever a dependency
/// above the Router changes while the pushed screen is up (the keyboard
/// closing, a theme or config rebuild), Flutter's Router re-parses the route
/// stack it last reported, and go_router 12 rebuilds every pushed route from
/// that encoded state with a fresh completer. The pop then completes a
/// completer nobody awaits and the Log In screen never moves. A sign-in that
/// takes a while (a fresh session, data migration, the first sync) leaves a
/// wide window for that; the quick second login slips through it.
///
/// So the screens report through this notifier instead, and the Log In
/// screen listens. They still pop, for the stack; nothing waits on it.

@ProviderFor(EmailAuthHandoff)
const emailAuthHandoffProvider = EmailAuthHandoffProvider._();

/// How the email login and signup screens tell the Log In screen beneath
/// them that they finished (2026-09-16: the first login came back to the
/// Log In screen and only the second went through).
///
/// The screens used to `pop(true)` and the Log In screen awaited the future
/// its `push` returned. That future is not reliable: whenever a dependency
/// above the Router changes while the pushed screen is up (the keyboard
/// closing, a theme or config rebuild), Flutter's Router re-parses the route
/// stack it last reported, and go_router 12 rebuilds every pushed route from
/// that encoded state with a fresh completer. The pop then completes a
/// completer nobody awaits and the Log In screen never moves. A sign-in that
/// takes a while (a fresh session, data migration, the first sync) leaves a
/// wide window for that; the quick second login slips through it.
///
/// So the screens report through this notifier instead, and the Log In
/// screen listens. They still pop, for the stack; nothing waits on it.
final class EmailAuthHandoffProvider
    extends $NotifierProvider<EmailAuthHandoff, EmailAuthHandoffEvent?> {
  /// How the email login and signup screens tell the Log In screen beneath
  /// them that they finished (2026-09-16: the first login came back to the
  /// Log In screen and only the second went through).
  ///
  /// The screens used to `pop(true)` and the Log In screen awaited the future
  /// its `push` returned. That future is not reliable: whenever a dependency
  /// above the Router changes while the pushed screen is up (the keyboard
  /// closing, a theme or config rebuild), Flutter's Router re-parses the route
  /// stack it last reported, and go_router 12 rebuilds every pushed route from
  /// that encoded state with a fresh completer. The pop then completes a
  /// completer nobody awaits and the Log In screen never moves. A sign-in that
  /// takes a while (a fresh session, data migration, the first sync) leaves a
  /// wide window for that; the quick second login slips through it.
  ///
  /// So the screens report through this notifier instead, and the Log In
  /// screen listens. They still pop, for the stack; nothing waits on it.
  const EmailAuthHandoffProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailAuthHandoffProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailAuthHandoffHash();

  @$internal
  @override
  EmailAuthHandoff create() => EmailAuthHandoff();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailAuthHandoffEvent? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailAuthHandoffEvent?>(value),
    );
  }
}

String _$emailAuthHandoffHash() => r'6dc443cf6b3514e15b15d16c1791a27483099f78';

/// How the email login and signup screens tell the Log In screen beneath
/// them that they finished (2026-09-16: the first login came back to the
/// Log In screen and only the second went through).
///
/// The screens used to `pop(true)` and the Log In screen awaited the future
/// its `push` returned. That future is not reliable: whenever a dependency
/// above the Router changes while the pushed screen is up (the keyboard
/// closing, a theme or config rebuild), Flutter's Router re-parses the route
/// stack it last reported, and go_router 12 rebuilds every pushed route from
/// that encoded state with a fresh completer. The pop then completes a
/// completer nobody awaits and the Log In screen never moves. A sign-in that
/// takes a while (a fresh session, data migration, the first sync) leaves a
/// wide window for that; the quick second login slips through it.
///
/// So the screens report through this notifier instead, and the Log In
/// screen listens. They still pop, for the stack; nothing waits on it.

abstract class _$EmailAuthHandoff extends $Notifier<EmailAuthHandoffEvent?> {
  EmailAuthHandoffEvent? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<EmailAuthHandoffEvent?, EmailAuthHandoffEvent?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EmailAuthHandoffEvent?, EmailAuthHandoffEvent?>,
              EmailAuthHandoffEvent?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
