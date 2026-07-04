import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database_provider.dart';
import '../../features/nutrition_plan/domain/run_parameters.dart';
import 'user_id_provider.dart';

part 'unit_system_provider.g.dart';

/// Provides the current user's preferred [UnitSystem] (imperial/metric).
///
/// Sourced from the user profile: `users.unit_system` on Supabase, mirrored
/// in Drift's `user_profiles.unit_system` column (default `'imperial'`).
/// This is the single shared entry point for reading unit-system preference
/// - callers should use this instead of reaching into settings state or the
/// user profile directly.
///
/// Usage:
/// ```dart
/// final unitSystem = ref.watch(unitSystemProvider).valueOrNull ?? UnitSystem.imperial;
/// final useMetric = unitSystem == UnitSystem.metric;
/// ```
@riverpod
Future<UnitSystem> unitSystem(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);

  final userId = await ref.watch(userIdProvider.future);
  final profile = await database.userDao.getUserProfileById(userId);

  return profile?.unitSystem ?? UnitSystem.imperial;
}
