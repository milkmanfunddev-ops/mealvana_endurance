import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart' show DatabaseSchemaException;
import '../database/database_provider.dart';
import 'logging_service.dart';

/// Provider for the schema recovery service
final schemaRecoveryServiceProvider = Provider<SchemaRecoveryService>((ref) {
  return SchemaRecoveryService(
    logger: ref.read(appLoggerProvider),
  );
});

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
///     ref: ref,
///     invalidateProviders: [myRepositoryProvider, myServiceProvider],
///   );
/// }
/// ```

class SchemaRecoveryService {
  SchemaRecoveryService({
    required AppLogger logger,
  }) : _logger = logger;

  final AppLogger _logger;

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
  /// 2. Invalidates the database provider to create fresh instance
  /// 3. Calls [onRecovery] to invalidate dependent providers
  /// 4. Retries the operation once
  ///
  /// Parameters:
  /// - [operation]: The async function to execute
  /// - [ref]: Riverpod ref for provider invalidation
  /// - [onRecovery]: Callback to invalidate dependent providers after DB is recreated
  /// - [context]: Optional context string for logging
  ///
  /// Returns the result of [operation] on success.
  /// Throws the original error if recovery fails or circuit breaker is tripped.
  Future<T> withSchemaRecovery<T>({
    required Future<T> Function() operation,
    required Ref ref,
    void Function()? onRecovery,
    String? context,
  }) async {
    try {
      return await operation();
    } on DatabaseSchemaException catch (e, stackTrace) {
      return _handleSchemaException<T>(
        exception: e,
        stackTrace: stackTrace,
        operation: operation,
        ref: ref,
        onRecovery: onRecovery,
        context: context,
      );
    }
  }

  /// Handle a DatabaseSchemaException with recovery and retry.
  Future<T> _handleSchemaException<T>({
    required DatabaseSchemaException exception,
    required StackTrace stackTrace,
    required Future<T> Function() operation,
    required Ref ref,
    void Function()? onRecovery,
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

    try {
      // Step 1: Invalidate the database provider to create fresh instance
      // Note: The database was already closed and files deleted by handleSchemaError
      ref.invalidate(appDatabaseProvider);

      // Step 2: Trigger creation of new database
      ref.read(appDatabaseProvider);

      // Step 3: Call recovery callback to invalidate dependent providers
      if (onRecovery != null) {
        onRecovery();
      }

      _logger.info(
        'Database reinitialized - retrying operation',
        context: context ?? 'SCHEMA_RECOVERY',
      );

      // Step 4: Retry the operation with fresh database
      return await operation();
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
