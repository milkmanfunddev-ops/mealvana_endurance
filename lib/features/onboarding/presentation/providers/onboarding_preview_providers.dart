import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../activities/domain/activity.dart';
import '../../../integrations/domain/integration.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../application/plan_preview_service.dart';
import '../../application/training_insight_service.dart';
import '../../domain/onboarding_integration_profile.dart';
import '../../domain/onboarding_plan_preview.dart';
import '../../domain/training_insights.dart';
import 'onboarding_controller.dart';

part 'onboarding_preview_providers.g.dart';

/// Key under which ConnectTrainingController stamps the temp user id used
/// for onboarding-time imports. Must match connect_training_controller.dart.
const _onboardingTempUserIdKey = 'onboarding_temp_user_id';

/// Hard ceiling on how long the plan-reveal loader waits for the
/// imported-workout digest before falling back to the generic preview
/// (§1b loader behavior in docs/features/onboarding-redesign/README.md).
const kOnboardingInsightTimeout = Duration(seconds: 10);

/// The computed plan preview plus the insights that personalized it, shared
/// by the plan-reveal and daily-preview screens so both render the same
/// numbers.
class OnboardingPreviewBundle {
  const OnboardingPreviewBundle({
    required this.preview,
    required this.insights,
  });

  final OnboardingPlanPreview preview;
  final TrainingInsights insights;
}

/// Every id the onboarding import might have written under, most likely
/// first.
///
/// ConnectTrainingController picks its id through a richer path than a
/// single lookup can reproduce: it prefers the LOCAL PROFILE id
/// (`user.id`) whenever one exists and looks real, only then the anonymous
/// `auth.uid`, and a temp UUID last. For a returning athlete the profile id
/// and the auth uid are not the same value, so reading under just one of
/// them silently finds nothing — the import is fine, we are looking in the
/// wrong place.
///
/// Rather than duplicate that decision tree (and drift from it again), read
/// under each candidate and take the first that actually holds data.
Future<List<String>> _candidateDataUserIds(Ref ref) async {
  final deps = ref.read(appExternalDepsProvider);
  final ids = <String>[];

  void add(String? id) {
    if (id != null && id.isNotEmpty && !ids.contains(id)) ids.add(id);
  }

  try {
    final profile = await ref
        .read(appDatabaseProvider)
        .userDao
        .getLocalUserProfile();
    add(profile?.id);
  } catch (_) {
    // No local profile yet (first run) — the ids below still apply.
  }
  add(deps.supabaseClient.auth.currentUser?.id);
  add(deps.sharedPreferences.getString(_onboardingTempUserIdKey));
  return ids;
}

/// Digest of the workouts imported during onboarding.
///
/// Recomputes whenever the draft changes (cheap local Drift read; fast-path
/// [TrainingInsights.none] when no platform was connected). Contract: never
/// throws — timeout or any failure Sentry-captures and falls back to the
/// generic digest so the plan reveal always renders.
@Riverpod(keepAlive: true)
Future<TrainingInsights> onboardingTrainingInsights(Ref ref) async {
  // Draft mutators call ref.notifyListeners(), so this re-runs after e.g.
  // recordConnectedProvider flips the connect state.
  ref.watch(onboardingControllerProvider);
  final draft = ref.read(onboardingControllerProvider.notifier).draft;
  if (draft.connectedProvider == null) return TrainingInsights.none;

  final sentry = ref.read(appExternalDepsProvider).sentry;
  try {
    return await _digestImportedActivities(
      ref,
    ).timeout(kOnboardingInsightTimeout);
  } catch (e, stackTrace) {
    // No silent failures — but also never a blocked/blank reveal: capture
    // and degrade to the generic preview.
    unawaited(
      sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'onboarding_training_insights',
        tags: {'feature': 'onboarding', 'step': 'plan_reveal'},
      ),
    );
    return TrainingInsights.none;
  }
}

Future<TrainingInsights> _digestImportedActivities(Ref ref) async {
  final candidates = await _candidateDataUserIds(ref);
  if (candidates.isEmpty) return TrainingInsights.none;

  // Reuse the existing date-range read (no new repository API): wide enough
  // to cover every provider's import window — completed Garmin history
  // backwards, planned FS/TP/VDOT/Runna calendars forwards. The digest
  // derives its own window span from the data.
  final now = DateTime.now();
  final repo = ref.read(activitiesRepositoryProvider);

  var readUnder = candidates.first;
  var activities = const <Activity>[];
  for (final candidate in candidates) {
    final rows = await repo.getActivitiesForDateRange(
      candidate,
      now.subtract(const Duration(days: 90)),
      now.add(const Duration(days: 366)),
    );
    if (rows.isNotEmpty) {
      readUnder = candidate;
      activities = rows;
      break;
    }
  }

  // Tag with the id we read under so the reveal's diagnostic sheet can show
  // whether an empty digest means "nothing was there" or "we looked in the
  // wrong place".
  return TrainingInsightService.digest(activities).withDataUserId(readUnder);
}

/// The plan preview both reveal screens render, personalized from imported
/// training data when the reliability gate passes. keepAlive + draft watch:
/// computed once per flow entry, cached across the two screens, recomputed
/// whenever any draft input changes.
@Riverpod(keepAlive: true)
Future<OnboardingPreviewBundle> onboardingPlanPreview(Ref ref) async {
  ref.watch(onboardingControllerProvider);
  final draft = ref.read(onboardingControllerProvider.notifier).draft;
  final insights = await ref.watch(onboardingTrainingInsightsProvider.future);
  return OnboardingPreviewBundle(
    preview: PlanPreviewService.buildPreview(draft, insights: insights),
    insights: insights,
  );
}

/// Athlete details from the platforms connected during onboarding, used to
/// pre-fill the personal-info and body-composition steps.
///
/// Per-field precedence, and the reason for it:
///
///  - **weight**: Garmin first (it is scale data, and the freshest), then
///    TrainingPeaks' profile figure.
///  - **birth year / gender**: TrainingPeaks only — it is the sole provider
///    that returns them.
///  - **name / email**: TrainingPeaks, then Final Surge. Deliberately NOT
///    Garmin or V.O2: those store the literal strings 'Garmin Connect' and
///    'V.O2' in `providerAthleteName`, so trusting them would write
///    "Garmin"/"Connect" into someone's name fields.
///
/// No provider reports height, so the height wheels keep their defaults.
///
/// Best-effort throughout: any failure resolves to an empty profile (no
/// autofill), never an error — a convenience must not block onboarding.
@Riverpod(keepAlive: true)
Future<OnboardingIntegrationProfile> onboardingIntegrationProfile(
  Ref ref,
) async {
  // Draft mutators call ref.notifyListeners(), so connecting a platform
  // (recordConnectedProvider) re-runs this. Without the watch, a keepAlive
  // provider first read before the connect would cache "nothing connected"
  // forever.
  ref.watch(onboardingControllerProvider);
  try {
    final repo = ref.read(integrationsRepositoryProvider);
    final candidates = await _candidateDataUserIds(ref);
    if (candidates.isEmpty) return OnboardingIntegrationProfile.empty;

    // Use the first id that actually has integrations — see
    // _candidateDataUserIds for why more than one is in play.
    var userId = candidates.first;
    for (final candidate in candidates) {
      final existing = await repo.getIntegrationsForUser(candidate);
      if (existing.any((i) => i.isActive)) {
        userId = candidate;
        break;
      }
    }

    Future<IntegrationModel?> active(String provider) async {
      final integration = await repo.getIntegration(userId, provider);
      return (integration != null && integration.isActive) ? integration : null;
    }

    final garmin = await active('garmin');
    final trainingPeaks = await active('training_peaks');
    final finalSurge = await active('final_surge');

    // Weight: scale data beats a self-reported profile figure.
    final weightSource = garmin?.providerAthleteWeightLbs != null
        ? garmin
        : (trainingPeaks?.providerAthleteWeightLbs != null
              ? trainingPeaks
              : null);

    // Name/email: only providers that return a real athlete identity.
    final identity = trainingPeaks?.providerAthleteName != null
        ? trainingPeaks
        : (finalSurge?.providerAthleteName != null ? finalSurge : null);
    final name = OnboardingIntegrationProfile.splitFullName(
      identity?.providerAthleteName,
    );

    final email = trainingPeaks?.providerAthleteEmail?.trim().isNotEmpty == true
        ? trainingPeaks!.providerAthleteEmail!.trim()
        : (finalSurge?.providerAthleteEmail?.trim().isNotEmpty == true
              ? finalSurge!.providerAthleteEmail!.trim()
              : null);

    return OnboardingIntegrationProfile(
      firstName: name.first,
      lastName: name.last,
      email: email,
      gender: OnboardingIntegrationProfile.parseGender(
        trainingPeaks?.providerAthleteGender,
      ),
      birthYear: trainingPeaks?.providerAthleteBirthday?.year,
      weightLbs: weightSource?.providerAthleteWeightLbs,
      // Whoever supplied the personal details on that screen: the identity
      // provider when there's a name/email, else TrainingPeaks when it was
      // only good for gender/birth year. Never left null while something
      // was filled — an unattributed pre-fill is the thing to avoid.
      detailsSource:
          identity?.providerDisplayName ??
          ((trainingPeaks?.providerAthleteGender != null ||
                  trainingPeaks?.providerAthleteBirthday != null)
              ? trainingPeaks?.providerDisplayName
              : null),
      weightSource: weightSource?.providerDisplayName,
    );
  } catch (_) {
    // Autofill is a convenience; the forms keep their defaults.
    return OnboardingIntegrationProfile.empty;
  }
}

/// Weight (lbs) from [onboardingIntegrationProfile], kept as its own
/// provider so the body-composition wheel can listen to just that value.
@Riverpod(keepAlive: true)
Future<double?> onboardingIntegrationWeightLbs(Ref ref) async =>
    (await ref.watch(onboardingIntegrationProfileProvider.future)).weightLbs;
