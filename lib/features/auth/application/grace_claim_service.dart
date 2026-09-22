import 'package:riverpod_annotation/riverpod_annotation.dart';
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
class GraceClaimService {
  GraceClaimService({
    required SupabaseClient supabase,
    required SubscriptionService subscriptions,
    required AppLogger logger,
    Duration timeout = const Duration(seconds: 10),
  }) : _supabase = supabase,
       _subscriptions = subscriptions,
       _logger = logger,
       _timeout = timeout;

  static const String functionName = 'grace-claim';

  /// The screen waits for the answer before it moves on, so a slow network
  /// must not hold the athlete there.
  final Duration _timeout;

  final SupabaseClient _supabase;
  final SubscriptionService _subscriptions;
  final AppLogger _logger;

  Future<GraceClaimResult> claim() async {
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
