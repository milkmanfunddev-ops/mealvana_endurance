import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/app_config.dart';
import '../../../activities/data/activities_repository.dart';
import '../../application/change_detection_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../application/final_surge_oauth_service.dart';
import '../../application/final_surge_sync_service.dart';
import '../../application/final_surge_transformer.dart';
import '../../application/garmin_oauth_service.dart';
import '../../application/runna_ics_parser.dart';
import '../../application/runna_sync_service.dart';
import '../../application/runna_transformer.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../application/training_peaks_transformer.dart';
import '../../application/vdot_oauth_service.dart';
import '../../application/vdot_sync_service.dart';
import '../../application/vdot_transformer.dart';
import '../../data/final_surge_api_client.dart';
import '../../data/integrations_repository.dart';
import '../../data/runna_ics_client.dart';
import '../../data/training_peaks_api_client.dart';
import '../../data/vdot_api_client.dart';
import '../../domain/integration.dart';

part 'integrations_providers.g.dart';

// =============================================================================
// GARMIN BODY COMP DATA CLASS
// =============================================================================

/// Latest body composition measurement received from Garmin Connect.
class GarminBodyCompData {
  const GarminBodyCompData({
    this.weightKg,
    this.bodyFatPct,
    required this.measurementTime,
  });

  /// Weight in kilograms derived from Garmin weightInGrams.
  final double? weightKg;

  /// Body fat percentage from Garmin percentFat.
  final double? bodyFatPct;

  /// UTC timestamp of the body-comp measurement.
  final DateTime measurementTime;
}

// =============================================================================
// GARMIN BODY COMP AUTHORITY HELPERS (pure functions — not providers)
// =============================================================================

/// Returns true if Garmin's body composition data should be treated as more
/// authoritative than the user's manually-entered weight.
///
/// Rules mirror `resolveAthleteProfile` in the edge function:
///   1. No Garmin data → false (user value stands).
///   2. Garmin data is more than 30 days old → false (stale, reject).
///   3. User has no weight → true (Garmin fills the gap).
///   4. Garmin measurement is at or after the user's last update → true.
///   5. User's current weight matches Garmin's (within 0.5 kg) → true.
///      This rule catches the case where the server-side mirror already
///      copied Garmin's value into `users.weight_pounds` and bumped the
///      `_updated_at` timestamp to Garmin's measurement time. Even if local
///      Drift sync hasn't caught up to that updated_at, value-equality
///      proves the displayed weight came from Garmin.
///
/// The "at or after" check (not strict "after") is intentional: when the
/// server-side mirror in garmin-push updates `users.weight_pounds` from a
/// Garmin reading, it bumps `weight_pounds_updated_at` to the Garmin
/// measurement time. Equal timestamps therefore still mean "Garmin is the
/// source of truth", and the UI should attribute accordingly.
bool isGarminAuthoritativeForWeight({
  required GarminBodyCompData? garmin,
  required double? userWeightKg,
  required DateTime? userUpdatedAt,
  DateTime? now,
}) {
  if (garmin == null || garmin.weightKg == null) return false;
  final reference = now ?? DateTime.now().toUtc();
  final ageDays = reference.difference(garmin.measurementTime).inDays;
  if (ageDays > 30) return false;
  if (userWeightKg == null || userUpdatedAt == null) return true;
  if (!garmin.measurementTime.isBefore(userUpdatedAt)) return true;
  // Value-equality fallback: if the user's stored weight matches Garmin's
  // reading within rounding tolerance, Garmin is the source even if our
  // timestamps look out of order (e.g. local Drift lagging Supabase).
  return (userWeightKg - garmin.weightKg!).abs() < 0.5;
}

/// Returns true if Garmin's body composition data should be treated as more
/// authoritative than the user's manually-entered body fat percentage.
///
/// Same staleness and precedence rules as [isGarminAuthoritativeForWeight],
/// plus a value-equality fallback (within 0.3 percentage points).
bool isGarminAuthoritativeForBodyFat({
  required GarminBodyCompData? garmin,
  required double? userBodyFatPct,
  required DateTime? userUpdatedAt,
  DateTime? now,
}) {
  if (garmin == null || garmin.bodyFatPct == null) return false;
  final reference = now ?? DateTime.now().toUtc();
  final ageDays = reference.difference(garmin.measurementTime).inDays;
  if (ageDays > 30) return false;
  if (userBodyFatPct == null || userUpdatedAt == null) return true;
  if (!garmin.measurementTime.isBefore(userUpdatedAt)) return true;
  return (userBodyFatPct - garmin.bodyFatPct!).abs() < 0.3;
}

/// Provider for app package info (version, build number, etc.)
@Riverpod(keepAlive: true)
Future<PackageInfo> packageInfo(Ref ref) async {
  return PackageInfo.fromPlatform();
}

/// Base callback URL scheme for OAuth
const _baseCallbackScheme = 'com.milkman.mealvanaendurance';
const _androidDevCallbackScheme = 'com.milkman.mealvanaendurance.dev';

/// Final Surge keeps a single callback scheme across environments due provider constraints.
String _getFinalSurgeCallbackScheme() {
  return _baseCallbackScheme;
}

/// TrainingPeaks uses a flavor-specific scheme on Android to avoid dev/prod collisions
/// when both app variants are installed on the same device.
String _getTrainingPeaksCallbackScheme(bool isDev) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && isDev) {
    return _androidDevCallbackScheme;
  }
  return _baseCallbackScheme;
}

// =============================================================================
// DATA LAYER PROVIDERS
// =============================================================================

/// Provider for Final Surge API client
@Riverpod(keepAlive: true)
FinalSurgeApiClient finalSurgeApiClient(Ref ref) {
  final config = ref.watch(appConfigProvider);
  return FinalSurgeApiClient(
    clientId: config.finalSurgeClientId,
    clientSecret: config.finalSurgeClientSecret,
  );
}

/// Provider for integrations repository
@Riverpod(keepAlive: true)
IntegrationsRepository integrationsRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final deps = ref.watch(appExternalDepsProvider);
  return IntegrationsRepository(
    database: database,
    supabase: Supabase.instance.client,
    logger: deps.logger,
    sentry: deps.sentry,
  );
}

// =============================================================================
// APPLICATION LAYER PROVIDERS
// =============================================================================

/// Provider for Final Surge OAuth service
@Riverpod(keepAlive: true)
FinalSurgeOAuthService finalSurgeOAuthService(Ref ref) {
  final config = ref.watch(appConfigProvider);
  final apiClient = ref.watch(finalSurgeApiClientProvider);
  final repository = ref.watch(integrationsRepositoryProvider);

  return FinalSurgeOAuthService(
    apiClient: apiClient,
    repository: repository,
    clientId: config.finalSurgeClientId,
    callbackUrlScheme: _getFinalSurgeCallbackScheme(),
  );
}

/// Provider for Final Surge transformer
@Riverpod(keepAlive: true)
FinalSurgeTransformer finalSurgeTransformer(Ref ref) {
  return const FinalSurgeTransformer();
}

/// Provider for Final Surge sync service
@Riverpod(keepAlive: true)
FinalSurgeSyncService finalSurgeSyncService(Ref ref) {
  final apiClient = ref.watch(finalSurgeApiClientProvider);
  final integrationsRepository = ref.watch(integrationsRepositoryProvider);
  final activitiesRepository = ref.watch(activitiesRepositoryProvider);
  final transformer = ref.watch(finalSurgeTransformerProvider);
  final changeDetectionService = ref.watch(changeDetectionServiceProvider);

  return FinalSurgeSyncService(
    apiClient: apiClient,
    integrationsRepository: integrationsRepository,
    activitiesRepository: activitiesRepository,
    transformer: transformer,
    changeDetectionService: changeDetectionService,
    analytics: ref.watch(analyticsTrackerProvider),
  );
}

// =============================================================================
// STATE PROVIDERS
// =============================================================================

/// Provider to get Final Surge integration for a user
@riverpod
Future<IntegrationModel?> finalSurgeIntegration(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository.getIntegration(userId, 'final_surge');
}

/// Provider to check if Final Surge is connected
@riverpod
Future<bool> isFinalSurgeConnected(Ref ref, String userId) async {
  final integration = await ref.watch(
    finalSurgeIntegrationProvider(userId).future,
  );
  return integration?.isActive ?? false;
}

/// Provider for all user integrations
@riverpod
Future<List<IntegrationModel>> userIntegrations(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository.getIntegrationsForUser(userId);
}

// =============================================================================
// TRAININGPEAKS PROVIDERS
// =============================================================================

/// Provider for TrainingPeaks API client
@Riverpod(keepAlive: true)
Future<TrainingPeaksApiClient> trainingPeaksApiClient(Ref ref) async {
  final config = ref.watch(appConfigProvider);
  final packageInfoData = await ref.watch(packageInfoProvider.future);
  return TrainingPeaksApiClient(
    clientId: config.trainingPeaksClientId,
    clientSecret: config.trainingPeaksClientSecret,
    appVersion: packageInfoData.version,
    useSandbox: config.trainingPeaksUseSandbox,
  );
}

/// Provider for TrainingPeaks transformer
@Riverpod(keepAlive: true)
TrainingPeaksTransformer trainingPeaksTransformer(Ref ref) {
  return const TrainingPeaksTransformer();
}

/// Provider for TrainingPeaks OAuth service
@Riverpod(keepAlive: true)
Future<TrainingPeaksOAuthService> trainingPeaksOAuthService(Ref ref) async {
  final config = ref.watch(appConfigProvider);
  final apiClient = await ref.watch(trainingPeaksApiClientProvider.future);
  final repository = ref.watch(integrationsRepositoryProvider);

  return TrainingPeaksOAuthService(
    apiClient: apiClient,
    repository: repository,
    clientId: config.trainingPeaksClientId,
    useSandbox: config.trainingPeaksUseSandbox,
    callbackUrlScheme: _getTrainingPeaksCallbackScheme(config.isDevelopment),
  );
}

/// Provider for TrainingPeaks sync service
@Riverpod(keepAlive: true)
Future<TrainingPeaksSyncService> trainingPeaksSyncService(Ref ref) async {
  final apiClient = await ref.watch(trainingPeaksApiClientProvider.future);
  final integrationsRepository = ref.watch(integrationsRepositoryProvider);
  final activitiesRepository = ref.watch(activitiesRepositoryProvider);
  final transformer = ref.watch(trainingPeaksTransformerProvider);
  final changeDetectionService = ref.watch(changeDetectionServiceProvider);

  return TrainingPeaksSyncService(
    apiClient: apiClient,
    integrationsRepository: integrationsRepository,
    activitiesRepository: activitiesRepository,
    transformer: transformer,
    changeDetectionService: changeDetectionService,
    analytics: ref.watch(analyticsTrackerProvider),
  );
}

/// Provider to get TrainingPeaks integration for a user
@riverpod
Future<IntegrationModel?> trainingPeaksIntegration(
  Ref ref,
  String userId,
) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository.getIntegration(userId, 'training_peaks');
}

/// Provider to check if TrainingPeaks is connected
@riverpod
Future<bool> isTrainingPeaksConnected(Ref ref, String userId) async {
  final integration = await ref.watch(
    trainingPeaksIntegrationProvider(userId).future,
  );
  return integration?.isActive ?? false;
}

// =============================================================================
// GARMIN CONNECT PROVIDERS
// =============================================================================

/// Provider for Garmin Connect OAuth service
///
/// Garmin is push-only — no sync service or API client needed.
/// Activities arrive automatically via server-side push.
@Riverpod(keepAlive: true)
GarminOAuthService garminOAuthService(Ref ref) {
  final config = ref.watch(appConfigProvider);
  final repository = ref.watch(integrationsRepositoryProvider);
  final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
  return GarminOAuthService(
    repository: repository,
    supabaseClient: supabaseClient,
    clientId: config.garminClientId,
    clientSecret: config.garminClientSecret,
    redirectUri: config.garminRedirectUri,
    callbackUrlScheme: _baseCallbackScheme,
  );
}

/// Provider to get Garmin Connect integration for a user
@riverpod
Future<IntegrationModel?> garminIntegration(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository.getIntegration(userId, 'garmin');
}

/// Provider to check if Garmin Connect is connected
@riverpod
Future<bool> isGarminConnected(Ref ref, String userId) async {
  final integration = await ref.watch(
    garminIntegrationProvider(userId).future,
  );
  return integration?.isActive ?? false;
}

/// Fetches the latest body composition record pushed by Garmin for [userId].
///
/// Queries the `garmin_health_data` table directly via Supabase (service-role
/// reads are gated by RLS on the authenticated user's JWT). Returns null when
/// Garmin is not connected, or no body-comp data has been received yet.
@riverpod
Future<GarminBodyCompData?> garminLastBodyComp(
  Ref ref,
  String userId,
) async {
  final supabase = ref.read(appExternalDepsProvider).supabaseClient;

  // First confirm Garmin is actually connected for this user.
  final isConnected = await ref.watch(isGarminConnectedProvider(userId).future);
  if (!isConnected) return null;

  try {
    // Look up the Garmin userId from our mapping table so we can query health data.
    final mappingResponse = await supabase
        .from('garmin_user_mappings')
        .select('garmin_user_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (mappingResponse == null) return null;

    final garminUserId = mappingResponse['garmin_user_id'] as String?;
    if (garminUserId == null) return null;

    // Fetch the most recent body_composition record for this Garmin user.
    final response = await supabase
        .from('garmin_health_data')
        .select('data, created_at')
        .eq('garmin_user_id', garminUserId)
        .eq('data_type', 'body_composition')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    final measurementTimeSec =
        (data['measurement_time_seconds'] as num?)?.toInt();
    if (measurementTimeSec == null) return null;

    final measurementTime = DateTime.fromMillisecondsSinceEpoch(
      measurementTimeSec * 1000,
      isUtc: true,
    );

    final weightGrams = (data['weight_grams'] as num?)?.toDouble();
    final weightKg = weightGrams != null ? weightGrams / 1000.0 : null;
    final bodyFatPct = (data['percent_fat'] as num?)?.toDouble();

    return GarminBodyCompData(
      weightKg: weightKg,
      bodyFatPct: bodyFatPct,
      measurementTime: measurementTime,
    );
  } catch (_) {
    return null;
  }
}

// =============================================================================
// V.O2 (VDOT) PROVIDERS
// =============================================================================

/// Redirect URI sent to V.O2 during the authorize request. Registered with
/// VDOT (info@vdoto2.com). Shared scheme with TP/FS/Garmin — VDOT
/// distinguishes callbacks by the `state` parameter rather than the path.
const _vdotRedirectUri = '$_baseCallbackScheme://callback';

/// Provider for the V.O2 API client (auth + workouts).
@Riverpod(keepAlive: true)
VdotApiClient vdotApiClient(Ref ref) {
  final config = ref.watch(appConfigProvider);
  if (kDebugMode) {
    // Diagnostic: confirm the VDOT secret actually loaded from the bundled .env
    // asset for THIS build. `invalid_payload` from the token endpoint means an
    // empty client_secret reached the server — almost always a stale/empty .env
    // asset (the file bundles at build time; an incremental build can ship a
    // stale asset even when the Dart code is current). `client_secret len 0`
    // here is the smoking gun → `flutter clean` + rebuild. Lengths only — never
    // log the secret value.
    print('🔑 [vdot] AppConfig creds at client build: '
        'client_id="${config.vdotClientId}" (len ${config.vdotClientId.length}), '
        'client_secret len ${config.vdotClientSecret.length}, '
        'authBase=${config.vdotAuthBaseUrl}');
  }
  return VdotApiClient(
    clientId: config.vdotClientId,
    clientSecret: config.vdotClientSecret,
    authBaseUrl: config.vdotAuthBaseUrl,
    apiBaseUrl: config.vdotApiBaseUrl,
  );
}

/// Provider for the V.O2 OAuth service.
@Riverpod(keepAlive: true)
VdotOAuthService vdotOAuthService(Ref ref) {
  final config = ref.watch(appConfigProvider);
  final apiClient = ref.watch(vdotApiClientProvider);
  final repository = ref.watch(integrationsRepositoryProvider);
  return VdotOAuthService(
    apiClient: apiClient,
    repository: repository,
    clientId: config.vdotClientId,
    authBaseUrl: config.vdotAuthBaseUrl,
    redirectUri: _vdotRedirectUri,
    callbackUrlScheme: _baseCallbackScheme,
  );
}

/// Provider to get the V.O2 integration for a user.
@riverpod
Future<IntegrationModel?> vdotIntegration(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository.getIntegration(userId, 'vdot');
}

/// Provider to check whether V.O2 is connected for a user.
@riverpod
Future<bool> isVdotConnected(Ref ref, String userId) async {
  final integration = await ref.watch(vdotIntegrationProvider(userId).future);
  return integration?.isActive ?? false;
}

/// Provider for the V.O2 transformer (workout JSON → Activity).
@Riverpod(keepAlive: true)
VdotTransformer vdotTransformer(Ref ref) => const VdotTransformer();

/// Provider for the V.O2 sync service.
@Riverpod(keepAlive: true)
VdotSyncService vdotSyncService(Ref ref) {
  final apiClient = ref.watch(vdotApiClientProvider);
  final integrationsRepository = ref.watch(integrationsRepositoryProvider);
  final activitiesRepository = ref.watch(activitiesRepositoryProvider);
  final transformer = ref.watch(vdotTransformerProvider);
  final changeDetectionService = ref.watch(changeDetectionServiceProvider);
  return VdotSyncService(
    apiClient: apiClient,
    integrationsRepository: integrationsRepository,
    activitiesRepository: activitiesRepository,
    transformer: transformer,
    changeDetectionService: changeDetectionService,
    analytics: ref.watch(analyticsTrackerProvider),
  );
}

// =============================================================================
// RUNNA (ICS FEED) PROVIDERS
// =============================================================================

/// Provider for the Runna ICS feed HTTP client. No OAuth — the calendar
/// subscription URL itself carries the token.
@Riverpod(keepAlive: true)
RunnaIcsClient runnaIcsClient(Ref ref) => RunnaIcsClient();

/// Provider for the Runna ICS parser (pure RFC 5545 subset).
@Riverpod(keepAlive: true)
RunnaIcsParser runnaIcsParser(Ref ref) => const RunnaIcsParser();

/// Provider for the Runna transformer (ICS event → Activity).
@Riverpod(keepAlive: true)
RunnaTransformer runnaTransformer(Ref ref) => const RunnaTransformer();

/// Provider for the Runna sync service.
@Riverpod(keepAlive: true)
RunnaSyncService runnaSyncService(Ref ref) {
  final icsClient = ref.watch(runnaIcsClientProvider);
  final parser = ref.watch(runnaIcsParserProvider);
  final integrationsRepository = ref.watch(integrationsRepositoryProvider);
  final activitiesRepository = ref.watch(activitiesRepositoryProvider);
  final transformer = ref.watch(runnaTransformerProvider);
  final changeDetectionService = ref.watch(changeDetectionServiceProvider);
  return RunnaSyncService(
    icsClient: icsClient,
    parser: parser,
    integrationsRepository: integrationsRepository,
    activitiesRepository: activitiesRepository,
    transformer: transformer,
    changeDetectionService: changeDetectionService,
    analytics: ref.watch(analyticsTrackerProvider),
  );
}

/// Provider to get the Runna integration for a user.
@riverpod
Future<IntegrationModel?> runnaIntegration(Ref ref, String userId) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository.getIntegration(userId, 'runna');
}

/// Provider to check whether Runna is connected for a user.
@riverpod
Future<bool> isRunnaConnected(Ref ref, String userId) async {
  final integration = await ref.watch(runnaIntegrationProvider(userId).future);
  return integration?.isActive ?? false;
}
