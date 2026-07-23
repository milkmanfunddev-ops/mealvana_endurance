import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/coach_chat_state.dart';
import '../../domain/coach_message.dart';
import '../providers/coach_chat_controller.dart';
import '../widgets/chat_input_field.dart';
import '../widgets/chat_message_bubble.dart';

/// Unified chat screen for coach-athlete conversations
/// Works for both coaches and athletes - role is detected from relationship
class CoachChatScreen extends ConsumerStatefulWidget {
  const CoachChatScreen({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends ConsumerState<CoachChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      ref
          .read(coachChatControllerProvider(widget.relationshipId).notifier)
          .sendMessage(text);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatAsync = ref.watch(
      coachChatControllerProvider(widget.relationshipId),
    );

    // Scroll to bottom when messages change
    ref.listen(coachChatControllerProvider(widget.relationshipId), (
      previous,
      next,
    ) {
      if (next.hasValue) {
        final prevCount = previous?.value?.allMessages.length ?? 0;
        final nextCount = next.value?.allMessages.length ?? 0;
        if (nextCount > prevCount) {
          _scrollToBottom();
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.blackberryDark
            : AppColors.surfaceLight,
        foregroundColor: isDark ? AppColors.cream : AppColors.blackberry,
        title: chatAsync.when(
          data: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.otherParticipantName,
                style: TextStyle(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
              ),
              Text(
                state.otherParticipantRole,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textDarkSecondary.withOpacity(0.7)
                      : AppColors.textLightSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          loading: () => Text(
            'Chat',
            style: TextStyle(
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
          ),
          error: (_, __) => Text(
            'Chat',
            style: TextStyle(
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
          ),
        ),
        leading: CustomAppBarBackButton(
          iconColor: isDark ? AppColors.cream : AppColors.blackberry,
          backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(
                    coachChatControllerProvider(widget.relationshipId).notifier,
                  )
                  .refresh();
            },
          ),
        ],
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            _buildErrorView(context, error.toString(), isDark),
        data: (state) => _buildChatBody(context, state, isDark),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load chat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textLightSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                ref
                    .read(
                      coachChatControllerProvider(
                        widget.relationshipId,
                      ).notifier,
                    )
                    .refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(
    BuildContext context,
    CoachChatState state,
    bool isDark,
  ) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: state.allMessages.isEmpty
              ? _buildEmptyView(context, state, isDark)
              : _buildMessagesList(context, state, isDark),
        ),

        // Error banner
        if (state.error != null) _buildErrorBanner(context, state, ref, isDark),

        // Input field
        ChatInputField(
          controller: _messageController,
          isSending: state.isSending,
          onSend: _handleSend,
        ),
      ],
    );
  }

  Widget _buildMessagesList(
    BuildContext context,
    CoachChatState state,
    bool isDark,
  ) {
    final messages = state.allMessages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isFromCurrentUser = message.senderUserId == state.currentUserId;

        // Show date separator if this is the first message or a different day
        final showDateSeparator =
            index == 0 ||
            !_isSameDay(
              messages[index].createdAt,
              messages[index - 1].createdAt,
            );

        return Column(
          children: [
            if (showDateSeparator)
              _buildDateSeparator(context, message.createdAt, isDark),
            ChatMessageBubble(
              message: message,
              isFromCurrentUser: isFromCurrentUser,
              showSenderName: !isFromCurrentUser,
              senderName: state.otherParticipantName,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date, bool isDark) {
    final separatorColor = isDark
        ? AppColors.textDarkSecondary.withOpacity(0.2)
        : AppColors.textLightSecondary.withOpacity(0.2);
    final textColor = isDark
        ? AppColors.textDarkSecondary.withOpacity(0.6)
        : AppColors.textLightSecondary.withOpacity(0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: separatorColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateLabel(date),
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: separatorColor)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
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
      return dayNames[date.weekday - 1];
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Widget _buildEmptyView(
    BuildContext context,
    CoachChatState state,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 80,
              color: AppColors.electrolyte.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Start the Conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send a message to ${state.otherParticipantName} to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textLightSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    CoachChatState state,
    WidgetRef ref,
    bool isDark,
  ) {
    return Container(
      color: AppColors.dragonfruit.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.dragonfruit,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
          ),
          if (state.pendingMessages.any(
            (m) => m.status == MessageStatus.failed,
          ))
            TextButton(
              onPressed: () {
                ref
                    .read(
                      coachChatControllerProvider(
                        widget.relationshipId,
                      ).notifier,
                    )
                    .retryFailedMessages();
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
            onPressed: () {
              ref
                  .read(
                    coachChatControllerProvider(widget.relationshipId).notifier,
                  )
                  .clearError();
            },
          ),
        ],
      ),
    );
  }
}
