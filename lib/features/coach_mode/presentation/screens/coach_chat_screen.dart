import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/coach_chat_state.dart';
import '../../domain/coach_message.dart';
import '../providers/coach_chat_controller.dart';
import '../widgets/chat_input_field.dart';
import '../widgets/chat_message_bubble.dart';

/// Unified chat screen for coach-athlete conversations
/// Works for both coaches and athletes - role is detected from relationship
class CoachChatScreen extends ConsumerStatefulWidget {
  const CoachChatScreen({
    super.key,
    required this.relationshipId,
  });

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
    final chatAsync = ref.watch(
      coachChatControllerProvider(widget.relationshipId),
    );

    // Scroll to bottom when messages change
    ref.listen(
      coachChatControllerProvider(widget.relationshipId),
      (previous, next) {
        if (next.hasValue) {
          final prevCount = previous?.value?.allMessages.length ?? 0;
          final nextCount = next.value?.allMessages.length ?? 0;
          if (nextCount > prevCount) {
            _scrollToBottom();
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      appBar: AppBar(
        backgroundColor: AppColors.blackberryDark,
        foregroundColor: AppColors.cream,
        title: chatAsync.when(
          data: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.otherParticipantName,
                style: const TextStyle(color: AppColors.cream),
              ),
              Text(
                state.otherParticipantRole,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textDarkSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          loading: () => const Text('Chat', style: TextStyle(color: AppColors.cream)),
          error: (_, __) => const Text('Chat', style: TextStyle(color: AppColors.cream)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(
                      coachChatControllerProvider(widget.relationshipId).notifier)
                  .refresh();
            },
          ),
        ],
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorView(context, error.toString()),
        data: (state) => _buildChatBody(context, state),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
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
            const Text(
              'Unable to load chat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDarkSecondary,
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
                    .read(coachChatControllerProvider(widget.relationshipId)
                        .notifier)
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

  Widget _buildChatBody(BuildContext context, CoachChatState state) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: state.allMessages.isEmpty
              ? _buildEmptyView(context, state)
              : _buildMessagesList(context, state),
        ),

        // Error banner
        if (state.error != null) _buildErrorBanner(context, state, ref),

        // Input field
        ChatInputField(
          controller: _messageController,
          isSending: state.isSending,
          onSend: _handleSend,
        ),
      ],
    );
  }

  Widget _buildMessagesList(BuildContext context, CoachChatState state) {
    final messages = state.allMessages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isFromCurrentUser = message.senderUserId == state.currentUserId;

        // Show date separator if this is the first message or a different day
        final showDateSeparator = index == 0 ||
            !_isSameDay(
              messages[index].createdAt,
              messages[index - 1].createdAt,
            );

        return Column(
          children: [
            if (showDateSeparator)
              _buildDateSeparator(context, message.createdAt),
            ChatMessageBubble(
              message: message,
              isFromCurrentUser: isFromCurrentUser,
              showSenderName: !isFromCurrentUser,
              senderName: state.otherParticipantRole,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.textDarkSecondary.withOpacity(0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateLabel(date),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDarkSecondary.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.textDarkSecondary.withOpacity(0.2),
            ),
          ),
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
        'Sunday'
      ];
      return dayNames[date.weekday - 1];
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Widget _buildEmptyView(BuildContext context, CoachChatState state) {
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
            const Text(
              'Start the Conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send a message to ${state.otherParticipantName} to get started.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textDarkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, CoachChatState state, WidgetRef ref) {
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
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.cream,
              ),
            ),
          ),
          if (state.pendingMessages.any((m) => m.status == MessageStatus.failed))
            TextButton(
              onPressed: () {
                ref
                    .read(
                        coachChatControllerProvider(widget.relationshipId).notifier)
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
            icon: const Icon(
              Icons.close,
              size: 18,
              color: AppColors.cream,
            ),
            onPressed: () {
              ref
                  .read(
                      coachChatControllerProvider(widget.relationshipId).notifier)
                  .clearError();
            },
          ),
        ],
      ),
    );
  }
}
