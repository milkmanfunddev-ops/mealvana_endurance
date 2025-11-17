import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';

/// Provider for session repository
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final database = ref.read(appDatabaseProvider);
  final deps = ref.read(appExternalDepsProvider);
  return SessionRepository(
    database,
    deps.logger,
    deps.supabaseClient,
  );
});

/// Repository for handling Supabase auth session persistence
///
/// Implements custom session storage in Drift to work around Supabase offline
/// limitations (Issue #716) where sessions are cleared on network errors.
///
/// Key Features:
/// - Stores sessions locally in Drift SQLite
/// - Maintains 24-hour offline grace period
/// - Auto-restores sessions on app restart
/// - Auto-refreshes when online
/// - Prevents data loss for users in remote areas
///
/// Usage:
/// ```dart
/// // On app startup:
/// final session = await sessionRepo.getCurrentSession();
///
/// // After successful auth:
/// await sessionRepo.saveSession(supabaseSession);
///
/// // Before making API calls:
/// final valid = await sessionRepo.isSessionValid();
/// if (!valid) {
///   await sessionRepo.refreshSession();
/// }
/// ```
class SessionRepository {
  SessionRepository(this._database, this._logger, this._supabase);

  final AppDatabase _database;
  final AppLogger _logger;
  final SupabaseClient _supabase;

  /// Save a Supabase session to local Drift database
  /// This enables offline session persistence and 24-hour grace period
  Future<void> saveSession(Session session) async {
    try {
      final userMetadata = jsonEncode(session.user.userMetadata);
      final appMetadata = jsonEncode(session.user.appMetadata);

      // Check if this is an anonymous user
      final isAnonymous = session.user.appMetadata['provider'] == 'anonymous';

      await _database.into(_database.authSessionsTable).insertOnConflictUpdate(
        AuthSessionsTableCompanion.insert(
          userId: session.user.id,
          accessToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            (session.expiresAt ?? 0) * 1000, // Convert seconds to milliseconds
            isUtc: true,
          ),
          userMetadata: drift.Value(userMetadata),
          appMetadata: drift.Value(appMetadata),
          lastSyncedAt: drift.Value(DateTime.now()),
          isAnonymous: drift.Value(isAnonymous),
          provider: drift.Value(
            session.user.appMetadata['provider'] as String? ?? 'email'
          ),
          email: drift.Value(session.user.email),
          phone: drift.Value(session.user.phone),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      _logger.info(
        'Session saved to local database',
        context: 'SESSION_REPO',
        data: {
          'userId': session.user.id,
          'isAnonymous': isAnonymous,
          'provider': session.user.appMetadata['provider'],
          'expiresAt': session.expiresAt,
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to save session to local database',
        context: 'SESSION_REPO',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the current session from local Drift database
  /// Returns null if no session exists
  Future<AuthSessionEntry?> getCurrentSession() async {
    try {
      final query = _database.select(_database.authSessionsTable)
        ..orderBy([(session) => drift.OrderingTerm.desc(session.updatedAt)])
        ..limit(1);

      final results = await query.get();

      if (results.isEmpty) {
        _logger.debug('No session found in local database', context: 'SESSION_REPO');
        return null;
      }

      final session = results.first;
      _logger.debug(
        'Retrieved session from local database',
        context: 'SESSION_REPO',
        data: {
          'userId': session.userId,
          'expiresAt': session.expiresAt.toIso8601String(),
          'isExpired': session.expiresAt.isBefore(DateTime.now()),
        },
      );

      return session;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get current session from local database',
        context: 'SESSION_REPO',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Check if the current session is valid
  /// A session is valid if it exists and hasn't expired (with grace period)
  Future<bool> isSessionValid() async {
    final session = await getCurrentSession();

    if (session == null) {
      return false;
    }

    // Allow 24-hour grace period for offline users
    const gracePeriod = Duration(hours: 24);
    final expiryWithGrace = session.expiresAt.add(gracePeriod);

    final isValid = expiryWithGrace.isAfter(DateTime.now());

    _logger.debug(
      'Session validity check',
      context: 'SESSION_REPO',
      data: {
        'isValid': isValid,
        'expiresAt': session.expiresAt.toIso8601String(),
        'expiryWithGrace': expiryWithGrace.toIso8601String(),
        'now': DateTime.now().toIso8601String(),
      },
    );

    return isValid;
  }

  /// Refresh the current session using Supabase
  /// Returns the new session if successful, null otherwise
  Future<Session?> refreshSession() async {
    try {
      _logger.info('Attempting to refresh session', context: 'SESSION_REPO');

      // Try to refresh using Supabase's built-in refresh mechanism
      final response = await _supabase.auth.refreshSession();

      if (response.session != null) {
        // Save the refreshed session to local database
        await saveSession(response.session!);

        _logger.info(
          'Session refreshed successfully',
          context: 'SESSION_REPO',
          data: {
            'userId': response.session!.user.id,
            'newExpiresAt': response.session!.expiresAt,
          },
        );

        return response.session;
      } else {
        _logger.warning('Session refresh returned null', context: 'SESSION_REPO');
        return null;
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to refresh session',
        context: 'SESSION_REPO',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Delete the current session from local database
  /// Call this on sign out
  Future<void> deleteSession() async {
    try {
      await _database.delete(_database.authSessionsTable).go();

      _logger.info('Session deleted from local database', context: 'SESSION_REPO');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to delete session from local database',
        context: 'SESSION_REPO',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Restore Supabase session from local database
  /// Call this on app startup to restore offline sessions
  /// Returns true if session was successfully restored
  Future<bool> restoreSession() async {
    try {
      final localSession = await getCurrentSession();

      if (localSession == null) {
        _logger.debug('No local session to restore', context: 'SESSION_REPO');
        return false;
      }

      // Check if session is still valid (with grace period)
      if (!await isSessionValid()) {
        _logger.warning(
          'Local session has expired beyond grace period',
          context: 'SESSION_REPO',
        );
        await deleteSession();
        return false;
      }

      // Try to restore the session in Supabase client
      // This sets up the auth state without making a network request
      await _supabase.auth.recoverSession(jsonEncode({
        'access_token': localSession.accessToken,
        'refresh_token': localSession.refreshToken,
        'expires_at': localSession.expiresAt.millisecondsSinceEpoch ~/ 1000,
        'user': {
          'id': localSession.userId,
          'email': localSession.email,
          'phone': localSession.phone,
          'user_metadata': jsonDecode(localSession.userMetadata),
          'app_metadata': jsonDecode(localSession.appMetadata),
        },
      }));

      _logger.info(
        'Session restored from local database',
        context: 'SESSION_REPO',
        data: {
          'userId': localSession.userId,
          'isAnonymous': localSession.isAnonymous,
        },
      );

      return true;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to restore session from local database',
        context: 'SESSION_REPO',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Update the last synced timestamp for the current session
  /// Call this after successful network operations
  Future<void> updateLastSynced() async {
    try {
      final currentSession = await getCurrentSession();
      if (currentSession == null) return;

      await (_database.update(_database.authSessionsTable)
            ..where((session) => session.userId.equals(currentSession.userId)))
          .write(
        AuthSessionsTableCompanion(
          lastSyncedAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      _logger.debug('Updated session last synced timestamp', context: 'SESSION_REPO');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to update session last synced timestamp',
        context: 'SESSION_REPO',
        error: error,
        stackTrace: stackTrace,
      );
      // Don't rethrow - this is not critical
    }
  }
}
