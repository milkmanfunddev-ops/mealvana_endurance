import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
import '../../domain/meal_source.dart';
import '../../domain/meal_type.dart';
import '../../domain/plan_meal.dart';
import '../../domain/ui_action.dart';
import '../../domain/vana_conversation_kind.dart';
import '../../domain/vana_message.dart';
import '../../domain/vana_part.dart';
import '../widgets/meal_sheet.dart';
import '../widgets/choice_chip_button.dart';
import '../../application/vana_settings_controller.dart';
import '../widgets/picker_chips.dart';
import '../widgets/plan_bar.dart';
import '../widgets/review_sheet.dart';
import '../widgets/vana_attach_sheet.dart';
import '../widgets/vana_avatar.dart';
import '../widgets/vana_date_divider.dart';
import '../widgets/vana_mic_button.dart';
import '../widgets/vana_round_button.dart';
import '../widgets/vana_message_card.dart';
import '../widgets/vana_status_copy.dart';
import '../widgets/vana_part_renderer.dart';

/// `/vana?mode=&c=` (05 §4) — the Vana chat for both kinds. Planning chats
/// carry the plan bar (minimized at start and on every new turn), the
/// review/confirm sheet and the pick/swap remote-ack actions; general chats
/// get the empty state with example chips. Errors map per the contract:
/// offline bubble-copy, 429 "Give me N seconds", 402 credits paywall,
/// 403 → `/pro`.
///
/// Transcript mechanics (plan §5 Phases 5–7): a one-time intro card heads a
/// new planning conversation; day dividers split turns that span days;
/// "Edit" under an athlete turn puts its text back in the composer and the
/// next send rewinds the conversation to that turn; the composer's `+`
/// offers "Snap my fridge" / "Use what I have" and the mic dictates.
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

  /// The athlete turn being edited (Phase 6.1) — the next send rewinds.
  String? _editingMessageId;

  VanaChatController get _controller => ref.read(
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
    // A planning conversation builds its OWN draft (meal_plans.conversation_id);
    // the plan bar, chips and coverage read that draft off the chat state —
    // never the week's active plan, which is what the Plan tab shows and what
    // a fresh conversation must not inherit (a new plan starts empty).
    final plan = isPlanning
        ? chatAsync.value?.draftPlan
        : ref.watch(mealPlanControllerProvider).value;
    if (widget.startOpener) _maybeRequestOpener();

    return Scaffold(
      key: const ValueKey('meal_planning.vana_chat_screen'),
      backgroundColor: bg,
      appBar: _buildAppBar(
        context,
        content,
        isDark,
        isPlanning,
        state?.isStreaming ?? false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  (state == null ||
                      (state.messages.isEmpty &&
                          !state.isStreaming &&
                          !isPlanning))
                  ? _EmptyState(kind: widget.kind, onPick: _send)
                  : _buildMessageList(context, state, plan),
            ),
            // The bar slides in over the composer the first time the draft
            // gains a meal (and out again if the draft empties), instead of
            // shoving the transcript up out of nowhere.
            AnimatedSwitcher(
              duration: Duration(
                milliseconds:
                    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                    ? 0
                    : 260,
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: isPlanning && plan != null && plan.meals.isNotEmpty
                  ? PlanBar(
                      key: _planBarKey,
                      meals: plan.meals,
                      confirmed: plan.isConfirmed,
                      showMacros:
                          ref
                              .watch(vanaSettingsControllerProvider)
                              .value
                              ?.showMacros ??
                          true,
                      onServings: (meal, servings) {
                        // Local-first write (keyed by the plan-meal row, so
                        // it lands on this draft); the bar shows the result
                        // at once.
                        _controller.applyDraftPlan(
                          plan.copyWith(
                            meals: [
                              for (final m in plan.meals)
                                if (m.id == meal.id)
                                  m.copyWith(
                                    servings: servings,
                                    servingsLeft: servings,
                                  )
                                else
                                  m,
                            ],
                            recomputeCoverage: true,
                          ),
                        );
                        ref
                            .read(mealPlanControllerProvider.notifier)
                            .setServings(meal.id, servings);
                      },
                      onRemove: (meal) {
                        _controller.applyDraftPlan(
                          plan.copyWith(
                            meals: [
                              for (final m in plan.meals)
                                if (m.id != meal.id) m,
                            ],
                            recomputeCoverage: true,
                          ),
                        );
                        ref
                            .read(mealPlanControllerProvider.notifier)
                            .removeMeal(meal.id);
                      },
                      onSwap: _swapFromSheet,
                      onReview: () => _openReviewSheet(context, plan),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('meal_planning.plan_bar.hidden'),
                    ),
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
    bool isStreaming,
  ) {
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              VanaRoundButton.back(
                context: context,
                onTap: () => context.pop(),
              ),
              const SizedBox(width: 12),
              VanaAvatar(size: 32, isPulsing: isStreaming),
              const SizedBox(width: 12),
              // Planning chats keep it to a single quiet line — the chat
              // itself says what's happening; general chats name Vana over
              // a one-line description of what the chat is for.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      content.getValue(
                        isPlanning
                            ? ContentKeys.mpChatTitlePlanning
                            : ContentKeys.mpChatTitleGeneral,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: textColor,
                        fontSize: 20,
                        height: 1.1,
                      ),
                    ),
                    if (!isPlanning)
                      Text(
                        content.getValue(ContentKeys.mpChatSubGeneral),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(color: muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              VanaRoundButton(
                icon: FontAwesomeIcons.plus,
                tooltip: 'New conversation',
                onTap: () => context.push(
                  '/vana?c=new&mode=${isPlanning ? 'meal_planning' : 'general'}',
                ),
              ),
              const SizedBox(width: 8),
              VanaRoundButton(
                icon: FontAwesomeIcons.comment,
                tooltip: 'Conversations',
                onTap: () => context.push(
                  '/vana/conversations?kind=${isPlanning ? 'meal_planning' : 'general'}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildMessageList(
    BuildContext context,
    VanaChatState state,
    MealPlan? plan,
  ) {
    final content = ref.read(contentServiceProvider);
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
      onAcceptRule: _acceptRule,
      onViewShopping: () => context.push('/food?tab=shopping'),
      onPantryUse: _usePantry,
      onPlanWeekOpen: () => context.push('/food?tab=plan'),
      onPantryPhoto: _snapFridgePhoto,
      onSwapPicked: (meal) => _swapPicked(plan, meal),
      onEditMessage: _beginEdit,
      // Disabled until the opener's response header has named the
      // conversation — there is no draft to browse into before that.
      onBrowseMeals: (state.conversationId ?? widget.conversationId) == null
          ? null
          : _openBrowse,
    );

    if (state.isStreaming && state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VanaAvatar(size: 56, isPulsing: true),
            const SizedBox(height: AppSpacing.md),
            Text(
              content.getValue(ContentKeys.mpOpenerLoading),
              key: const ValueKey('meal_planning.opener_loading'),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    final firstPickerIndex = _firstPickerIndex(state);
    final editLabel = state.isStreaming
        ? null
        : content.getValue(ContentKeys.mpEditMessage);
    final rows = _transcriptRows(state.messages);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: rows.length,
      itemBuilder: (context, rowIndex) {
        final row = rows[rowIndex];
        switch (row) {
          case _DividerRow(:final date):
            return VanaDateDivider(date: date);
          case _MessageRow(:final index, :final message):
            final isLast = index == state.messages.length - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: VanaPickerScope(
                isFirstPicker: index == firstPickerIndex,
                child: VanaMessageCard(
                  key: ValueKey('meal_planning.chat_message_$index'),
                  message: message,
                  index: index,
                  callbacks: callbacks,
                  isStreaming: state.isStreaming && isLast,
                  statusTool: isLast ? _statusLine(state.statusTool) : null,
                  editLabel: editLabel,
                  onEdit: state.isStreaming ? null : _beginEdit,
                ),
              ),
            );
        }
      },
    );
  }

  /// Messages interleaved with a day divider wherever consecutive turns
  /// fall on different local days (Phase 6.4). The first message gets a
  /// divider only when the conversation did not start today.
  static List<_TranscriptRow> _transcriptRows(List<VanaMessage> messages) {
    final rows = <_TranscriptRow>[];
    DateTime? previous;
    final now = DateTime.now();
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final needsDivider = previous == null
          ? VanaDateDivider.crossesDay(m.createdAt, now)
          : VanaDateDivider.crossesDay(previous, m.createdAt);
      if (needsDivider) rows.add(_DividerRow(m.createdAt));
      rows.add(_MessageRow(i, m));
      previous = m.createdAt;
    }
    return rows;
  }

  /// Index of the first transcript turn carrying a `meal_picker` — the
  /// only place the "Draft my whole week" chip may show (Phase 2.3).
  static int _firstPickerIndex(VanaChatState state) {
    for (var i = 0; i < state.messages.length; i++) {
      if (state.messages[i].parts.any((p) => p is VanaMealPickerPart)) {
        return i;
      }
    }
    return -1;
  }

  /// The chip strip's "`Next: <type>`" — the slot of the last picker's type
  /// progression is decided server-side; the client defaults to the last
  /// picker's own meal type when known.
  /// The type the NEXT picker should fill: the one after the last picker's
  /// type in the planning order (dinner → lunch → breakfast → snack),
  /// skipping types the draft already covers. Null once the order is spent
  /// (the primary chip then falls back to "I like these" / "That's my week").
  MealType? _nextType(VanaChatState state) {
    const order = [
      MealType.dinner,
      MealType.lunch,
      MealType.breakfast,
      MealType.snack,
    ];
    MealType? last;
    for (final message in state.messages.reversed) {
      final picker = message.parts.whereType<VanaMealPickerPart>().firstOrNull;
      if (picker != null) {
        last = picker.mealType;
        break;
      }
    }
    if (last == null) return null;
    final covered = {
      for (final m in state.draftPlan?.meals ?? const <PlanMeal>[]) m.mealType,
    };
    var i = order.indexOf(last) + 1;
    while (i < order.length) {
      if (!covered.contains(order[i])) return order[i];
      i++;
    }
    return null;
  }

  /// Per-tool status copy (plan §5 Phase 1.5) — the tool → key map lives in
  /// [VanaStatusCopy] so it stays a pure, testable table.
  String? _statusLine(String? tool) {
    if (tool == null) return null;
    return ref
        .read(contentServiceProvider)
        .getValue(VanaStatusCopy.keyForTool(tool));
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
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    // A pill field with a round electrolyte send button beside it, floating
    // over the transcript rather than sitting in a bordered bar
    // (prototype `.v-input` + `.k-send`). The `+` (attach) sits left of the
    // field, the mic right of it, and an editing strip rides above the row
    // while an athlete turn is being edited.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editingMessageId != null)
            _EditingStrip(
              label: content.getValue(ContentKeys.mpEditingStrip),
              cancelTooltip: content.getValue(ContentKeys.mpEditingCancel),
              onCancel: _cancelEdit,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isPlanning) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: VanaRoundButton(
                    key: const ValueKey('meal_planning.chat_attach'),
                    icon: FontAwesomeIcons.plus,
                    tooltip: content.getValue(ContentKeys.mpAttachTooltip),
                    onTap: isStreaming ? () {} : _openAttachSheet,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 140,
                  ),
                  child: TextField(
                    key: const ValueKey('meal_planning.chat_input'),
                    controller: _textController,
                    focusNode: _inputFocus,
                    enabled: !isStreaming,
                    maxLines: null,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: textColor,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: textColor.withValues(alpha: 0.4),
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: textColor.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: textColor.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: AppColors.electrolyte,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: isStreaming ? null : (_) => _sendFromInput(),
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: VanaMicButton(
                    tooltip: content.getValue(ContentKeys.mpMicTooltip),
                    listeningTooltip: content.getValue(
                      ContentKeys.mpMicListening,
                    ),
                    enabled: !isStreaming,
                    onText: _dictated,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: isStreaming
                      ? AppColors.electrolyte.withValues(alpha: 0.4)
                      : AppColors.electrolyte,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('meal_planning.chat_send'),
                    onTap: isStreaming ? null : _sendFromInput,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: isStreaming
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.blackberry,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: AppColors.blackberry,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final editing = _editingMessageId;
    if (editing != null) {
      setState(() {
        _editingMessageId = null;
        _chipsPicked = false;
      });
      _controller.rewindAndSend(editing, text);
      return;
    }
    _send(text);
  }

  void _send(String text) {
    _controller.send(text);
    setState(() => _chipsPicked = false);
  }

  void _focusComposer() {
    _inputFocus.requestFocus();
  }

  // ── Edit-and-rewind (Phase 6.1) ──

  void _beginEdit(String messageId, String text) {
    _textController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    setState(() => _editingMessageId = messageId);
    _focusComposer();
  }

  void _cancelEdit() {
    _textController.clear();
    setState(() => _editingMessageId = null);
  }

  // ── Composer `+` and mic (Phases 6.5, 7.3) ──

  /// Dictation replaces the field's text with the recogniser's running
  /// phrase (it re-emits the whole utterance as it refines).
  void _dictated(String words) {
    _textController
      ..text = words
      ..selection = TextSelection.collapsed(offset: words.length);
  }

  Future<void> _openAttachSheet() async {
    final content = ref.read(contentServiceProvider);
    final VanaAttachChoice? choice;
    try {
      choice = await showVanaAttachSheet(context: context);
    } on VanaAttachPickFailed {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpAttachPhotoFailed),
        );
      }
      return;
    }
    if (!mounted || choice == null) return;
    switch (choice) {
      case VanaAttachBrowseMeals():
        await _openBrowse();
      case VanaAttachUseWhatIHave():
        _send(content.getValue(ContentKeys.mpAttachUseWhatIHave));
      case VanaAttachPhoto(:final file, :final extension):
        // `readAsBytes` works for both the file path (mobile) and the blob
        // URL (web) an XFile can carry.
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        // Failures surface through the controller's error state → the
        // snackbar in [_handleError].
        await _controller.sendPantryPhoto(bytes, extension: extension);
    }
  }

  /// "Browse meals": the catalog picks straight into this conversation's
  /// draft on the server, so reload the draft when the screen pops back
  /// (the plan bar and coverage read it off the chat state).
  Future<void> _openBrowse() async {
    final id = _conversationId;
    if (id == null) return;
    await context.push('/vana/browse?c=$id');
    if (mounted) await _controller.refreshDraft();
  }

  /// "Use these" on a pantry card: record the items, then tell Vana.
  Future<void> _usePantry(List<String> items) async {
    if (items.isEmpty) return;
    final content = ref.read(contentServiceProvider);
    final message = ContentKeys.format(
      content.getValue(ContentKeys.mpPantryUseMessage),
      {'items': items.join(', ')},
    );
    setState(() => _chipsPicked = false);
    await _controller.usePantry(items, message: message);
  }

  /// "Scan my fridge" on a pantry card: straight to the camera (gallery on
  /// web — `image_picker` has no camera there), then the controller's
  /// `pantry_photo` flow. No attach sheet; the card is the context.
  Future<void> _snapFridgePhoto() async {
    final content = ref.read(contentServiceProvider);
    final XFile? file;
    try {
      // Same capture budget as the attach sheet: enough detail for
      // ingredient recognition without bloating the vision input.
      file = await ImagePicker().pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1000,
      );
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpAttachPhotoFailed),
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    // `readAsBytes` works for both the file path (mobile) and the blob URL
    // (web) an XFile can carry. `sendPantryPhoto` no-ops mid-stream.
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final parts = file.name.split('.');
    await _controller.sendPantryPhoto(
      bytes,
      extension: (parts.length > 1 ? parts.last : 'jpg').toLowerCase(),
    );
  }

  // ── Per-card overflow on transcript meal cards (Phase 6.2 hooks) ──

  /// The plan meal a transcript [MealRef] stands for, matched by source id.
  static PlanMeal? _planMealFor(MealPlan? plan, MealRef meal) {
    if (plan == null) return null;
    for (final pm in plan.meals) {
      if (pm.source != meal.source) continue;
      final id = switch (meal.source) {
        MealSource.library => pm.libraryMealId,
        MealSource.saved => pm.savedMealId,
      };
      if (id == meal.id || pm.id == meal.id) return pm;
    }
    return null;
  }

  /// Swap from a transcript card: the meal sheet's inline swap picker is
  /// the existing flow, so open it on the matching plan meal.
  void _swapPicked(MealPlan? plan, MealRef meal) {
    final planMeal = _planMealFor(plan, meal);
    if (planMeal == null) return;
    final planController = ref.read(mealPlanControllerProvider.notifier);
    showMealSheet(
      context: context,
      ref: ref,
      meal: planMeal,
      onServings: (servings) =>
          planController.setServings(planMeal.id, servings),
      onSwap: _swapFromSheet,
      onRemove: () => planController.removeMeal(planMeal.id),
    );
  }

  /// The live conversation id (the opener's response header fills it in
  /// for a `c=new` conversation), else the route's.
  String? get _conversationId =>
      ref
          .read(
            vanaChatControllerProvider(
              kind: widget.kind,
              conversationId: widget.conversationId,
            ),
          )
          .value
          ?.conversationId ??
      widget.conversationId;

  /// Await a plan write and mirror the returned draft into the chat state.
  Future<MealPlan?> _applyDraft(Future<MealPlan?> write) async {
    final plan = await write;
    if (plan != null && mounted) _controller.applyDraftPlan(plan);
    return plan;
  }

  Future<void> _pickMeal(MealRef meal, int servings) async {
    final content = ref.read(contentServiceProvider);
    setState(
      () => _pickedInCurrentPicker = {..._pickedInCurrentPicker, meal.id},
    );
    try {
      // Scoped to THIS conversation's draft (never the week's active plan),
      // and mirrored into the chat state so the minimized bar updates.
      await _applyDraft(
        ref
            .read(mealPlanControllerProvider.notifier)
            .pickMeals(
              [MealPick(source: meal.source, id: meal.id)],
              servings: servings,
              conversationId: _conversationId,
            ),
      );
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

  /// `accept_rule` as the remote-ack UiAction (closes the 4c stopgap that
  /// sent "Accept the rule: …" as a chat message — a whole model turn with
  /// no ack and no plan fold).
  Future<void> _acceptRule(VanaRulePart part) async {
    final content = ref.read(contentServiceProvider);
    try {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .acceptRule(part.rule, conversationId: widget.conversationId);
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

  /// The athlete's `show_macros` setting (on by default — plan §2 Q-4).
  bool get _showMacros =>
      ref.read(vanaSettingsControllerProvider).value?.showMacros ?? true;

  Future<void> _openReviewSheet(BuildContext context, MealPlan plan) {
    final planController = ref.read(mealPlanControllerProvider.notifier);
    return showReviewSheet(
      context: context,
      ref: ref,
      plan: plan,
      showMacros: _showMacros,
      onTapMeal: (meal) => showMealSheet(
        context: context,
        ref: ref,
        meal: meal,
        onServings: (servings) => planController.setServings(meal.id, servings),
        onSwap: _swapFromSheet,
        onRemove: () => planController.removeMeal(meal.id),
      ),
      onServings: (meal, servings) =>
          planController.setServings(meal.id, servings),
      onRemove: (meal) => planController.removeMeal(meal.id),
      onConfirm: () async {
        try {
          await planController.confirmPlan();
          return true;
        } on Exception {
          return false;
        }
      },
      // Confirmed → the shopping list is the next thing the athlete needs
      // (the server has just built it). `go` leaves the chat behind rather
      // than stacking the Food tab on top of it.
      onConfirmed: () => context.go('/food?tab=shopping'),
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

/// One row of the transcript list: a turn or the day divider before it.
sealed class _TranscriptRow {
  const _TranscriptRow();
}

class _MessageRow extends _TranscriptRow {
  const _MessageRow(this.index, this.message);

  final int index;
  final VanaMessage message;
}

class _DividerRow extends _TranscriptRow {
  const _DividerRow(this.date);

  final DateTime date;
}

/// "Editing — sending will rewind the conversation" over the composer,
/// with a cancel `×` (Phase 6.1).
class _EditingStrip extends StatelessWidget {
  const _EditingStrip({
    required this.label,
    required this.cancelTooltip,
    required this.onCancel,
  });

  final String label;
  final String cancelTooltip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        key: const ValueKey('meal_planning.editing_strip'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.xxs,
          AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.electrolyte.withValues(alpha: isDark ? 0.12 : 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_outlined,
              size: 14,
              color: textColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('meal_planning.editing_cancel'),
              tooltip: cancelTooltip,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close,
                size: 16,
                color: textColor.withValues(alpha: 0.7),
              ),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// General chats' empty state: Vana's avatar over "Ask me anything", a line
/// about what she can reach for, then the three example questions as choice
/// chips (05 §4, prototype `ChatView`'s empty branch). Planning chats with
/// `c=new` stream the opener instead (handled by the parent).
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.kind, required this.onPick});

  final VanaConversationKind kind;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);

    final examples = [
      content.getValue(ContentKeys.mpGeneralExample1),
      content.getValue(ContentKeys.mpGeneralExample2),
      content.getValue(ContentKeys.mpGeneralExample3),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          const VanaAvatar(size: 48),
          const SizedBox(height: 10),
          Text(
            content.getValue(ContentKeys.mpEmptyTitle),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              content.getValue(ContentKeys.mpEmptyBody),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: muted,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              for (final example in examples)
                ChoiceChipButton(
                  key: ValueKey('meal_planning.general_example_$example'),
                  label: example,
                  onTap: () => onPick(example),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
