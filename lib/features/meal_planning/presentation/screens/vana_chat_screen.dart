import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/vana_chat_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/meal_plan.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_type.dart';
import '../../domain/plan_meal.dart';
import '../../domain/ui_action.dart';
import '../../domain/vana_conversation_kind.dart';
import '../../domain/vana_part.dart';
import '../widgets/meal_sheet.dart';
import '../widgets/plan_bar.dart';
import '../widgets/review_sheet.dart';
import '../widgets/vana_avatar.dart';
import '../widgets/vana_message_card.dart';
import '../widgets/vana_part_renderer.dart';

/// `/vana?mode=&c=` (05 §4) — the Vana chat for both kinds. Planning chats
/// carry the plan bar (minimized at start and on every new turn), the
/// review/confirm sheet and the pick/swap remote-ack actions; general chats
/// get the empty state with example chips. Errors map per the contract:
/// offline bubble-copy, 429 "Give me N seconds", 402 credits paywall,
/// 403 → `/pro`.
class VanaChatScreen extends ConsumerStatefulWidget {
  const VanaChatScreen({
    super.key,
    this.kind = VanaConversationKind.mealPlanning,
    this.conversationId,
    this.startOpener = false,
  });

  final VanaConversationKind kind;

  /// `c=new` passes null; the opener's response header fills the id in.
  final String? conversationId;

  /// Planning chats opened with `c=new` stream the scripted opener.
  final bool startOpener;

  @override
  ConsumerState<VanaChatScreen> createState() => _VanaChatScreenState();
}

class _VanaChatScreenState extends ConsumerState<VanaChatScreen> {
  final _textController = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();
  final GlobalKey<PlanBarState> _planBarKey = GlobalKey<PlanBarState>();

  bool _openerRequested = false;
  bool _chipsPicked = false;
  Set<String> _pickedInCurrentPicker = {};

  VanaChatController get _controller =>
      ref.read(
        vanaChatControllerProvider(
          kind: widget.kind,
          conversationId: widget.conversationId,
        ).notifier,
      );

  @override
  void dispose() {
    _textController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final chatAsync = ref.watch(
      vanaChatControllerProvider(
        kind: widget.kind,
        conversationId: widget.conversationId,
      ),
    );
    final state = chatAsync.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;

    ref.listen<AsyncValue<VanaChatState>>(
      vanaChatControllerProvider(
        kind: widget.kind,
        conversationId: widget.conversationId,
      ),
      (previous, next) {
        final s = next.value;
        if (s == null) return;
        // Re-minimize the plan bar and re-arm the chips on every new turn.
        if ((s.messages.length) > (previous?.value?.messages.length ?? 0)) {
          _planBarKey.currentState?.minimize();
          setState(() {
            _chipsPicked = false;
            _pickedInCurrentPicker = {};
          });
        }
        _handleError(s);
        if (s.messages.isNotEmpty || s.isStreaming) _scrollToBottom();
      },
    );

    final isPlanning = widget.kind == VanaConversationKind.mealPlanning;
    final plan = ref.watch(mealPlanControllerProvider).value;
    if (widget.startOpener) _maybeRequestOpener();

    return Scaffold(
      key: const ValueKey('meal_planning.vana_chat_screen'),
      backgroundColor: bg,
      appBar: _buildAppBar(context, content, isDark, isPlanning),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: (state == null ||
                      (state.messages.isEmpty &&
                          !state.isStreaming &&
                          !isPlanning))
                  ? _EmptyState(kind: widget.kind, onPick: _send)
                  : _buildMessageList(context, state, plan),
            ),
            if (isPlanning && plan != null && plan.meals.isNotEmpty)
              PlanBar(
                key: _planBarKey,
                meals: plan.meals,
                onServings: (meal, servings) => ref
                    .read(mealPlanControllerProvider.notifier)
                    .setServings(meal.id, servings),
                onRemove: (meal) =>
                    ref.read(mealPlanControllerProvider.notifier).removeMeal(
                      meal.id,
                    ),
                onSwap: _swapFromSheet,
                onReview: () => _openReviewSheet(context, plan),
              ),
            _buildComposer(context, content, isDark, state, isPlanning),
          ],
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ContentService content,
    bool isDark,
    bool isPlanning,
  ) {
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: FaIcon(FontAwesomeIcons.chevronLeft, color: textColor, size: 18),
        onPressed: () => context.pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VanaAvatar(size: 30),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              isPlanning
                  ? '${content.getValue(ContentKeys.mpConvAsk)} · ${content.getValue(ContentKeys.mpConvPlans)}'
                  : content.getValue(ContentKeys.mpConvAsk),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionTitle.copyWith(color: textColor),
            ),
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
          onPressed: () => context.push(
            '/vana?c=new&mode=${isPlanning ? 'meal_planning' : 'general'}',
          ),
        ),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.listUl,
            color: textColor.withValues(alpha: 0.7),
            size: 18,
          ),
          onPressed: () => context.push(
            '/vana/conversations?kind=${isPlanning ? 'meal_planning' : 'general'}',
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildMessageList(
    BuildContext context,
    VanaChatState state,
    MealPlan? plan,
  ) {
    final coverage = plan?.coverage;
    final callbacks = VanaPartCallbacks(
      onTapMeal: (meal) => context.push('/food/meals/${meal.id}'),
      onPickMeal: _pickMeal,
      pickedIds: _pickedInCurrentPicker,
      coverageCovered: coverage?.covered ?? 0,
      coverageOf: coverage?.lunchDinnerSlots ?? 0,
      nextType: _nextType(state),
      planHasMeals: plan?.meals.isNotEmpty ?? false,
      chipsEnabled: !_chipsPicked,
      onChipPick: (label) {
        setState(() => _chipsPicked = true);
        _send(label);
      },
      onSomethingElse: _focusComposer,
      onAcceptRule: (part) => _controller.send(
        'Accept the rule: ${part.rule.rule}',
      ),
      onViewShopping: () => context.push('/food?tab=shopping'),
    );

    if (state.isStreaming && state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VanaAvatar(size: 56, isPulsing: true),
            const SizedBox(height: AppSpacing.md),
            Text(
              ref.read(contentServiceProvider).getValue(
                ContentKeys.mpOpenerLoading,
              ),
              key: const ValueKey('meal_planning.opener_loading'),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final isLast = index == state.messages.length - 1;
        return VanaMessageCard(
          key: ValueKey('meal_planning.chat_message_$index'),
          message: message,
          callbacks: callbacks,
          isStreaming: state.isStreaming && isLast,
          statusTool: isLast ? _statusLine(state.statusTool) : null,
        );
      },
    );
  }

  /// The chip strip's "`Next: <type>`" — the slot of the last picker's type
  /// progression is decided server-side; the client defaults to the last
  /// picker's own meal type when known.
  MealType? _nextType(VanaChatState state) {
    for (final message in state.messages.reversed) {
      final picker = message.parts.whereType<VanaMealPickerPart>().firstOrNull;
      if (picker != null) return picker.mealType;
    }
    return null;
  }

  String? _statusLine(String? tool) {
    if (tool == null) return null;
    // The status tool name is machine-ish (`searchMeals`); show the generic
    // thinking line until the copy table gains per-tool labels.
    return ref
        .read(contentServiceProvider)
        .getValue(ContentKeys.mpStatusThinking);
  }

  // ── Composer ─────────────────────────────────────────────────────────────

  Widget _buildComposer(
    BuildContext context,
    ContentService content,
    bool isDark,
    VanaChatState? state,
    bool isPlanning,
  ) {
    final isStreaming = state?.isStreaming ?? false;
    final hint = content.getValue(
      isPlanning
          ? ContentKeys.mpPickerPlaceholderPlanning
          : ContentKeys.mpPickerPlaceholderGeneral,
    );
    final isDark0 = isDark;
    final borderColor = isDark0
        ? AppColors.cream.withValues(alpha: 0.2)
        : AppColors.blackberry.withValues(alpha: 0.15);
    final textColor = isDark0 ? AppColors.cream : AppColors.blackberry;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark0 ? AppColors.blackberry : AppColors.cream,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: TextField(
                key: const ValueKey('meal_planning.chat_input'),
                controller: _textController,
                focusNode: _inputFocus,
                enabled: !isStreaming,
                maxLines: null,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: isDark0
                      ? AppColors.blackberryLight
                      : AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: isStreaming ? null : (_) => _sendFromInput(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          isStreaming
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.electrolyte,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  key: const ValueKey('meal_planning.chat_send'),
                  onPressed: _sendFromInput,
                  icon: const Icon(Icons.send_rounded, size: 20),
                  color: AppColors.electrolyte,
                ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _maybeRequestOpener() {
    if (_openerRequested) return;
    _openerRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadOpener();
    });
  }

  void _sendFromInput() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _send(text);
  }

  void _send(String text) {
    _controller.send(text);
    setState(() => _chipsPicked = false);
  }

  void _focusComposer() {
    _inputFocus.requestFocus();
  }

  Future<void> _pickMeal(MealRef meal, int servings) async {
    final content = ref.read(contentServiceProvider);
    setState(() => _pickedInCurrentPicker = {..._pickedInCurrentPicker, meal.id});
    try {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .pickMeals([
            MealPick(source: meal.source, id: meal.id),
          ], servings: servings);
    } on NeedsConnectionException {
      if (mounted) {
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(ContentKeys.mpNeedsConnection),
        );
      }
    } on Exception {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpServerError),
        );
      }
    }
  }

  Future<void> _swapFromSheet(PlanMeal meal, MealRef replacement) async {
    final content = ref.read(contentServiceProvider);
    try {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .swapMeal(meal.id, source: replacement.source, id: replacement.id);
    } on Exception {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpServerError),
        );
      }
    }
  }

  Future<void> _openReviewSheet(BuildContext context, MealPlan plan) {
    final planController = ref.read(mealPlanControllerProvider.notifier);
    return showReviewSheet(
      context: context,
      ref: ref,
      plan: plan,
      onTapMeal: (meal) => showMealSheet(
        context: context,
        ref: ref,
        meal: meal,
        onServings: (servings) =>
            planController.setServings(meal.id, servings),
        onSwap: _swapFromSheet,
        onRemove: () => planController.removeMeal(meal.id),
      ),
      onServings: (meal, servings) =>
          planController.setServings(meal.id, servings),
      onConfirm: () async {
        try {
          await planController.confirmPlan();
          return true;
        } on Exception {
          return false;
        }
      },
    );
  }

  // ── Errors ───────────────────────────────────────────────────────────────

  void _handleError(VanaChatState s) {
    if (s.error == null) return;
    final content = ref.read(contentServiceProvider);
    final error = s.error!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (error) {
        case VanaChatErrorKind.proRequired:
          context.go('/pro');
        case VanaChatErrorKind.rateLimited:
          MealvanaSnackbar.showWarning(
            context,
            ContentKeys.format(content.getValue(ContentKeys.mpRateLimited), {
              'n': s.retryAfterSeconds ?? 30,
            }),
          );
        case VanaChatErrorKind.offline:
          MealvanaSnackbar.showWarning(
            context,
            content.getValue(ContentKeys.mpVanaOffline),
          );
        default:
          MealvanaSnackbar.showError(
            context,
            content.getValue(ContentKeys.mpServerError),
          );
      }
      _controller.clearError();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

/// General chats' empty state: avatar + example chips (05 §4). Planning
/// chats with `c=new` stream the opener instead (handled by the parent).
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.kind, required this.onPick});

  final VanaConversationKind kind;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    final examples = [
      content.getValue(ContentKeys.mpGeneralExample1),
      content.getValue(ContentKeys.mpGeneralExample2),
      content.getValue(ContentKeys.mpGeneralExample3),
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VanaAvatar(size: 64),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              for (final example in examples)
                ActionChip(
                  key: ValueKey('meal_planning.general_example_$example'),
                  label: Text(example),
                  onPressed: () => onPick(example),
                  backgroundColor: accent.withValues(alpha: 0.1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
