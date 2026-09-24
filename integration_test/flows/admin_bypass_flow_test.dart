/// The Admin bypass under **Patrol** (mp-416): an Admin skips the paywall
/// screen and nothing else; the server still checks the subscription on
/// every Vana call.
///
/// mp-416, as the record words it: the Gate opens for an Admin (an account
/// the team marked by hand, `users.is_admin`) whatever its subscription says,
/// and there is no other exception. The server still checks the subscription
/// on every paid and Vana call, so an Admin skips only the paywall screen.
/// Example: test@test.com signs in on a fresh simulator with no purchase,
/// goes straight into the app, and Vana refuses it until it has a
/// subscription or a Grant.
///
/// **Written as the rule, for whatever account the run signs in as**, like
/// `pro_gate_flow_test.dart`: the flow reads the signed-in account's own
/// `users.is_admin` and `user_entitlements.active_until` (both owner-readable
/// under RLS), works out what mp-416 says the athlete should see, and checks
/// the app and the server against that.
///
///   * Gate: open (tabs shell) when the account is an Admin or holds Pro
///     (`active_until` in the future); the paywall otherwise.
///   * Admin: `/paywall` pushed on purpose yields straight back to the shell.
///   * Server: when the account holds no Pro, one `vana-chat` message is
///     refused with 403 `{error: pro_required}`, Admin or not. The refusal
///     comes before the budget and the model, so it costs nothing. When the
///     account holds Pro (a subscription or a Grant) the server leg is not
///     run: its answer would be a real, billed model turn.
///
/// The server's rule is `user_entitlements` (the webhook's cache of
/// RevenueCat); the app's gate reads the RevenueCat SDK. Both come from the
/// same RevenueCat record, so the flow uses the cache row as "holds Pro".
///
/// Run as the dev Admin (the M1 runner's account is not one; testing-wave
/// 03-003), with a define file carrying the Admin's address and password as
/// INTEGRATION_TEST_EMAIL / INTEGRATION_TEST_PASSWORD:
///   patrol test --target integration_test/flows/admin_bypass_flow_test.dart \
///     --flavor dev --bundle-id com.milkman.mealvanaendurance.dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=ADMIN_DEFINES.env \
///     --device UDID
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/flow_launcher.dart';
import '../helpers/test_config.dart';

const _paywallScreen = ValueKey('paywall.screen');
const _welcome = ValueKey('welcome.log_in_button');

/// The account's standing, read from the two rows mp-416 turns on.
class _Standing {
  const _Standing({required this.isAdmin, required this.activeUntil});

  final bool isAdmin;
  final DateTime? activeUntil;

  bool holdsPro(DateTime now) =>
      activeUntil != null && activeUntil!.isAfter(now);

  /// mp-416: the Gate opens for an Admin or an account with Pro.
  bool gateOpen(DateTime now) => isAdmin || holdsPro(now);

  @override
  String toString() =>
      'is_admin=$isAdmin, active_until=${activeUntil?.toIso8601String()}';
}

Future<_Standing> _readStanding(SupabaseClient client, String userId) async {
  final user = await client
      .from('users')
      .select('is_admin')
      .eq('id', userId)
      .maybeSingle();
  final entitlement = await client
      .from('user_entitlements')
      .select('active_until')
      .eq('user_id', userId)
      .maybeSingle();
  final until = entitlement?['active_until'] as String?;
  return _Standing(
    isAdmin: user?['is_admin'] == true,
    activeUntil: until == null ? null : DateTime.parse(until),
  );
}

/// Signs in when needed and waits until the app shows the tabs shell or the
/// paywall. Unlike [ensureAuthenticated], which waits for the shell only,
/// this accepts either landing, since which one is right is what the flow
/// checks. Returns the landing key, or null when neither came.
Future<ValueKey<String>?> _signInAndLand(PatrolIntegrationTester $) async {
  const landings = [authSentinel, _paywallScreen];

  Future<ValueKey<String>?> poll(Duration within) async {
    final polls = within.inMilliseconds ~/ 500;
    for (var i = 0; i < polls; i++) {
      await $.pump(const Duration(milliseconds: 500));
      for (final key in landings) {
        if ($(key).exists) return key;
      }
      if ($(_welcome).exists) return _welcome;
    }
    return null;
  }

  var landing = await poll(const Duration(seconds: 90));
  final signedInAs = Supabase.instance.client.auth.currentUser?.email;
  if (landing != null &&
      landing != _welcome &&
      signedInAs?.toLowerCase() != TestConfig.loginEmail.toLowerCase()) {
    // Signed in as someone else: sign out and take the login path.
    await Supabase.instance.client.auth.signOut();
    landing = await poll(const Duration(seconds: 20));
  }
  if (landing != _welcome) return landing;

  await $(_welcome).tap();
  await $(
    const ValueKey('login_options.email_button'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login_options.email_button')).tap();
  await $(
    const ValueKey('login.email_field'),
  ).waitUntilVisible(timeout: const Duration(seconds: 15));
  await $(const ValueKey('login.email_field')).enterText(TestConfig.loginEmail);
  await $(
    const ValueKey('login.password_field'),
  ).enterText(TestConfig.loginPassword);
  await $(const ValueKey('login.log_in_button')).tap();

  final after = await poll(const Duration(seconds: 40));
  return after == _welcome ? null : after;
}

/// One Vana message straight to `vana-chat` as the signed-in athlete.
Future<http.Response> _sendVanaMessage(Session session) => http
    .post(
      Uri.parse('${TestConfig.supabaseUrl}/functions/v1/vana-chat'),
      headers: {
        'apikey': TestConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'kind': 'general',
        'message': 'How much carbohydrate should I eat before a long run?',
      }),
    )
    .timeout(const Duration(seconds: 30));

void main() {
  patrolTest(
    'Admin bypass — an Admin skips only the paywall; the server still checks Pro',
    ($) async {
      await launchApp($);
      await $.pump(const Duration(milliseconds: 500));

      if (!TestConfig.hasLoginCredentials) {
        skipFlow(noAuthSkipMessage());
        return;
      }

      final landing = await _signInAndLand($);
      expect(
        landing,
        isNotNull,
        reason: 'sign-in reached neither the tabs shell nor the paywall',
      );
      restoreTestErrorHandler();

      final client = Supabase.instance.client;
      final session = client.auth.currentSession!;
      final standing = await _readStanding(client, session.user.id);
      final now = DateTime.now().toUtc();
      // ignore: avoid_print
      print('[admin_bypass] ${session.user.email}: $standing');

      // ---- The Gate ----------------------------------------------------
      expect(
        landing,
        standing.gateOpen(now) ? authSentinel : _paywallScreen,
        reason: standing.gateOpen(now)
            ? 'mp-416: an Admin or an account with Pro goes straight into '
                  'the app ($standing)'
            : 'mp-416: no Admin flag and no Pro means the paywall '
                  '($standing)',
      );

      // ---- An Admin pushing /paywall lands back on the shell -------------
      if (standing.isAdmin) {
        final context = $.tester.element(find.byType(Navigator).first);
        GoRouter.of(context).push('/paywall');
        ValueKey<String>? after;
        for (var i = 0; i < 20 && after == null; i++) {
          await $.pump(const Duration(milliseconds: 500));
          if ($(_paywallScreen).exists) after = _paywallScreen;
        }
        expect(
          after,
          isNull,
          reason:
              'mp-416: the Gate is open for an Admin, so /paywall must '
              'not show the paywall',
        );
        expect($(authSentinel).exists, isTrue);
      }

      // ---- The server's own check ----------------------------------------
      if (standing.holdsPro(now)) {
        // A skip, not a silent return: the server's refusal is this flow's
        // point, and a run that could not check it must not read as a pass
        // (Finding 03-001; this account's Grants are Finding 12-001).
        skipFlow(
          'admin_bypass: server leg not run, the account holds Pro until '
          '${standing.activeUntil!.toIso8601String()}, so vana-chat would '
          'answer with a billed model turn. mp-416 lets Vana answer here.',
        );
        return;
      }
      final res = await _sendVanaMessage(session);
      // ignore: avoid_print
      print('[admin_bypass] vana-chat ${res.statusCode} ${res.body}');
      expect(
        res.statusCode,
        403,
        reason:
            'mp-416: with no Pro the server refuses a Vana message, '
            'Admin or not ($standing)',
      );
      expect(
        (jsonDecode(res.body) as Map<String, dynamic>)['error'],
        'pro_required',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
