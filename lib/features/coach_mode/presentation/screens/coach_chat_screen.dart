import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        title: chatAsync.when(
          data: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.otherParticipantName),
              Text(
                state.otherParticipantRole,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ],
          ),
          loading: () => const Text('Chat'),
          error: (_, __) => const Text('Chat'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Refresh button
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load chat',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
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
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.allMessages.length,
                  itemBuilder: (context, index) {
                    final message = state.allMessages[index];
                    final isFromCurrentUser =
                        message.senderUserId == state.currentUserId;

                    return ChatMessageBubble(
                      message: message,
                      isFromCurrentUser: isFromCurrentUser,
                      showSenderName: !isFromCurrentUser,
                      senderName: state.otherParticipantRole,
                    );
                  },
                ),
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

  Widget _buildEmptyView(BuildContext context, CoachChatState state) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Start the Conversation',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send a message to ${state.otherParticipantName} to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, CoachChatState state, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          // Retry button if there are failed messages
          if (state.pendingMessages.any((m) => m.status == MessageStatus.failed))
            TextButton(
              onPressed: () {
                ref
                    .read(
                        coachChatControllerProvider(widget.relationshipId).notifier)
                    .retryFailedMessages();
              },
              child: Text(
                'Retry',
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
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
