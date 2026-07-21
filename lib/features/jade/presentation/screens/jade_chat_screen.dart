import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/jade_message.dart';
import '../../domain/jade_ui_part.dart';
import '../providers/jade_chat_controller.dart';
import '../widgets/jade_avatar.dart';
import '../widgets/jade_choice_buttons.dart';
import '../widgets/jade_meal_card.dart';

/// Full-screen chat interface for the Jade AI coach.
///
/// Layout:
///   - AppBar: Jade avatar + name + "new chat" action icon.
///   - Body: scrollable message list with user/assistant bubbles.
///   - Bottom: input row with send button (disabled while streaming).
///   - Empty state: warm intro card + suggested prompt chips.
class JadeChatScreen extends ConsumerStatefulWidget {
  const JadeChatScreen({super.key});

  @override
  ConsumerState<JadeChatScreen> createState() => _JadeChatScreenState();
}

class _JadeChatScreenState extends ConsumerState<JadeChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasShownError = false;

  /// Guards the one-shot proactive-opener request so it fires once per empty
  /// conversation (reset when the user starts a new chat).
  bool _openerRequested = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// The suggested prompt labels, resolved from content with sensible defaults.
  /// Shared by the first-run empty state and the persistent chip strip.
  List<String> _suggestedPrompts(ContentService contentService) {
    return [
      contentService.getValue(
        'jade.suggested_prompt_plan_day',
        defaultValue: 'Plan my day',
      ),
      contentService.getValue(
        'jade.suggested_prompt_plan_week',
        defaultValue: 'Plan my week',
      ),
      contentService.getValue(
        'jade.suggested_prompt_1',
        defaultValue: 'Help me set up my meal baseline',
      ),
      contentService.getValue(
        'jade.suggested_prompt_2',
        defaultValue: "What should I eat before tomorrow's workout?",
      ),
      contentService.getValue(
        'jade.suggested_prompt_3',
        defaultValue: 'How much carbs do I need for a long run?',
      ),
    ];
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          pos,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(pos);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentService = ref.read(contentServiceProvider);
    final chatAsync = ref.watch(jadeChatControllerProvider);

    // Consume any error message exactly once per error.
    ref.listen<AsyncValue<JadeChatState>>(jadeChatControllerProvider, (
      _,
      next,
    ) {
      final s = next.value;
      if (s?.errorMessage != null && !_hasShownError) {
        _hasShownError = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          MealvanaSnackbar.showError(context, s!.errorMessage!);
          ref.read(jadeChatControllerProvider.notifier).clearError();
          _hasShownError = false;
        });
      }
      // Auto-scroll when new messages arrive or streaming progresses.
      if (s != null && (s.messages.isNotEmpty || s.isStreaming)) {
        _scrollToBottom();
      }
    });

    final jadeName = contentService.getValue(
      'jade.coach_name',
      defaultValue: 'Jade',
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: _buildAppBar(context, jadeName, isDark),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chatAsync.when(
                data: (state) => _buildBody(context, state, contentService),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.electrolyte,
                  ),
                ),
                error: (_, __) => _buildLoadError(context),
              ),
            ),
            _buildInputRow(context, chatAsync.value, isDark, contentService),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String jadeName,
    bool isDark,
  ) {
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    return AppBar(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: FaIcon(FontAwesomeIcons.chevronLeft, color: textColor, size: 18),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const JadeAvatar(size: 32),
          const SizedBox(width: AppSpacing.sm),
          Text(
            jadeName,
            style: AppTextStyles.sectionTitle.copyWith(color: textColor),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.penToSquare,
            color: textColor.withValues(alpha: 0.7),
            size: 18,
          ),
          tooltip: 'New chat',
          onPressed: () {
            ref.read(jadeChatControllerProvider.notifier).newChat();
            // Allow the proactive opener to fire again for the fresh chat.
            setState(() => _openerRequested = false);
          },
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    JadeChatState state,
    ContentService contentService,
  ) {
    if (state.messages.isEmpty && !state.isStreaming) {
      if (!state.hasHistory) {
        _maybeRequestOpener();
      }
      return _buildEmptyState(context, contentService);
    }
    return _buildMessageList(context, state);
  }

  void _maybeRequestOpener() {
    if (_openerRequested) return;
    _openerRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(jadeChatControllerProvider.notifier).loadOpener();
    });
  }

  Widget _buildMessageList(BuildContext context, JadeChatState state) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: state.messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final msg = state.messages[index];
        final isLastAndStreaming =
            state.isStreaming && index == state.messages.length - 1;
        return _MessageBubble(message: msg, isStreaming: isLastAndStreaming);
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, ContentService contentService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final intro = contentService.getValue(
      'jade.empty_intro',
      defaultValue:
          "Hi! I'm Jade, your AI endurance nutrition coach. I can help you build a fueling strategy, answer questions about your nutrition plan, and help you establish a solid meal baseline.",
    );

    final prompts = _suggestedPrompts(contentService);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // Avatar + name header
          Column(
            children: [
              const JadeAvatar(size: 72),
              const SizedBox(height: AppSpacing.md),
              Text(
                contentService.getValue(
                  'jade.empty_greeting',
                  defaultValue: 'Hey, I\'m Jade',
                ),
                style: AppTextStyles.sectionTitle.copyWith(color: textColor),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Intro card
          BaseCard(
            backgroundColor: isDark
                ? AppColors.blackberryLight
                : AppColors.surfaceLight,
            child: Text(
              intro,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor.withValues(alpha: 0.85),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Suggested prompts
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: prompts.map((prompt) {
              return _PromptChip(
                label: prompt,
                onTap: () => _sendMessage(prompt),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildLoadError(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load chat history',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RetryButton(
            onPressed: () => ref.invalidate(jadeChatControllerProvider),
          ),
        ],
      ),
    );
  }

  // ── Input row ──────────────────────────────────────────────────────────────

  Widget _buildInputRow(
    BuildContext context,
    JadeChatState? state,
    bool isDark,
    ContentService contentService,
  ) {
    final isStreaming = state?.isStreaming ?? false;
    final hint = contentService.getValue(
      'jade.input_hint',
      defaultValue: 'Ask Jade anything…',
    );

    final borderColor = isDark
        ? AppColors.cream.withValues(alpha: 0.2)
        : AppColors.blackberry.withValues(alpha: 0.15);

    final inputBg = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberry : AppColors.cream,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: TextField(
                controller: _textController,
                enabled: !isStreaming,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.cream.withValues(alpha: 0.4)
                        : AppColors.blackberry.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: borderColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: AppColors.electrolyte,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onSubmitted: isStreaming ? null : (_) => _sendFromInput(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Send / streaming indicator
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isStreaming
                ? _StreamingIndicator(key: const ValueKey('streaming'))
                : _SendButton(
                    key: const ValueKey('send'),
                    onPressed: _sendFromInput,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _sendFromInput() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _sendMessage(text);
  }

  void _sendMessage(String text) {
    ref.read(jadeChatControllerProvider.notifier).send(text);
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isStreaming});

  final JadeMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.role == JadeMessageRole.user;

    if (isUser) {
      return _UserBubble(message: message, isDark: isDark);
    }
    return _AssistantBubble(
      message: message,
      isDark: isDark,
      isStreaming: isStreaming,
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.isDark});

  final JadeMessage message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.electrolyte,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.xs),
              ),
            ),
            child: SelectableText(
              message.content,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.blackberry,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.message,
    required this.isDark,
    required this.isStreaming,
  });

  final JadeMessage message;
  final bool isDark;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final bubbleBg = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final hasText = message.content.isNotEmpty;
    final hasUiParts = message.uiParts.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: JadeAvatar(size: 28, isPulsing: isStreaming),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Prose bubble ─────────────────────────────────────────────
              if (isStreaming && !hasText && !hasUiParts)
                // Waiting for first chunk — show typing indicator in a bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.xs),
                      topRight: Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: _TypingIndicator(isDark: isDark),
                )
              else if (hasText)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.xs),
                      topRight: const Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(
                        hasUiParts ? AppRadius.xs : AppRadius.lg,
                      ),
                      bottomRight: const Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: SelectableText(
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: textColor,
                      height: 1.6,
                    ),
                  ),
                ),

              // ── UI parts rendered below the prose ────────────────────────
              if (hasUiParts) ...[
                const SizedBox(height: AppSpacing.xs),
                ..._buildUiParts(message.uiParts),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildUiParts(List<JadeUiPart> parts) {
    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i > 0) widgets.add(const SizedBox(height: AppSpacing.xs));

      switch (part) {
        case JadeMealCardsPart(:final meals):
          for (int j = 0; j < meals.length; j++) {
            if (j > 0) widgets.add(const SizedBox(height: AppSpacing.xs));
            widgets.add(JadeMealCard(suggestion: meals[j]));
          }
        case JadeChoicesPart():
          widgets.add(JadeChoiceButtons(part: part));
      }
    }
    return widgets;
  }
}

/// Three animated dots shown while waiting for the first chunk from Jade.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.isDark});
  final bool isDark;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isDark
        ? AppColors.cream.withValues(alpha: 0.5)
        : AppColors.blackberry.withValues(alpha: 0.4);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final progress = (_controller.value - i * 0.2).clamp(0.0, 1.0);
            final alpha = (0.3 + 0.7 * (1.0 - (2 * (progress - 0.5)).abs()))
                .clamp(0.3, 1.0);
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(alpha: alpha),
              ),
            );
          },
        );
      }),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.electrolyte.withValues(alpha: 0.7),
          ),
          borderRadius: BorderRadius.circular(AppRadius.circular),
          color: AppColors.electrolyte.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark ? AppColors.electrolyte : AppColors.electrolyteDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.electrolyte,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.send_rounded,
          color: AppColors.blackberry,
          size: 20,
        ),
      ),
    );
  }
}

class _StreamingIndicator extends StatelessWidget {
  const _StreamingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.electrolyte,
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.electrolyte,
          borderRadius: BorderRadius.circular(AppRadius.circular),
        ),
        child: Text(
          'Retry',
          style: AppTextStyles.buttonPrimary.copyWith(
            color: AppColors.blackberry,
          ),
        ),
      ),
    );
  }
}
