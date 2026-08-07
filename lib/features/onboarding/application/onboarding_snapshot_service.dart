import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/logging_service.dart';
import '../../auth/domain/user_preferences.dart';
import '../data/onboarding_survey_repository.dart';
import '../domain/onboarding_draft.dart';

part 'onboarding_snapshot_service.g.dart';

@riverpod
OnboardingSnapshotService onboardingSnapshotService(Ref ref) {
  return OnboardingSnapshotService();
}

/// Local safety net for the anonymous-user data-loss hazard
/// (docs/features/onboarding-redesign/README.md §7).
///
/// The Drift upgrade strategy is delete-and-recreate + re-pull from Supabase.
/// Anonymous users normally survive that (their rows ARE pushed under a real
/// anonymous auth session), but two residual failure modes remain: the device
/// is offline at upgrade time (dirty rows can't upload before the delete), or
/// the anonymous Supabase session was lost (keychain wipe/reinstall — re-pull
/// returns nothing). This snapshot is a compact JSON copy of exactly the data
/// onboarding creates, written OUTSIDE Drift (SharedPreferences) at
/// `saveAllOnboardingData` success, so a post-recreate startup that finds no
/// user row can re-import it locally with `needs_upload = true`.
///
/// Scope is deliberately narrow: profile essentials + survey answers. It is
/// not a general backup system — broader anonymous upgrade safety is its own
/// future workstream.
class OnboardingSnapshotService {
  static const prefsKey = 'onboarding_snapshot_v1';

  /// Persist the snapshot. Failures are swallowed after logging — the
  /// snapshot is a best-effort net under an already-successful save and must
  /// never fail onboarding itself.
  Future<void> writeSnapshot({
    required UserProfile profile,
    required OnboardingDraft draft,
    AppLogger? logger,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKey,
        jsonEncode({
          'version': 1,
          'written_at': DateTime.now().toIso8601String(),
          'profile': profile.toJson(),
          'survey': {
            'sports': [for (final s in draft.sports) s.dbValue],
            'goals': [for (final g in draft.goals) g.dbValue],
            'pitfalls': [for (final p in draft.pitfalls) p.dbValue],
          },
        }),
      );
    } catch (e, stackTrace) {
      logger?.warning(
        'Failed to write onboarding snapshot (non-fatal)',
        context: 'ONBOARDING_SNAPSHOT',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Read and decode the stored snapshot, or null when absent/corrupt.
  Future<OnboardingSnapshot?> readSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final profileJson = Map<String, dynamic>.from(json['profile'] as Map);
      final surveyJson = Map<String, dynamic>.from(
        json['survey'] as Map? ?? const {},
      );
      return OnboardingSnapshot(
        profile: UserProfile.fromJson(profileJson),
        sports: List<String>.from(surveyJson['sports'] as List? ?? const []),
        goals: List<String>.from(surveyJson['goals'] as List? ?? const []),
        pitfalls: List<String>.from(
          surveyJson['pitfalls'] as List? ?? const [],
        ),
        writtenAt:
            DateTime.tryParse(json['written_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      // Corrupt snapshot: drop it rather than crash startup.
      await prefs.remove(prefsKey);
      return null;
    }
  }

  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}

/// Decoded snapshot payload.
class OnboardingSnapshot {
  const OnboardingSnapshot({
    required this.profile,
    required this.sports,
    required this.goals,
    required this.pitfalls,
    required this.writtenAt,
  });

  final UserProfile profile;
  final List<String> sports;
  final List<String> goals;
  final List<String> pitfalls;
  final DateTime writtenAt;

  /// Rebuild a minimal draft (survey fields only) for re-import through
  /// [OnboardingSurveyRepository.saveSurveyFromDraft].
  OnboardingDraft toSurveyDraft() {
    return OnboardingDraft(
      sports: {
        for (final s in sports)
          if (OnboardingSport.fromDbValue(s) case final OnboardingSport v) v,
      },
      goals: {
        for (final g in goals)
          if (OnboardingGoal.fromDbValue(g) case final OnboardingGoal v) v,
      },
      pitfalls: {
        for (final p in pitfalls)
          if (OnboardingPitfall.fromDbValue(p) case final OnboardingPitfall v)
            v,
      },
    );
  }
}
