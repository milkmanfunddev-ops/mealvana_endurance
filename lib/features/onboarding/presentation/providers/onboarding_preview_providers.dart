import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../activities/data/activities_repository.dart';
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

/// The user id the onboarding auto-import wrote activities under: the (often
/// anonymous) Supabase auth uid when a session exists, else the persisted
/// temp uid — mirroring ConnectTrainingController's id resolution.
String? _onboardingDataUserId(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  final authUserId = deps.supabaseClient.auth.currentUser?.id;
  if (authUserId != null && authUserId.isNotEmpty) return authUserId;
  return deps.sharedPreferences.getString(_onboardingTempUserIdKey);
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
  final userId = _onboardingDataUserId(ref);
  if (userId == null) return TrainingInsights.none;

  // Reuse the existing date-range read (no new repository API): wide enough
  // to cover every provider's import window — completed Garmin history
  // backwards, planned FS/TP/VDOT/Runna calendars forwards. The digest
  // derives its own window span from the data.
  final now = DateTime.now();
  final activities = await ref
      .read(activitiesRepositoryProvider)
      .getActivitiesForDateRange(
        userId,
        now.subtract(const Duration(days: 90)),
        now.add(const Duration(days: 366)),
      );
  // Tag with the id we read under so the reveal's diagnostic sheet can show
  // whether an empty digest means "nothing was there" or "we looked in the
  // wrong place".
  return TrainingInsightService.digest(activities).withDataUserId(userId);
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
  final userId = _onboardingDataUserId(ref);
  if (userId == null) return OnboardingIntegrationProfile.empty;

  try {
    final repo = ref.read(integrationsRepositoryProvider);

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
      nameSource: identity?.providerDisplayName,
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
