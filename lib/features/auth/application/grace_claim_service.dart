import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../subscription/data/subscription_service.dart';

part 'grace_claim_service.g.dart';

/// What the claim came to.
enum GraceClaimResult {
  /// The grace month was granted now.
  granted,

  /// The account already held it (a second claim, or the flip-day run).
  alreadyHeld,

  /// Not this account's to claim, or the flip has not happened yet.
  notEligible,

  /// No answer: offline, the store was down, or the function is not set up.
  failed,
}

@riverpod
GraceClaimService graceClaimService(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return GraceClaimService(
    supabase: deps.supabaseClient,
    subscriptions: ref.watch(subscriptionServiceProvider),
    logger: deps.logger,
    prefs: deps.sharedPreferences,
  );
}

/// The grace month for an install left anonymous from before the paywall
/// (mp-455 §4, paywall ticket 09). Called once that install has signed up
/// onto its old user; the `grace-claim` function decides whether the account
/// is owed the 30 days and grants them through RevenueCat, once.
///
/// Never throws: whatever the answer, the athlete moves on to the paywall,
/// which unlocks when the grant is there. A granted (or already held) answer
/// drops the SDK's cached status, which still holds the locked answer from
/// before the grant, so the gate's next read asks RevenueCat.
///
/// A claim that gets no answer is tried again at the next app start (mp-561,
/// card mp-555): [claim] marks the signed-in account as owed a claim before
/// it asks, and clears the mark on any answer but [GraceClaimResult.failed].
/// The startup flow calls [retryPending], which claims again only for the
/// account the mark names. Only the old-install sign-up path calls [claim],
/// so the mark carries that eligibility; the function still decides the
/// rest (created before the flip, anonymous at it) and is idempotent:
/// RevenueCat's own record decides "once" (applyGrace in
/// `supabase/functions/_shared/grace/grace.ts`).
class GraceClaimService {
  GraceClaimService({
    required SupabaseClient supabase,
    required SubscriptionService subscriptions,
    required AppLogger logger,
    SharedPreferences? prefs,
    Duration timeout = const Duration(seconds: 10),
  }) : _supabase = supabase,
       _subscriptions = subscriptions,
       _logger = logger,
       _prefs = prefs,
       _timeout = timeout;

  static const String functionName = 'grace-claim';

  /// The auth user id whose claim has not been answered yet.
  static const String pendingKey = 'grace_claim_pending_user_id';

  /// Where the pending mark lives; null keeps no mark (and no retry).
  final SharedPreferences? _prefs;

  /// The screen waits for the answer before it moves on, so a slow network
  /// must not hold the athlete there.
  final Duration _timeout;

  final SupabaseClient _supabase;
  final SubscriptionService _subscriptions;
  final AppLogger _logger;

  /// Claim again at startup when the signed-in account's last claim got no
  /// answer (or never finished). Null when there is nothing to retry: no
  /// mark, nobody signed in, still anonymous, or the mark names another
  /// account (kept, for when that account signs back in). Never throws.
  Future<GraceClaimResult?> retryPending() async {
    final prefs = _prefs;
    if (prefs == null) return null;
    try {
      final pending = prefs.getString(pendingKey);
      if (pending == null) return null;
      final user = _supabase.auth.currentUser;
      if (user == null || user.isAnonymous || user.id != pending) return null;
      _logger.info('Retrying a grace claim with no answer', context: 'GRACE');
    } catch (e, st) {
      _logger.error(
        'Grace claim retry check failed',
        context: 'GRACE',
        error: e,
        stackTrace: st,
      );
      return null;
    }
    return claim();
  }

  Future<GraceClaimResult> claim() async {
    final pendingFor = await _markPending();
    final result = await _ask();
    if (pendingFor != null && result != GraceClaimResult.failed) {
      await _clearPending(pendingFor);
    }
    return result;
  }

  /// Mark the signed-in account as owed an answer. Returns its id, or null
  /// when no mark is kept.
  Future<String?> _markPending() async {
    final prefs = _prefs;
    if (prefs == null) return null;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return null;
      await prefs.setString(pendingKey, userId);
      return userId;
    } catch (e, st) {
      _logger.error(
        'Grace claim pending mark failed',
        context: 'GRACE',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _clearPending(String userId) async {
    try {
      if (_prefs?.getString(pendingKey) == userId) {
        await _prefs?.remove(pendingKey);
      }
    } catch (e, st) {
      _logger.error(
        'Grace claim pending clear failed',
        context: 'GRACE',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<GraceClaimResult> _ask() async {
    final GraceClaimResult result;
    try {
      final response = await _supabase.functions
          .invoke(functionName)
          .timeout(_timeout);
      result = _read(response.data);
      _logger.info(
        'Grace claim answered',
        context: 'GRACE',
        data: {'result': result.name, 'body': response.data},
      );
    } on FunctionException catch (e) {
      _logger.warning(
        'Grace claim refused by the server',
        context: 'GRACE',
        data: {'status': e.status, 'details': e.details},
      );
      return GraceClaimResult.failed;
    } catch (e, st) {
      _logger.error(
        'Grace claim failed',
        context: 'GRACE',
        error: e,
        stackTrace: st,
      );
      return GraceClaimResult.failed;
    }

    if (result == GraceClaimResult.granted ||
        result == GraceClaimResult.alreadyHeld) {
      await _subscriptions.forgetCachedStatus();
    }
    return result;
  }

  static GraceClaimResult _read(Object? data) {
    if (data is! Map) return GraceClaimResult.failed;
    if (data['ok'] != true) return GraceClaimResult.notEligible;
    return switch (data['status']) {
      'granted' => GraceClaimResult.granted,
      // 'marked': the grant was already there, only the attribute was added.
      'already' || 'marked' => GraceClaimResult.alreadyHeld,
      _ => GraceClaimResult.failed,
    };
  }
}
