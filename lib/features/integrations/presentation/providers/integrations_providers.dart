import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_config.dart';
import '../../../activities/data/activities_repository.dart';
import '../../application/change_detection_service.dart';
import '../../application/final_surge_oauth_service.dart';
import '../../application/final_surge_sync_service.dart';
import '../../application/final_surge_transformer.dart';
import '../../application/training_peaks_oauth_service.dart';
import '../../application/training_peaks_sync_service.dart';
import '../../application/training_peaks_transformer.dart';
import '../../data/final_surge_api_client.dart';
import '../../data/integrations_repository.dart';
import '../../data/training_peaks_api_client.dart';
import '../../domain/integration.dart';

part 'integrations_providers.g.dart';

/// Provider for app package info (version, build number, etc.)
@Riverpod(keepAlive: true)
Future<PackageInfo> packageInfo(Ref ref) async {
  return PackageInfo.fromPlatform();
}

/// Base callback URL scheme for OAuth
const _baseCallbackScheme = 'com.milkman.mealvanaendurance';

/// Get the callback URL scheme for OAuth
/// Note: We use the same callback scheme for both dev and prod because
/// Final Surge only has one registered app ("mealvana") with a single
/// whitelisted callback URL. Using different schemes per environment
/// would cause "invalid callback URL" errors.
String _getCallbackScheme(bool isDev) {
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
    callbackUrlScheme: _getCallbackScheme(config.isDevelopment),
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
Future<IntegrationModel?> finalSurgeIntegration(
  Ref ref,
  String userId,
) async {
  final repository = ref.watch(integrationsRepositoryProvider);
  return repository.getIntegration(userId, 'final_surge');
}

/// Provider to check if Final Surge is connected
@riverpod
Future<bool> isFinalSurgeConnected(
  Ref ref,
  String userId,
) async {
  final integration = await ref.watch(finalSurgeIntegrationProvider(userId).future);
  return integration?.isActive ?? false;
}

/// Provider for all user integrations
@riverpod
Future<List<IntegrationModel>> userIntegrations(
  Ref ref,
  String userId,
) async {
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
    callbackUrlScheme: _getCallbackScheme(config.isDevelopment),
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
Future<bool> isTrainingPeaksConnected(
  Ref ref,
  String userId,
) async {
  final integration = await ref.watch(trainingPeaksIntegrationProvider(userId).future);
  return integration?.isActive ?? false;
}
