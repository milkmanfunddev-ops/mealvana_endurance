import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/coach_message.dart';

/// A chat message bubble widget with theme-aware styling
/// Uses AppColors for consistent branding with the app theme
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isFromCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages
          if (!isFromCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.electrolyte,
              child: Text(
                _getInitials(senderName),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackberryDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.70,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromCurrentUser
                    ? (isDark
                          ? AppColors.blackberryLight
                          : AppColors.orange.withOpacity(0.15))
                    : (isDark
                          ? AppColors.inputBackground
                          : AppColors.surfaceLightSecondary),
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
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.electrolyte,
                        ),
                      ),
                    ),

                  // Message text
                  Text(
                    message.messageText,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),

                  // Timestamp with status indicator
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textDarkSecondary.withOpacity(0.7)
                              : AppColors.textLightSecondary.withOpacity(0.7),
                        ),
                      ),
                      // Status indicator for sent messages
                      if (isFromCurrentUser) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(isDark),
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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _buildStatusIcon(bool isDark) {
    final color = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;

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
        return Icon(Icons.done, size: 14, color: color);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: AppColors.dragonfruit,
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
      const dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return '${dayNames[date.weekday - 1]} $time';
    } else {
      return '${date.day}/${date.month}/${date.year} $time';
    }
  }
}
