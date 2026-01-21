import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart' show DatabaseSchemaException;
import '../database/database_provider.dart';
import 'logging_service.dart';

/// Provider for the schema recovery service
final schemaRecoveryServiceProvider = Provider<SchemaRecoveryService>((ref) {
  return SchemaRecoveryService(
    logger: ref.read(appLoggerProvider),
    // Store the ref for later use in invalidation
    providerRef: ref,
  );
});

/// Exception thrown after schema recovery completes, signaling that the
/// operation should be retried. The database has been deleted and will
/// be recreated on next access.
class SchemaRecoveryCompleteException implements Exception {
  final String message;
  final String? context;

  SchemaRecoveryCompleteException({
    this.message = 'Schema recovery complete. Please retry the operation.',
    this.context,
  });

  @override
  String toString() => 'SchemaRecoveryCompleteException: $message';
}

/// Global service for handling database schema errors with automatic recovery.
///
/// This service provides:
/// - Circuit breaker to prevent infinite recovery loops (one attempt per session)
/// - Automatic database close → delete → recreate flow
/// - Generic wrapper method for any async operation that might hit schema errors
///
/// Usage in any controller:
/// ```dart
/// Future<Activity> createSomething() async {
///   return ref.read(schemaRecoveryServiceProvider).withSchemaRecovery(
///     operation: () => _service.doSomething(),
///     onRetryNeeded: () async {
///       // Invalidate your providers and retry
///       ref.invalidate(myRepositoryProvider);
///       return _service.doSomething();
///     },
///   );
/// }
/// ```

class SchemaRecoveryService {
  SchemaRecoveryService({
    required AppLogger logger,
    required Ref providerRef,
  })  : _logger = logger,
        _providerRef = providerRef;

  final AppLogger _logger;
  final Ref _providerRef;

  /// Circuit breaker: only attempt recovery once per app session
  static bool _recoveryAttemptedThisSession = false;

  /// Check if recovery has already been attempted this session
  bool get hasAttemptedRecovery => _recoveryAttemptedThisSession;

  /// Reset the circuit breaker (only for testing)
  @visibleForTesting
  static void resetCircuitBreaker() {
    _recoveryAttemptedThisSession = false;
  }

  /// Execute an operation with automatic schema error recovery.
  ///
  /// If a [DatabaseSchemaException] is thrown:
  /// 1. Checks circuit breaker (only one recovery attempt per session)
  /// 2. Invalidates the database provider using the service's own ref
  /// 3. Calls [onRetryNeeded] to let the caller retry with fresh providers
  ///
  /// Parameters:
  /// - [operation]: The async function to execute
  /// - [onRetryNeeded]: Callback that returns the retry result (caller invalidates their providers and retries)
  /// - [context]: Optional context string for logging
  ///
  /// Returns the result of [operation] on success, or [onRetryNeeded] after recovery.
  Future<T> withSchemaRecovery<T>({
    required Future<T> Function() operation,
    required Future<T> Function() onRetryNeeded,
    String? context,
  }) async {
    try {
      return await operation();
    } on DatabaseSchemaException catch (e, stackTrace) {
      return _handleSchemaException<T>(
        exception: e,
        stackTrace: stackTrace,
        onRetryNeeded: onRetryNeeded,
        context: context,
      );
    }
  }

  /// Handle a DatabaseSchemaException with recovery and retry.
  Future<T> _handleSchemaException<T>({
    required DatabaseSchemaException exception,
    required StackTrace stackTrace,
    required Future<T> Function() onRetryNeeded,
    String? context,
  }) async {
    // Circuit breaker: prevent infinite loops
    if (_recoveryAttemptedThisSession) {
      _logger.error(
        'Schema error but recovery already attempted this session - not retrying',
        context: context ?? 'SCHEMA_RECOVERY',
        error: exception,
        stackTrace: stackTrace,
        data: {'circuitBreakerTripped': true},
      );
      // Re-throw the original exception
      throw exception;
    }

    // Mark that we're attempting recovery
    _recoveryAttemptedThisSession = true;

    _logger.warning(
      'Schema error detected - initiating automatic recovery',
      context: context ?? 'SCHEMA_RECOVERY',
      error: exception,
      data: {'context': context},
    );

    // Step 1: Invalidate the database provider using the SERVICE's ref (not caller's)
    // This is safe because the service's ref won't be disposed by this invalidation
    _providerRef.invalidate(appDatabaseProvider);

    // Step 2: Trigger creation of new database
    _providerRef.read(appDatabaseProvider);

    _logger.info(
      'Database recreated - calling retry callback',
      context: context ?? 'SCHEMA_RECOVERY',
    );

    // Step 3: Call the retry callback - caller handles their own provider invalidation
    try {
      return await onRetryNeeded();
    } catch (retryError, retryStackTrace) {
      _logger.error(
        'Operation failed even after schema recovery',
        context: context ?? 'SCHEMA_RECOVERY',
        error: retryError,
        stackTrace: retryStackTrace,
      );
      rethrow;
    }
  }
}
