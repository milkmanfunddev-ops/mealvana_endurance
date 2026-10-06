import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../shared/services/app_config.dart';

/// Path of the edge function Apple posts the Android sign-in result to
/// (`supabase/functions/apple-signin-callback`). It relays the result to the
/// plugin's `signinwithapple://callback` intent. Supabase's own
/// `/auth/v1/callback` cannot serve here: it rejects a flow it did not start
/// ("OAuth state parameter missing") and never returns to the app.
const appleSignInCallbackPath = '/functions/v1/apple-signin-callback';

/// Thrown when Apple sign-in is attempted on Android without a Services ID.
class AppleSignInNotConfiguredException implements Exception {
  const AppleSignInNotConfiguredException();

  @override
  String toString() =>
      'AppleSignInNotConfiguredException: APPLE_AUTH_SERVICES_ID is empty, '
      'so Sign in with Apple cannot run on Android in this build.';
}

/// Whether this build can offer Sign in with Apple at all. iOS always can
/// (native sheet, bundle ID); Android only with a Services ID configured.
bool appleSignInAvailable({
  required bool isAndroid,
  required String servicesId,
}) => !isAndroid || servicesId.trim().isNotEmpty;

/// [appleSignInAvailable] for this build: the auth screens show the Apple
/// button only when it can work, so a dev Android build without a Services ID
/// offers Google / email instead of a button that always fails.
final appleSignInAvailableProvider = Provider<bool>((ref) {
  if (kIsWeb) return true; // web uses Supabase's OAuth redirect, not the plugin
  final String servicesId;
  try {
    servicesId = ref.watch(appConfigProvider).appleAuthServicesId;
  } on ProviderException catch (e) {
    // Only the "appConfigProvider must be overridden" placeholder (widget
    // tests, a harness without an env file): keep the pre-ticket-17 behaviour
    // and show the button. Any other config failure is a real one and
    // propagates. The catch is the feature test (allow-list: reasoned).
    if (e.exception is! UnimplementedError) rethrow;
    return true;
  }
  return appleSignInAvailable(
    isAndroid: defaultTargetPlatform == TargetPlatform.android,
    servicesId: servicesId,
  );
});

/// The `webAuthenticationOptions` for `SignInWithApple.getAppleIDCredential`.
///
/// Android runs Apple's web flow in a Custom Tab and the plugin throws
/// "`webAuthenticationOptions` argument must be provided on Android" without
/// these (Sentry MEALVANA-ENDURANCE-A6 / BY). iOS uses the native sheet and
/// gets `null`.
///
/// [servicesId] is the Apple Services ID (`APPLE_AUTH_SERVICES_ID`); it must
/// also be in the Supabase project's Apple client-id list, because the id
/// token's audience is the Services ID. [supabaseUrl] picks the project, so
/// dev and prod each get their own return URL.
WebAuthenticationOptions? appleWebAuthenticationOptions({
  required bool isAndroid,
  required String servicesId,
  required String supabaseUrl,
}) {
  if (!isAndroid) return null;
  final clientId = servicesId.trim();
  if (clientId.isEmpty) throw const AppleSignInNotConfiguredException();
  final base = supabaseUrl.endsWith('/')
      ? supabaseUrl.substring(0, supabaseUrl.length - 1)
      : supabaseUrl;
  return WebAuthenticationOptions(
    clientId: clientId,
    redirectUri: Uri.parse('$base$appleSignInCallbackPath'),
  );
}
