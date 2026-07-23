import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/app_external_deps.dart';
import '../domain/coach_message.dart';

part 'coach_messaging_repository.g.dart';

@riverpod
CoachMessagingRepository coachMessagingRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return CoachMessagingRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
  );
}

/// Repository for managing coach-athlete messaging following FOA pattern
/// Handles bidirectional messaging, subscriptions, and message queries
class CoachMessagingRepository {
  const CoachMessagingRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required SentryReporter sentry,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger,
       _sentry = sentry;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final SentryReporter _sentry;

  static const _uuid = Uuid();

  // ============================================================================
  // MESSAGE QUERY OPERATIONS
  // ============================================================================

  /// Get ONLY general chat messages (excludes activity and nutrition plan comments)
  /// Used for the dedicated chat screen
  /// Queries Supabase directly for real-time accuracy (historical messages)
  Future<List<CoachMessage>> getGeneralChatMessages({
    required String coachUserId,
    required String athleteUserId,
    int? limit,
  }) async {
    try {
      // Query Supabase directly to get all historical messages
      var query = _supabase
          .from('coach_messages')
          .select('*')
          .eq('coach_user_id', coachUserId)
          .eq('athlete_user_id', athleteUserId)
          .isFilter('activity_id', null)
          .isFilter('nutrition_plan_id', null)
          .order(
            'created_at',
            ascending: true,
          ); // Oldest first for chat display

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      final messages = data.map((json) {
        final m = json as Map<String, dynamic>;
        return CoachMessage(
          id: m['id'] as String,
          coachUserId: m['coach_user_id'] as String,
          athleteUserId: m['athlete_user_id'] as String,
          senderUserId: m['sender_user_id'] as String,
          messageText: m['message_text'] as String,
          activityId: m['activity_id'] as String?,
          nutritionPlanId: m['nutrition_plan_id'] as String?,
          isRead: m['is_read'] as bool? ?? false,
          createdAt: DateTime.parse(m['created_at'] as String),
          updatedAt: DateTime.parse(m['updated_at'] as String),
        );
      }).toList();

      // Also cache to local Drift for offline access
      for (final message in messages) {
        final companion = CoachMessagesTableCompanion.insert(
          id: message.id,
          coachUserId: message.coachUserId,
          athleteUserId: message.athleteUserId,
          senderUserId: message.senderUserId,
          messageText: message.messageText,
          nutritionPlanId: Value(message.nutritionPlanId),
          activityId: Value(message.activityId),
          isRead: Value(message.isRead),
          createdAt: Value(message.createdAt),
          updatedAt: Value(message.updatedAt),
        );

        await _database
            .into(_database.coachMessagesTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }

      return messages;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get general chat messages from Supabase',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get messages for a coach-athlete conversation
  Future<List<CoachMessage>> getMessagesForConversation({
    required String coachUserId,
    required String athleteUserId,
    int? limit,
  }) async {
    try {
      var query = _database.select(_database.coachMessagesTable)
        ..where(
          (t) =>
              t.coachUserId.equals(coachUserId) &
              t.athleteUserId.equals(athleteUserId),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      if (limit != null) {
        query = query..limit(limit);
      }

      final results = await query.get();
      return results.map(_mapToMessageDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get messages for conversation',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get messages/comments for a nutrition plan
  Future<List<CoachMessage>> getMessagesForNutritionPlan(
    String nutritionPlanId,
  ) async {
    try {
      final results =
          await (_database.select(_database.coachMessagesTable)
                ..where((t) => t.nutritionPlanId.equals(nutritionPlanId))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

      return results.map(_mapToMessageDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get messages for nutrition plan',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get messages/comments for an activity
  Future<List<CoachMessage>> getMessagesForActivity(String activityId) async {
    try {
      final results =
          await (_database.select(_database.coachMessagesTable)
                ..where((t) => t.activityId.equals(activityId))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

      return results.map(_mapToMessageDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get messages for activity',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get unread message count for a user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // User can be either coach or athlete in the conversation
      // Count messages where they are the recipient (not the sender) and unread
      final results =
          await (_database.select(_database.coachMessagesTable)..where(
                (t) =>
                    (t.coachUserId.equals(userId) |
                        t.athleteUserId.equals(userId)) &
                    t.senderUserId.isNotValue(userId) &
                    t.isRead.equals(false),
              ))
              .get();

      return results.length;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get unread message count',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  // ============================================================================
  // MESSAGE MUTATION OPERATIONS
  // ============================================================================

  /// Send a message in a coach-athlete conversation
  /// Writes to both Supabase (for cross-device sync) AND local Drift database
  Future<CoachMessage> sendMessage({
    required String coachUserId,
    required String athleteUserId,
    required String senderUserId,
    required String messageText,
    String? nutritionPlanId,
    String? activityId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();

      // Insert into Supabase first (for cross-device sync and realtime)
      try {
        await _supabase.from('coach_messages').insert({
          'id': id,
          'coach_user_id': coachUserId,
          'athlete_user_id': athleteUserId,
          'sender_user_id': senderUserId,
          'message_text': messageText,
          'nutrition_plan_id': nutritionPlanId,
          'activity_id': activityId,
          'is_read': false,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'COACH_MESSAGING_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'send_message', 'recordId': id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:coach_messages:send_message',
          method: 'INSERT',
          stackTrace: stackTrace,
        );
        throw StateError('Failed to send message remotely');
      }

      // Also save to local Drift database
      final companion = CoachMessagesTableCompanion.insert(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        nutritionPlanId: Value(nutritionPlanId),
        activityId: Value(activityId),
        isRead: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _database.into(_database.coachMessagesTable).insert(companion);

      return CoachMessage(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        nutritionPlanId: nutritionPlanId,
        activityId: activityId,
        isRead: false,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to send message',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Send a chat message to Supabase (for realtime sync)
  /// Also saves to local Drift database
  Future<CoachMessage> sendChatMessageToSupabase({
    required String coachUserId,
    required String athleteUserId,
    required String senderUserId,
    required String messageText,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();

      // Insert into Supabase first (this triggers realtime for other party)
      try {
        await _supabase.from('coach_messages').insert({
          'id': id,
          'coach_user_id': coachUserId,
          'athlete_user_id': athleteUserId,
          'sender_user_id': senderUserId,
          'message_text': messageText,
          'is_read': false,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          // activity_id and nutrition_plan_id are NULL for general chat
        });
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'COACH_MESSAGING_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'send_chat_message', 'recordId': id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:coach_messages:send_chat_message',
          method: 'INSERT',
          stackTrace: stackTrace,
        );
        throw StateError('Failed to send chat message remotely');
      }

      // Also save to local Drift database
      final companion = CoachMessagesTableCompanion.insert(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        isRead: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      await _database.into(_database.coachMessagesTable).insert(companion);

      return CoachMessage(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        isRead: false,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to send chat message to Supabase',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead({
    required String coachUserId,
    required String athleteUserId,
    required String readerUserId,
  }) async {
    try {
      // Mark all messages in this conversation as read where:
      // - The reader is not the sender (they're the recipient)
      await (_database.update(_database.coachMessagesTable)..where(
            (t) =>
                t.coachUserId.equals(coachUserId) &
                t.athleteUserId.equals(athleteUserId) &
                t.senderUserId.isNotValue(readerUserId) &
                t.isRead.equals(false),
          ))
          .write(
            CoachMessagesTableCompanion(
              isRead: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark messages as read',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a message (only sender can delete)
  Future<void> deleteMessage(String messageId) async {
    try {
      await (_database.delete(
        _database.coachMessagesTable,
      )..where((t) => t.id.equals(messageId))).go();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete message',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // REALTIME SUBSCRIPTION OPERATIONS
  // ============================================================================

  /// Subscribe to new messages for a conversation using Supabase Realtime
  /// Returns a RealtimeChannel that should be unsubscribed when done
  RealtimeChannel subscribeToConversation({
    required String coachUserId,
    required String athleteUserId,
    required void Function(CoachMessage) onNewMessage,
  }) {
    final channelName = 'chat:$coachUserId:$athleteUserId';

    _logger.info(
      'Setting up realtime subscription for conversation',
      context: 'COACH_MESSAGING_REPOSITORY',
      data: {
        'channelName': channelName,
        'coachUserId': coachUserId,
        'athleteUserId': athleteUserId,
      },
    );

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'coach_messages',
          // REMOVED FILTER: Let all messages through, filter in callback
          // This ensures we don't miss messages due to overly restrictive filters
          callback: (payload) {
            _logger.info(
              'Realtime event received',
              context: 'COACH_MESSAGING_REPOSITORY',
              data: {
                'eventType': payload.eventType.toString(),
                'table': payload.table,
                'newRecord': payload.newRecord,
              },
            );

            try {
              final newRecord = payload.newRecord;

              // Check if this message is for our conversation
              final messageCoachUserId = newRecord['coach_user_id'] as String?;
              final messageAthleteUserId =
                  newRecord['athlete_user_id'] as String?;

              if (messageCoachUserId != coachUserId ||
                  messageAthleteUserId != athleteUserId) {
                _logger.info(
                  'Message not for our conversation, skipping',
                  context: 'COACH_MESSAGING_REPOSITORY',
                  data: {
                    'expected_coach_user_id': coachUserId,
                    'expected_athlete_user_id': athleteUserId,
                    'received_coach_user_id': messageCoachUserId,
                    'received_athlete_user_id': messageAthleteUserId,
                  },
                );
                return;
              }

              final message = CoachMessage(
                id: newRecord['id'] as String,
                coachUserId: newRecord['coach_user_id'] as String,
                athleteUserId: newRecord['athlete_user_id'] as String,
                senderUserId: newRecord['sender_user_id'] as String,
                messageText: newRecord['message_text'] as String,
                nutritionPlanId: newRecord['nutrition_plan_id'] as String?,
                activityId: newRecord['activity_id'] as String?,
                isRead: newRecord['is_read'] as bool? ?? false,
                createdAt: DateTime.parse(newRecord['created_at'] as String),
                updatedAt: DateTime.parse(newRecord['updated_at'] as String),
              );

              // Only notify for general messages (not activity/plan comments)
              if (message.isGeneralMessage) {
                _logger.info(
                  'Calling onNewMessage callback',
                  context: 'COACH_MESSAGING_REPOSITORY',
                  data: {'messageId': message.id},
                );
                onNewMessage(message);
              } else {
                _logger.info(
                  'Message is not a general message, skipping',
                  context: 'COACH_MESSAGING_REPOSITORY',
                  data: {
                    'messageId': message.id,
                    'isActivityComment': message.isActivityComment,
                    'isNutritionPlanComment': message.isNutritionPlanComment,
                  },
                );
              }
            } catch (e, stackTrace) {
              _logger.error(
                'Failed to parse realtime message',
                context: 'COACH_MESSAGING_REPOSITORY',
                error: e,
                stackTrace: stackTrace,
              );
            }
          },
        )
        .subscribe();

    _logger.info(
      'Realtime subscription created and subscribed',
      context: 'COACH_MESSAGING_REPOSITORY',
      data: {'channelName': channelName},
    );

    return channel;
  }

  /// Unsubscribe from a conversation channel
  Future<void> unsubscribeFromConversation(RealtimeChannel channel) async {
    try {
      await channel.unsubscribe();
      await _supabase.removeChannel(channel);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to unsubscribe from conversation',
        context: 'COACH_MESSAGING_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Map Drift CoachMessageEntry to domain
  CoachMessage _mapToMessageDomain(CoachMessageEntry entry) {
    return CoachMessage(
      id: entry.id,
      coachUserId: entry.coachUserId,
      athleteUserId: entry.athleteUserId,
      senderUserId: entry.senderUserId,
      messageText: entry.messageText,
      nutritionPlanId: entry.nutritionPlanId,
      activityId: entry.activityId,
      isRead: entry.isRead,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }
}
