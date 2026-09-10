import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/app_config.dart';
import '../data/kroger_repository.dart';

/// Dev stays visible per deployment policy. Production requires an explicit
/// release flag; the server independently enforces KROGER_ENABLED and Pro.
final krogerShoppingEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(appConfigProvider).isDevelopment ||
      const bool.fromEnvironment('KROGER_SHOPPING_ENABLED'),
);

/// Coverage: whether Kroger serves the shopper's delivery area at all.
///
/// Answered with the application token, so it costs no Kroger sign-in and can
/// be asked of a shopper who has never connected an account. `null` is
/// *unknown*, which is not the same as *not covered* — a check that could not
/// be made must never take the feature away from someone Kroger can serve.
final krogerCoverageProvider = FutureProvider<bool?>((ref) async {
  if (!ref.watch(krogerShoppingEnabledProvider)) return null;
  // Coverage is a fact about a market, and Kroger meters Locations by the day.
  // Asking again every time the Shopping tab is rebuilt spends that budget for
  // an answer that has not changed.
  ref.keepAlive();
  try {
    final result = await ref
        .watch(krogerRepositoryProvider)
        .remote
        .call('coverage');
    return result['covered'] as bool?;
  } catch (_) {
    // Every failure is the same answer: unknown. Kroger being unreachable,
    // rate limiting us, or not being configured says nothing about whether it
    // delivers to this shopper.
    return null;
  }
});

/// Whether to offer Shop with Kroger at all. A shopper Kroger cannot serve is
/// never shown the entry point — withheld while Coverage is still unanswered
/// too, so it cannot appear and then vanish under them. Any answer that is not
/// a "no", including a check that failed, shows it.
final krogerEntryVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(krogerShoppingEnabledProvider)) return false;
  final coverage = ref.watch(krogerCoverageProvider);
  return !coverage.isLoading && coverage.value != false;
});
