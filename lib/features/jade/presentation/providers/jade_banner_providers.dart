import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/meal_logging/data/meal_log_repository.dart';

part 'jade_banner_providers.g.dart';

/// True when the current user has at least one non-deleted meal log created
/// in the last 14 days (local Drift query — no network required).
///
/// Used by [JadeCoachBanner] to choose between baseline-tutorial copy and
/// default copy.  Degrades gracefully:
///   - loading  → false (show tutorial copy until data is available)
///   - no user  → false
///   - error    → false (never throws)
@riverpod
Future<bool> jadeHasBaseline(Ref ref) async {
  try {
    final userRepo = await ref.read(userRepositoryProvider.future);
    final user = await userRepo.getCurrentUser();
    final userId = user?.id;
    if (userId == null) return false;

    final since = DateTime.now().subtract(const Duration(days: 14));
    final count = await ref
        .read(mealLogRepositoryProvider)
        .countLogsSince(userId, since);
    return count > 0;
  } catch (_) {
    return false;
  }
}
