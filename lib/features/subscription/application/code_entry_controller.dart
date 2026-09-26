import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../coach_mode/application/coach_service.dart';
import '../../coach_mode/presentation/providers/coach_dashboard_controller.dart';
import '../../coach_mode/presentation/providers/my_coaches_controller.dart';
import '../../settings/presentation/providers/settings_controller.dart';
import '../data/subscription_service.dart';
import '../domain/code_redemption.dart';
import 'subscription_status_provider.dart';

part 'code_entry_controller.g.dart';

/// Our own Code entry (mp-458), reached from Redeem code in the paywall's ⋯
/// menu (mp-494) and on the Subscription screen (mp-495). Never the App
/// Store's offer-code sheet.
///
/// [redeem] sends the Code to `redeem-code`; the state holds what it did
/// ([CodeRedeemed]) or why it was refused ([CodeRefused]), and an
/// [AsyncError] carrying a [CodeRedeemFailure] when no answer came back.
///
/// A Code that grants `pro` (a coach's own, a giveaway) was granted on the
/// server, so the SDK's cached status still says locked: it is dropped and
/// the status provider asked again, which opens the gate and moves the
/// person into the app, as after the grace claim.
///
/// A Code that changes coaching (mp-600, card mp-598) updates the app at
/// once: a coach's own Code pulls the new `coaches` row, an athlete's coach
/// Code pulls the pending pairing, and coach mode (Settings) and both
/// pairing lists (the athlete's My Coaches, the coach's dashboard) are
/// rebuilt from it. The pull comes first because both lists sync only once
/// per notifier, and Riverpod keeps the notifier across an invalidate.
///
/// keepAlive for the same reason as [ProPaywallController]: the entry only
/// `ref.read`s the notifier, and a redemption in flight must finish its
/// status refresh even if the sheet is closed under it. [reset] clears the
/// last answer when the entry opens again.
@Riverpod(keepAlive: true)
class CodeEntryController extends _$CodeEntryController {
  static const String functionName = 'redeem-code';

  /// The entry waits for the answer; a stalled network must not hold it.
  static const Duration timeout = Duration(seconds: 20);

  @override
  FutureOr<CodeRedemption?> build() => null;

  /// Clear the last answer for a fresh entry.
  void reset() => state = const AsyncData(null);

  /// Redeem [code] as typed (trimmed; the server ignores case and spaces).
  /// Returns the answer, or null when the Code was blank or no answer came
  /// back (the state then holds the [CodeRedeemFailure]).
  Future<CodeRedemption?> redeem(String code) async {
    final entered = code.trim();
    if (entered.isEmpty) return null;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = CodeRedemption.fromResponse(await _invoke(entered));
      if (result is CodeRedeemed && result.grantsPro) {
        await ref.read(subscriptionServiceProvider).forgetCachedStatus();
        await ref.read(subscriptionStatusProvider.notifier).refresh();
      }
      if (result is CodeRedeemed) await _refreshCoaching(result.kind);
      return result;
    });
    return state.value;
  }

  /// Pull what the Code changed in coaching and rebuild coach mode and the
  /// pairing lists. Never throws: the Code is redeemed either way, and a
  /// failed pull leaves the lists to their own sync.
  Future<void> _refreshCoaching(RedeemedKind kind) async {
    if (kind != RedeemedKind.coach && kind != RedeemedKind.paired) return;
    final coachService = ref.read(coachServiceProvider);
    try {
      if (kind == RedeemedKind.coach) {
        await coachService.syncCurrentCoachDataFromSupabase();
      } else {
        await coachService.syncRelationshipsFromSupabase();
        await coachService.syncMyCoachesData();
      }
    } catch (e, st) {
      ref
          .read(appExternalDepsProvider)
          .logger
          .error(
            'Coaching refresh after a Code failed',
            context: 'CODES',
            error: e,
            stackTrace: st,
          );
    }
    ref
      ..invalidate(settingsControllerProvider)
      ..invalidate(myCoachesControllerProvider)
      ..invalidate(coachDashboardControllerProvider);
  }

  Future<Object?> _invoke(String code) async {
    final deps = ref.read(appExternalDepsProvider);
    try {
      final response = await deps.supabaseClient.functions
          .invoke(functionName, body: {'code': code})
          .timeout(timeout);
      return response.data;
    } on FunctionException catch (e) {
      deps.logger.warning(
        'redeem-code answered ${e.status}',
        context: 'CODES',
        data: {'details': e.details},
      );
      // 400: after the server strips spaces the Code is empty (invalid_input)
      // or longer than any Code can be (code_too_long). Either is an answer
      // with its plain reason (mp-458 clause 6), not a reason to try again.
      if (e.status == 400) {
        final details = e.details;
        final tooLong = details is Map && details['error'] == 'code_too_long';
        return {'ok': false, 'reason': tooLong ? 'too_long' : 'not_found'};
      }
      throw switch (e.status) {
        401 || 403 => const CodeRedeemFailure.signInRequired(),
        _ => const CodeRedeemFailure.unavailable(),
      };
    } catch (e, st) {
      deps.logger.error(
        'redeem-code failed',
        context: 'CODES',
        error: e,
        stackTrace: st,
      );
      throw const CodeRedeemFailure.unavailable();
    }
  }
}
