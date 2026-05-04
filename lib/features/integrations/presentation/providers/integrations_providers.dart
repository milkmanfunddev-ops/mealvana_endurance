import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_config.dart';
import '../../../activities/data/activities_repository.dart';
import '../../application/change_detection_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../application/final_surge_oauth_service.dart';
import '../../application/final_surge_sync_service.dart';
import '../../application/final_surge_transformer.dart';
import '../../application/garmin_oauth_service.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../application/training_peaks_transformer.dart';
import '../../data/final_surge_api_client.dart';
import '../../data/integrations_repository.dart';
import '../../data/training_peaks_api_client.dart';
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
///   4. Garmin measurement is newer than user's last update → true.
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
  return garmin.measurementTime.isAfter(userUpdatedAt);
}

/// Returns true if Garmin's body composition data should be treated as more
/// authoritative than the user's manually-entered body fat percentage.
///
/// Same staleness and precedence rules as [isGarminAuthoritativeForWeight].
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
  return garmin.measurementTime.isAfter(userUpdatedAt);
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
  return IntegrationsRepository(database: database);
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
