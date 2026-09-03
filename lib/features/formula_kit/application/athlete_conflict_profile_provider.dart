import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_service.dart';
import '../../onboarding/domain/dietary_preference.dart';
import '../domain/formula_profile_conflict.dart';

part 'athlete_conflict_profile_provider.g.dart';

/// The athlete's allergy + diet db values, read once from the profile for the
/// formula-pin conflict surface (FP-4a/4b/7/8 —
/// `docs/ssot/spec/design/components/formula-pin-surface.md`).
///
/// Mirrors how the client plan solver reads the profile
/// (`ClientPlanService`: `authServiceProvider` → `getCurrentUser()` →
/// `allergies` / `dietaryPreference`). `none` normalizes to no diet
/// constraint. Read-only derived data — conflict *evaluation* stays in the
/// pure domain (`evaluateFormulaProfileConflict`).
@riverpod
Future<AthleteConflictProfile> athleteConflictProfile(Ref ref) async {
  final user = await ref.read(authServiceProvider).getCurrentUser();
  final diet = user?.dietaryPreference;
  return AthleteConflictProfile(
    allergyDbValues:
        user?.allergies.map((a) => a.dbValue).toList(growable: false) ??
        const [],
    dietDbValue: (diet == null || diet == DietaryPreference.none)
        ? null
        : diet.dbValue,
  );
}
