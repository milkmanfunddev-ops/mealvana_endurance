import 'package:flutter/material.dart';

import '../../domain/coach_message.dart';

/// A chat message bubble widget for displaying messages in the chat screen
/// Follows Material Design 3 patterns for chat UI
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.showSenderName = false,
    this.senderName = '',
  });

  final CoachMessage message;
  final bool isFromCurrentUser;
  final bool showSenderName;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages
          if (!isFromCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromCurrentUser
                    ? theme.colorScheme.primaryContainer
                    : const Color(0xFFD92D20), // Coral/red for coach messages - contrasts with purple background
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isFromCurrentUser ? 16 : 4),
                  bottomRight: Radius.circular(isFromCurrentUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name for received messages
                  if (showSenderName && !isFromCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),

                  // Message text
                  Text(
                    message.messageText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isFromCurrentUser
                          ? theme.colorScheme.onPrimaryContainer
                          : Colors.white,
                    ),
                  ),

                  // Timestamp with status indicator
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: (isFromCurrentUser
                                  ? theme.colorScheme.onPrimaryContainer
                                  : Colors.white)
                              .withOpacity(0.7),
                        ),
                      ),
                      // Status indicator for sent messages
                      if (isFromCurrentUser) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(theme),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Spacing after sent messages
          if (isFromCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    final color = theme.colorScheme.onPrimaryContainer.withOpacity(0.7);

    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done,
          size: 14,
          color: color,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: theme.colorScheme.error,
        );
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return time;
    } else if (messageDate == yesterday) {
      return 'Yesterday $time';
    } else if (now.difference(date).inDays < 7) {
      // Show day name for messages within the last week
      const dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return '${dayNames[date.weekday - 1]} $time';
    } else {
      // Show full date for older messages
      return '${date.day}/${date.month}/${date.year} $time';
    }
  }
}
