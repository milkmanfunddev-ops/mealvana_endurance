import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_message.dart';
import '../providers/activity_coach_feedback_provider.dart';
import '../providers/activity_coach_feedback_sync_provider.dart';

/// Widget to display coach comments/feedback for a specific activity
/// Can be embedded in the ActivityDetailScreen
///
/// Supports a shared comment thread visible to all connected coaches.
/// Both coaches and athletes can comment on the activity.
class ActivityCoachFeedbackWidget extends ConsumerStatefulWidget {
  const ActivityCoachFeedbackWidget({
    super.key,
    required this.activityId,
    this.isCoachView = false,
    this.activityUserId,
  });

  final String activityId;
  final bool isCoachView;
  /// For coach view: the athlete who owns the activity
  /// For athlete view: can be null (will use current user)
  final String? activityUserId;

  @override
  ConsumerState<ActivityCoachFeedbackWidget> createState() => _ActivityCoachFeedbackWidgetState();
}

class _ActivityCoachFeedbackWidgetState extends ConsumerState<ActivityCoachFeedbackWidget> {
  final _commentController = TextEditingController();
  bool _isSending = false;
  bool _isExpanded = false;

  /// Cached coach user ID for athlete view (to avoid repeated lookups)
  String? _cachedCoachUserId;
  bool _hasLoadedCoachId = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Get a valid coach_user_id for athlete comments
  /// Strategy: Use coach from existing comments, or first connected coach
  Future<String?> _getCoachUserIdForAthlete(List<CoachMessage> existingMessages) async {
    // Return cached value if available
    if (_hasLoadedCoachId) return _cachedCoachUserId;

    // Try to get coach from existing messages first
    if (existingMessages.isNotEmpty) {
      _cachedCoachUserId = existingMessages.first.coachUserId;
      _hasLoadedCoachId = true;
      return _cachedCoachUserId;
    }

    // Fall back to first active coach relationship
    final coachService = ref.read(coachServiceProvider);
    final coaches = await coachService.getMyCoaches();

    if (coaches.isNotEmpty) {
      _cachedCoachUserId = coaches.first.coachUserId;
    }

    _hasLoadedCoachId = true;
    return _cachedCoachUserId;
  }

  Future<void> _handleSendComment(List<CoachMessage> existingMessages) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final currentAuthUserId = Supabase.instance.client.auth.currentUser?.id;
      final profile = await db.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );

      if (profile == null) {
        throw Exception('User profile not found');
      }

      final coachService = ref.read(coachServiceProvider);

      String coachUserId;
      String athleteUserId;

      if (widget.isCoachView) {
        // Coach view: I am the coach, athlete is activityUserId
        if (widget.activityUserId == null) {
          throw Exception('Cannot determine athlete');
        }
        coachUserId = profile.id;
        athleteUserId = widget.activityUserId!;
      } else {
        // Athlete view: I am the athlete, need to find a coach
        athleteUserId = profile.id;

        final resolvedCoachId = await _getCoachUserIdForAthlete(existingMessages);
        if (resolvedCoachId == null) {
          throw Exception('No connected coach found');
        }
        coachUserId = resolvedCoachId;
      }

      await coachService.sendMessage(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        messageText: text,
        activityId: widget.activityId,
      );

      _commentController.clear();
      // Refresh the comments list
      ref.invalidate(activityCoachFeedbackProvider(widget.activityId));

      if (mounted) {
        MealvanaSnackbar.showSuccess(context, 'Comment sent');
      }
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to send comment: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Trigger sync when widget loads to get latest coach feedback from Supabase
    // This ensures athletes see new messages immediately without manual refresh
    ref.listen(
      activityCoachFeedbackSyncProvider(widget.activityId),
      (_, __) {}, // Just trigger, sync provider handles invalidation
    );

    final feedbackAsync = ref.watch(activityCoachFeedbackProvider(widget.activityId));

    return feedbackAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.comment,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Loading coach feedback...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
      error: (error, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to load coach feedback: ${error.toString()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(activityCoachFeedbackSyncProvider(widget.activityId));
                ref.invalidate(activityCoachFeedbackProvider(widget.activityId));
              },
              tooltip: 'Retry',
            ),
          ],
        ),
      ),
      data: (messages) => _buildContent(context, messages),
    );
  }

  Widget _buildContent(BuildContext context, List<CoachMessage> messages) {
    // For athlete view with no messages, check if they have coaches
    if (messages.isEmpty && !widget.isCoachView) {
      // Show section with input if athlete might have coaches
      return FutureBuilder<String?>(
        future: _getCoachUserIdForAthlete(messages),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          // Only show if athlete has at least one coach
          if (snapshot.data != null) {
            return _buildFeedbackSectionWithInput(context, messages, showInput: true);
          }
          return const SizedBox.shrink();
        },
      );
    }

    // For athlete view with messages - check if we can comment
    if (!widget.isCoachView && messages.isNotEmpty) {
      return FutureBuilder<String?>(
        future: _getCoachUserIdForAthlete(messages),
        builder: (context, snapshot) {
          final canComment = snapshot.data != null;
          return _buildFeedbackSectionWithInput(context, messages, showInput: canComment);
        },
      );
    }

    // Coach view: always show input
    return _buildFeedbackSectionWithInput(context, messages, showInput: widget.isCoachView);
  }

  Widget _buildFeedbackSectionWithInput(
    BuildContext context,
    List<CoachMessage> messages, {
    required bool showInput,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Collapsible header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.comment,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isCoachView ? 'Activity Feedback' : 'Coach Feedback',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (messages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${messages.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_isExpanded) ...[
            Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            if (messages.isNotEmpty || showInput)
              _buildFeedbackSection(context, messages),
            if (showInput)
              _buildInputSection(context, messages),
          ],
        ],
      ),
    );
  }

  Widget _buildInputSection(BuildContext context, List<CoachMessage> messages) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: widget.isCoachView
                    ? 'Add feedback...'
                    : 'Reply to coach...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : () => _handleSendComment(messages),
            icon: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(BuildContext context, List<CoachMessage> messages) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Empty state hint
          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.isCoachView
                    ? 'No feedback yet. Add a comment below.'
                    : 'No feedback from your coach yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Feedback cards (oldest first for natural reading order)
          ...messages.reversed.map((m) => _buildFeedbackCard(context, m)),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context, CoachMessage message) {
    final theme = Theme.of(context);
    final isFromCoach = message.isSentByCoach;

    // Determine label based on view mode and sender
    String senderLabel;
    if (widget.isCoachView) {
      senderLabel = isFromCoach ? 'You' : 'Athlete';
    } else {
      senderLabel = isFromCoach ? 'Coach' : 'You';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isFromCoach
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isFromCoach
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  child: Icon(
                    Icons.person,
                    size: 14,
                    color: isFromCoach
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    senderLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatDate(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.messageText,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
