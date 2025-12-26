import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_config.dart';
import '../../../activities/data/activities_repository.dart';
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

/// Final Surge Client ID
/// TODO: Move to environment variables
const _finalSurgeClientId = 'BD5D0C2B-7507-405B-8A3F-DB161288E6FC';

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
  return FinalSurgeApiClient(clientId: _finalSurgeClientId);
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
    clientId: _finalSurgeClientId,
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

  return FinalSurgeSyncService(
    apiClient: apiClient,
    integrationsRepository: integrationsRepository,
    activitiesRepository: activitiesRepository,
    transformer: transformer,
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
TrainingPeaksApiClient trainingPeaksApiClient(Ref ref) {
  final config = ref.watch(appConfigProvider);
  return TrainingPeaksApiClient(
    clientId: config.trainingPeaksClientId,
    clientSecret: config.trainingPeaksClientSecret,
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
TrainingPeaksOAuthService trainingPeaksOAuthService(Ref ref) {
  final config = ref.watch(appConfigProvider);
  final apiClient = ref.watch(trainingPeaksApiClientProvider);
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
TrainingPeaksSyncService trainingPeaksSyncService(Ref ref) {
  final apiClient = ref.watch(trainingPeaksApiClientProvider);
  final oauthService = ref.watch(trainingPeaksOAuthServiceProvider);
  final integrationsRepository = ref.watch(integrationsRepositoryProvider);
  final activitiesRepository = ref.watch(activitiesRepositoryProvider);
  final transformer = ref.watch(trainingPeaksTransformerProvider);

  return TrainingPeaksSyncService(
    apiClient: apiClient,
    oauthService: oauthService,
    integrationsRepository: integrationsRepository,
    activitiesRepository: activitiesRepository,
    transformer: transformer,
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
