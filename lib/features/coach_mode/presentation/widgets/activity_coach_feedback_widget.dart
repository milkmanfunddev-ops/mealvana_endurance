import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/database/database_provider.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_message.dart';
import '../providers/activity_coach_feedback_provider.dart';

/// Widget to display coach comments/feedback for a specific activity
/// Can be embedded in the ActivityDetailScreen
class ActivityCoachFeedbackWidget extends ConsumerStatefulWidget {
  const ActivityCoachFeedbackWidget({
    super.key,
    required this.activityId,
    this.isCoachView = false,
    this.activityUserId,
  });

  final String activityId;
  final bool isCoachView;
  final String? activityUserId;

  @override
  ConsumerState<ActivityCoachFeedbackWidget> createState() => _ActivityCoachFeedbackWidgetState();
}

class _ActivityCoachFeedbackWidgetState extends ConsumerState<ActivityCoachFeedbackWidget> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (widget.activityUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Cannot determine athlete')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final profile = await db.getCurrentUserProfile();
      
      if (profile == null) {
        throw Exception('User profile not found');
      }

      final coachService = ref.read(coachServiceProvider);
      
      // Determine IDs based on view mode
      // If Coach View: I am the coach, athlete is activityUserId
      // If Athlete View: I am the athlete... wait, athletes can't initiate comments easily on activity 
      // without picking a coach. For now, we only support Coach commenting on activity.
      
      String coachUserId;
      String athleteUserId;

      if (widget.isCoachView) {
        coachUserId = profile.id;
        athleteUserId = widget.activityUserId!;
      } else {
        // Fallback for athlete replying? 
        // For now, assume this input is primarily for coaches.
        // If an athlete wants to reply, they should probably do it in the message center 
        // or we need to know which coach thread this is.
        // Let's disable input for athletes for now unless we have context.
        throw Exception('Commenting not supported for athletes in this view yet');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send comment: $e')),
        );
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
    final feedbackAsync = ref.watch(activityCoachFeedbackProvider(widget.activityId));

    return Column(
      children: [
        feedbackAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (messages) {
            if (messages.isEmpty && !widget.isCoachView) {
              return const SizedBox.shrink();
            }
            return _buildFeedbackSection(context, messages);
          },
        ),
        
        // Input section for coaches
        if (widget.isCoachView)
          _buildInputSection(context),
      ],
    );
  }

  Widget _buildInputSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
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
            onPressed: _isSending ? null : _handleSendComment,
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

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.comment,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Coach Feedback',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            ],
          ),
          const SizedBox(height: 12),

          // Feedback cards
          ...messages.map((m) => _buildFeedbackCard(context, m)),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context, CoachMessage message) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: message.isSentByCoach
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  child: Icon(
                    Icons.person,
                    size: 14,
                    color: message.isSentByCoach
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.isSentByCoach ? 'Coach' : 'You',
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
