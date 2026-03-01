import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/preferences_service.dart';
import '../../application/tp_writeback_service.dart';
import 'integrations_providers.dart';

part 'tp_writeback_providers.g.dart';

/// Provider for the TrainingPeaks write-back service.
/// keepAlive because the service is stateless and expensive to recreate
/// (requires async resolution of API client and OAuth service).
@Riverpod(keepAlive: true)
Future<TpWritebackService> tpWritebackService(Ref ref) async {
  final apiClient = await ref.watch(trainingPeaksApiClientProvider.future);
  final oauthService = await ref.watch(trainingPeaksOAuthServiceProvider.future);
  final preferencesService = ref.watch(preferencesServiceProvider);
  final database = ref.watch(appDatabaseProvider);

  return TpWritebackService(
    apiClient: apiClient,
    oauthService: oauthService,
    preferencesService: preferencesService,
    database: database,
  );
}
