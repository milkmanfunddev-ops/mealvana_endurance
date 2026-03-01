import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_external_deps.dart';
import '../logging_service.dart';
import '../sentry/sentry_reporter.dart';

/// Centralized immediate remote write handling for offline-first repositories.
///
/// Repositories should:
/// 1. Save local changes with `needsUpload=true`
/// 2. Call [run] immediately
/// 3. Let this service report failures while keeping local records dirty for retry
final immediateRemoteWriteServiceProvider =
    Provider<ImmediateRemoteWriteService>((ref) {
      final deps = ref.read(appExternalDepsProvider);
      return ImmediateRemoteWriteService(
        logger: deps.logger,
        sentry: deps.sentry,
      );
    });

class ImmediateRemoteWriteService {
  const ImmediateRemoteWriteService({
    required AppLogger logger,
    required SentryReporter sentry,
  }) : _logger = logger,
       _sentry = sentry;

  final AppLogger _logger;
  final SentryReporter _sentry;

  Future<bool> run({
    required String repository,
    required String operation,
    required Future<void> Function() write,
    String? recordId,
    String? method,
    String? url,
  }) async {
    try {
      await write();
      return true;
    } catch (error, stackTrace) {
      _logger.warning(
        'Immediate remote write failed; record remains dirty for retry',
        context: 'IMMEDIATE_REMOTE_WRITE',
        error: error,
        stackTrace: stackTrace,
        data: {
          'repository': repository,
          'operation': operation,
          if (recordId != null) 'recordId': recordId,
        },
      );

      await _sentry.reportNetworkError(
        error,
        url: url ?? 'supabase:$repository:$operation',
        method: method ?? 'UPSERT',
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
