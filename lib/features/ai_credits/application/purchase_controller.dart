import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/revenuecat_service.dart';
import 'credits_controller.dart';

part 'purchase_controller.g.dart';

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

/// Manages the purchase and restore flows for AI credit packs.
///
/// State is `AsyncValue<void>`:
/// - `AsyncData(null)` — idle / last operation succeeded.
/// - `AsyncLoading()` — purchase / restore in progress.
/// - `AsyncError(...)` — the last operation failed with a user-visible message.
///
/// The UI should watch state to show a loading indicator or surface errors.
@riverpod
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
  Future<void> buy(Package pkg) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final previousBalance = await _currentBalance();
      final success = await _rcService.purchase(pkg);

      if (!success) {
        // User cancelled or purchase was rejected — treat as no-op.
        return;
      }

      // Poll until the webhook has credited the wallet.
      await _pollForBalanceUpdate(previousBalance: previousBalance);
    });
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
  Future<void> _pollForBalanceUpdate({
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
          if (kDebugMode) {
            debugPrint(
              '[PurchaseController] balance updated '
              '($previousBalance → ${wallet.balance}) '
              'after ${attempt + 1} attempt(s)',
            );
          }
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[PurchaseController] poll attempt ${attempt + 1} error: $e',
          );
        }
      }
    }

    // Final refresh regardless — let the controller settle.
    ref.invalidate(creditsControllerProvider);
    if (kDebugMode) {
      debugPrint(
        '[PurchaseController] balance poll exhausted after $maxAttempts attempt(s)',
      );
    }
  }
}
