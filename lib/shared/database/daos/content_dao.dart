import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/app_content_table.dart';
import '../tables/feedback.dart';

part 'content_dao.g.dart';

/// Data Access Object for app content and survey feedback.
///
/// This DAO handles:
/// - App content cache operations (getActiveAppContent, cacheAppContent)
/// - Survey/feedback CRUD operations (saveSurveyResponse, getLatestSurveyResponse)
@DriftAccessor(tables: [AppContentTable, FeedbackTable])
class ContentDao extends DatabaseAccessor<AppDatabase> with _$ContentDaoMixin {
  ContentDao(super.db);

  // ==================== App Content Methods ====================

  /// Get active app content for environment and locale
  Future<AppContentEntry?> getActiveAppContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
    final query = select(appContentTable)
      ..where(
        (c) =>
            c.environment.equals(environment) &
            c.locale.equals(locale) &
            c.isActive.equals(true),
      )
      ..orderBy([(c) => OrderingTerm.desc(c.version)])
      ..limit(1);

    return await query.getSingleOrNull();
  }

  /// Cache app content from Supabase
  Future<void> cacheAppContent(Map<String, dynamic> contentData) async {
    final entry = AppContentTableCompanion(
      id: Value(contentData['id'] ?? 'main'),
      version: Value(contentData['version'] ?? 1),
      environment: Value(contentData['environment'] ?? 'production'),
      locale: Value(contentData['locale'] ?? 'en'),
      content: Value(contentData['content'] ?? '{}'),
      isActive: const Value(true),
      lastSyncAt: Value(DateTime.now()),
      isCached: const Value(true),
    );

    await into(appContentTable).insertOnConflictUpdate(entry);
  }

  // ==================== Survey/Feedback Methods ====================

  /// Save survey response to local database
  Future<void> saveSurveyResponse({
    required String id,
    required int confidenceLevel,
    required String confidenceLabel,
    required String reuseIntent,
    bool reminderRequested = false,
    List<String>? missedReasons,
    String? missedOther,
    int? reminderDayOfWeek,
    int? reminderHour,
    int? reminderMinute,
    bool? reminderRecurring,
    String? deviceId,
    String? planName,
  }) async {
    await into(feedbackTable).insertOnConflictUpdate(
      FeedbackTableCompanion.insert(
        id: id,
        satisfactionLevel: 2, // Default to "just right" for now
        satisfactionEmoji: '🤗',
        satisfactionLabel: 'Just right',
        confidenceLevel: Value(confidenceLevel),
        confidenceLabel: Value(confidenceLabel),
        reuseIntent: Value(reuseIntent),
        reminderRequested: Value(reminderRequested),
        missedReasons: Value(missedReasons?.join(',')),
        missedOther: Value(missedOther),
        reminderDayOfWeek: Value(reminderDayOfWeek),
        reminderHour: Value(reminderHour ?? 17),
        reminderMinute: Value(reminderMinute ?? 0),
        reminderRecurring: Value(reminderRecurring ?? false),
        deviceId: Value(deviceId),
        planName: Value(planName),
        timestamp: Value(DateTime.now()),
      ),
    );

    // Use Unix timestamp in milliseconds for Drift compatibility
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'UPDATE feedback SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, id],
    );
  }

  /// Get latest survey response for a device
  Future<FeedbackEntry?> getLatestSurveyResponse(String deviceId) async {
    final query = select(feedbackTable)
      ..where((f) => f.deviceId.equals(deviceId))
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)])
      ..limit(1);

    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }
}
