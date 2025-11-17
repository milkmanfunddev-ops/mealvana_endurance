import 'package:drift/drift.dart';

/// Auth Sessions table definition for Drift
/// Stores Supabase auth sessions for offline-first persistence
///
/// This table implements custom session persistence to work around Supabase
/// offline limitations (Issue #716) where sessions are cleared on network errors.
///
/// By storing sessions locally in Drift, we can:
/// - Maintain 24-hour offline grace period
/// - Restore sessions on app restart
/// - Auto-refresh when online
/// - Prevent data loss for users in remote areas
@DataClassName('AuthSessionEntry')
class AuthSessionsTable extends Table {
  /// User ID from Supabase auth.uid() - this is the primary key
  TextColumn get userId => text().withLength(min: 36, max: 36).named('user_id')();

  /// JWT access token (short-lived, default 1 hour)
  TextColumn get accessToken => text().named('access_token')();

  /// JWT refresh token (long-lived, used once to get new access/refresh pair)
  TextColumn get refreshToken => text().named('refresh_token')();

  /// When the access token expires (UTC timestamp)
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  /// User metadata from auth.user.user_metadata (stored as JSON string)
  /// Contains device_id and other user-controlled metadata
  TextColumn get userMetadata => text().withDefault(const Constant('{}')).named('user_metadata')();

  /// App metadata from auth.user.app_metadata (stored as JSON string)
  /// Contains server-only metadata like roles, provider info
  TextColumn get appMetadata => text().withDefault(const Constant('{}')).named('app_metadata')();

  /// When this session was last synced with Supabase
  DateTimeColumn get lastSyncedAt => dateTime().nullable().named('last_synced_at')();

  /// Whether this is an anonymous user session
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(true)).named('is_anonymous')();

  /// OAuth provider used (e.g., 'email', 'google', 'apple', 'anonymous')
  TextColumn get provider => text().withDefault(const Constant('anonymous'))();

  /// Email address (nullable for anonymous users)
  TextColumn get email => text().nullable()();

  /// Phone number (nullable)
  TextColumn get phone => text().nullable()();

  /// When the session was created locally
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the session was last updated locally
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {userId};

  @override
  String get tableName => 'auth_sessions';

  @override
  List<String> get customConstraints => [
    "CHECK (provider IN ('anonymous', 'email', 'google', 'apple'))",
  ];
}
