import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/analytics/internal_user_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../data/credits_repository.dart';
import '../data/revenuecat_service.dart';
import '../domain/credit_packs.dart';
import 'credits_controller.dart';

part 'purchase_controller.g.dart';

/// What actually happened during [PurchaseController.buy].
///
/// The sheet used to infer this from a wallet-balance delta, which cannot tell
/// "the user cancelled" from "the store errored" from "the purchase went
/// through but our webhook has not credited it yet" — so all three rendered as
/// "Purchase failed. Nothing was charged.", including the one case where the
/// user *had* been charged. Each outcome now carries its own honest message.
enum PurchaseOutcome {
  /// Store confirmed the purchase and the wallet balance went up.
  credited,

  /// Store confirmed the purchase, but the balance had not moved before we
  /// stopped polling. The money is real; the grant is late or the
  /// `revenuecat-webhook` never landed. Never tell the user nothing was
  /// charged here.
  purchasedButNotCredited,

  /// User dismissed the store sheet. Not an error.
  cancelled,

  /// Nobody is signed in, so there is no wallet to credit. Refused before the
  /// store was contacted — a purchase here would take real money and credit
  /// nobody, because the webhook maps `app_user_id` onto `auth.users.id`.
  notSignedIn,

  /// The session is a Supabase *anonymous* user. Refused before the store was
  /// contacted: only the link-in-place "Create Account" upgrade preserves the
  /// anonymous `auth.users.id` that the webhook would credit — signing in to
  /// an existing account swaps the id and strands the purchase forever. The
  /// UI should route the user to account creation, after which buying works.
  requiresAccount,

  /// The store rejected the purchase, or the SDK was never configured.
  failed,
}

/// Provides the RevenueCat `credits` offering.
///
/// Returns null when the SDK is not configured, the user has RC disabled, or
/// on any network error — the UI should render a disabled / coming-soon state
/// in that case.
@riverpod
Future<Offering?> aiCreditOffering(Ref ref) async {
  final service = ref.read(revenueCatServiceProvider);
  final offerings = await service.getOfferings();
  return offerings?.getOffering('credits');
}

/// The packages the current build is allowed to *display*, in offering order.
///
/// This is [aiCreditOffering] minus the tester-only SKUs
/// ([kTesterOnlyProductIds]): the $0.99 pipeline-test pack exists in the store
/// so the whole purchase path (StoreKit → RevenueCat → webhook → wallet) can
/// be exercised end to end, but only devices with tester mode ON (the 7-tap
/// switch, defaulting on for IS_INTERNAL/debug builds) may see it. Filtering
/// lives here — not in the sheet or the screen — so no future purchase
/// surface can forget it.
@riverpod
Future<List<Package>> visibleCreditPackages(Ref ref) async {
  // Watch before the await so the provider is subscribed even if the offering
  // fetch is slow, and so toggling tester mode recomputes the list. Tester-SKU
  // visibility follows the tester-mode switch ONLY — no isDevelopment
  // short-circuit, so toggling it off hides the $0.99 pack on dev builds too.
  final showTesterSkus = ref.watch(internalDeviceFlagProvider);

  final offering = await ref.watch(aiCreditOfferingProvider.future);
  if (offering == null) return const [];

  return offering.availablePackages
      .where(
        (p) =>
            showTesterSkus ||
            !kTesterOnlyProductIds.contains(p.storeProduct.identifier),
      )
      .toList();
}

/// Manages the purchase and restore flows for AI credit packs.
///
/// State is `AsyncValue<void>`:
/// - `AsyncData(null)` — idle / last operation succeeded.
/// - `AsyncLoading()` — purchase / restore in progress.
/// - `AsyncError(...)` — the last operation failed with a user-visible message.
///
/// The UI should watch state to show a loading indicator or surface errors.
///
/// **keepAlive is load-bearing, not an optimisation.** Under autoDispose this
/// controller was torn down the moment `buy()` hit its first await, because the
/// token top-up sheet only `ref.read`s the notifier — a read creates no
/// subscription. Every `ref` use after the store call then threw
/// `UnmountedRefException`, so a *successful* purchase crashed on the way to
/// the celebration screen. (`buy_credits_screen` watches the provider, which is
/// why the same code never failed there.) A purchase in flight must outlive any
/// widget that started it.
@Riverpod(keepAlive: true)
class PurchaseController extends _$PurchaseController {
  RevenueCatService get _rcService => ref.read(revenueCatServiceProvider);

  @override
  FutureOr<void> build() {
    // Idle initial state.
    return null;
  }

  /// Purchase [pkg] from the native store.
  ///
  /// On success, polls [CreditsController] (up to 5 times, 1.5s apart) until
  /// the server-side wallet balance increases — the RevenueCat webhook may
  /// take a few seconds to credit the account.
  Future<PurchaseOutcome> buy(Package pkg) async {
    state = const AsyncLoading();

    final sku = pkg.storeProduct.identifier;
    final sentry = ref.read(sentryReporterProvider);
    var outcome = PurchaseOutcome.failed;

    // Hard precondition: never contact the store without a signed-in user.
    // RevenueCat happily transacts against an anonymous `$RCAnonymousID:…`
    // customer, and the webhook then has no `auth.users.id` to credit — the
    // user is charged and the tokens land nowhere recoverable.
    final repo = ref.read(creditsRepositoryProvider);
    final userId = repo.currentUserId;
    if (userId == null || userId.isEmpty) {
      state = const AsyncData(null);
      await sentry.reportCriticalError(
        StateError('Purchase attempted with no signed-in user (sku: $sku)'),
        context: 'ai_credits',
        tags: {'rc_operation': 'buy_unauthenticated', 'sku': sku},
      );
      return PurchaseOutcome.notSignedIn;
    }

    // Anonymous sessions must create an account before buying. Not a Sentry
    // error — it is an expected funnel step — but leave a breadcrumb so a
    // purchase-drop-off investigation can see it happened.
    if (repo.isAnonymousUser) {
      state = const AsyncData(null);
      sentry.addBreadcrumb(
        message: 'purchase blocked: anonymous session',
        category: 'ai_credits',
        data: {'sku': sku},
      );
      return PurchaseOutcome.requiresAccount;
    }

    // Re-assert identity immediately before buying. `logIn` runs once at
    // startup, so anyone who signed in *after* launch still carried the
    // anonymous RevenueCat id. It is idempotent and cheap.
    await _rcService.logIn(userId);

    state = await AsyncValue.guard(() async {
      final previousBalance = await _currentBalance();
      final success = await _rcService.purchase(pkg);

      if (!success) {
        // RevenueCatService has already reported the distinction (cancel is a
        // breadcrumb, a store rejection is a Sentry error), so trust its
        // return value and do not double-report here.
        outcome = PurchaseOutcome.cancelled;
        return;
      }

      // Poll until the webhook has credited the wallet.
      final credited = await _pollForBalanceUpdate(
        previousBalance: previousBalance,
      );
      outcome = credited
          ? PurchaseOutcome.credited
          : PurchaseOutcome.purchasedButNotCredited;

      if (!credited) {
        // The user paid and we did not deliver. This is the highest-severity
        // failure in the whole feature and it is completely invisible from the
        // client side otherwise — the store is happy, the app just shows a
        // stale balance.
        await sentry.reportCriticalError(
          StateError(
            'RevenueCat purchase completed but the wallet balance never '
            'increased after polling (sku: $sku)',
          ),
          context: 'ai_credits',
          tags: {
            'rc_operation': 'purchase_not_credited',
            'sku': sku,
            'previous_balance': previousBalance.toString(),
          },
        );
      }
    });

    if (state is AsyncError) {
      final err = state as AsyncError;
      outcome = PurchaseOutcome.failed;
      await sentry.reportCriticalError(
        err.error,
        stackTrace: err.stackTrace,
        context: 'ai_credits',
        tags: {'rc_operation': 'buy', 'sku': sku},
      );
    }

    return outcome;
  }

  /// Restore previous consumable purchases.
  ///
  /// RevenueCat handles server-side fulfillment; after restoring we refresh
  /// the wallet once to surface any newly credited balance.
  Future<void> restore() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _rcService.restore();
      // Give the server a moment to process, then refresh once.
      await Future<void>.delayed(const Duration(seconds: 2));
      await ref.read(creditsControllerProvider.notifier).refresh();
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<int> _currentBalance() async {
    try {
      final wallet = await ref.read(creditsControllerProvider.future);
      return wallet.balance;
    } catch (_) {
      return 0;
    }
  }

  /// Poll [CreditsController] up to [maxAttempts] times until the balance
  /// exceeds [previousBalance], or until attempts are exhausted.
  ///
  /// Returns true if the balance increased, false if the attempts ran out.
  Future<bool> _pollForBalanceUpdate({
    required int previousBalance,
    int maxAttempts = 5,
    Duration interval = const Duration(milliseconds: 1500),
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future<void>.delayed(interval);
      ref.invalidate(creditsControllerProvider);

      try {
        final wallet = await ref.read(creditsControllerProvider.future);
        if (wallet.balance > previousBalance) {
          debugPrint(
            '[PurchaseController] balance updated '
            '($previousBalance → ${wallet.balance}) '
            'after ${attempt + 1} attempt(s)',
          );
          return true;
        }
      } catch (e) {
        // Not fatal on its own — a later attempt may still succeed — so this
        // is a breadcrumb. Exhausting every attempt is what gets reported.
        debugPrint(
          '[PurchaseController] poll attempt ${attempt + 1} error: $e',
        );
        ref
            .read(sentryReporterProvider)
            .addBreadcrumb(
              message: 'credit balance poll attempt failed',
              category: 'ai_credits',
              data: {'attempt': attempt + 1, 'error': e.toString()},
            );
      }
    }

    // Final refresh regardless — let the controller settle.
    ref.invalidate(creditsControllerProvider);
    // Deliberately not behind kDebugMode: release-mode dev builds are the ones
    // testers run, and this line is the difference between a diagnosable
    // "purchase went through, grant never arrived" and total silence.
    debugPrint(
      '[PurchaseController] balance poll exhausted after $maxAttempts attempt(s)',
    );
    return false;
  }
}
