import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/cooking_session_controller.dart';
import '../../application/meal_detail_controller.dart';
import '../widgets/choice_chip_button.dart';
import '../widgets/step_progress_dots.dart';
import '../widgets/timer_chip.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';

/// `/food/cook/:id` (05 §4): enters straight at step 1 → done. The screen
/// owns the platform side of cooking mode — wake lock held while cooking, a
/// local notification + vibration when a timer rings, then
/// `acknowledgeTimer`. Oversized left/right tap zones and swipes step
/// through; the ingredients drawer strikes items through.
class CookingModeScreen extends ConsumerStatefulWidget {
  const CookingModeScreen({super.key, required this.mealId});

  final String mealId;

  @override
  ConsumerState<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends ConsumerState<CookingModeScreen> {
  bool _drawerOpen = false;
  final Set<int> _announcedRinging = {};

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _onRinging(CookingSessionState state) {
    final controller = ref.read(
      cookingSessionControllerProvider(widget.mealId).notifier,
    );
    for (final entry in state.timers.entries) {
      final stepIndex = entry.key;
      for (final (timerIndex, timer) in entry.value.indexed) {
        if (!timer.rang) continue;
        final key = Object.hash(stepIndex, timerIndex);
        if (_announcedRinging.contains(key)) continue;
        _announcedRinging.add(key);
        _notifyRang(timer);
        controller.acknowledgeTimer(stepIndex, timerIndex);
      }
    }
  }

  Future<void> _notifyRang(StepTimerState timer) async {
    try {
      final canVibrate = await Vibration.hasVibrator();
      if (canVibrate) Vibration.vibrate(pattern: [400, 200, 400]);
    } on Exception {
      // Vibration unsupported on this device — the visual state still shows.
    }
    try {
      await FlutterLocalNotificationsPlugin().show(
        timer.timer.hashCode & 0x7fffffff,
        ref.read(contentServiceProvider).getValue(
          ContentKeys.mpCookTimerNotification,
        ),
        timer.timer.label,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          android: AndroidNotificationDetails(
            'cooking_timers',
            'Cooking timers',
          ),
        ),
      );
    } on Exception {
      // Notifications not initialized/permitted — the ringing chip is the
      // fallback UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final stateAsync = ref.watch(cookingSessionControllerProvider(widget.mealId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;

    return Scaffold(
      key: ValueKey('meal_planning.cook_${widget.mealId}'),
      backgroundColor: bg,
      body: stateAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(
              cookingSessionControllerProvider(widget.mealId),
            ),
            child: Text(content.getValue(ContentKeys.mpRetry)),
          ),
        ),
        data: (state) {
          // Wake lock intent follows the controller's phase (05 deviations).
          WakelockPlus.toggle(enable: state.wakeLockWanted);
          _onRinging(state);

          if (!state.hasSteps) return _NoSteps(onExit: () => context.pop());

          final controller = ref.read(
            cookingSessionControllerProvider(widget.mealId).notifier,
          );

          return SafeArea(
            child: Column(
              children: [
                // The bar is the same in every phase: close · meal · the
                // ingredients toggle, with the step counter appearing while
                // cooking (prototype's top bar).
                _CookBar(
                  name: state.detail.meal.name,
                  stepLabel: state.phase == CookingPhase.cooking
                      ? ContentKeys.format(
                          content.getValue(ContentKeys.mpCookStepOf),
                          {
                            'n': state.stepIndex + 1,
                            'total': state.stepCount,
                          },
                        )
                      : null,
                  drawerOpen: _drawerOpen,
                  onToggleDrawer: () =>
                      setState(() => _drawerOpen = !_drawerOpen),
                  onClose: () => context.pop(),
                ),
                if (state.phase == CookingPhase.cooking)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: StepProgressDots(
                      count: state.stepCount,
                      current: state.stepIndex,
                    ),
                  ),
                if (_drawerOpen)
                  _IngredientsDrawer(
                    state: state,
                    onIngredient: controller.toggleIngredient,
                  ),
                Expanded(
                  child: switch (state.phase) {
                    CookingPhase.cooking => _CookingPhase(
                      state: state,
                      onTimerToggle: (timer, running) {
                        final timerIndex = state.currentTimers.indexOf(timer);
                        if (running) {
                          controller.pauseTimer(state.stepIndex, timerIndex);
                        } else {
                          controller.startTimer(state.stepIndex, timerIndex);
                        }
                      },
                      onTimerReset: (timer) => controller.resetTimer(
                        state.stepIndex,
                        state.currentTimers.indexOf(timer),
                      ),
                      onBack: controller.back,
                      onNext: controller.next,
                      onDone: controller.finish,
                    ),
                    CookingPhase.done => _DonePhase(
                      state: state,
                      mealId: widget.mealId,
                      onStartOver: controller.startOver,
                      onExit: () => context.pop(),
                    ),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The bar carried across every cooking phase.
class _CookBar extends ConsumerWidget {
  const _CookBar({
    required this.name,
    required this.stepLabel,
    required this.drawerOpen,
    required this.onToggleDrawer,
    required this.onClose,
  });

  final String name;
  final String? stepLabel;
  final bool drawerOpen;
  final VoidCallback onToggleDrawer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('meal_planning.cook_close'),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(Icons.close, size: 22, color: textColor),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.foodTitle.copyWith(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stepLabel != null)
                  Text(
                    stepLabel!,
                    style: AppTextStyles.bodySmall.copyWith(color: secondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChipButton(
            key: const ValueKey('meal_planning.cook_ingredients_toggle'),
            label: content.getValue(
              drawerOpen
                  ? ContentKeys.mpCookHide
                  : ContentKeys.mpCookIngredients,
            ),
            dense: true,
            onTap: onToggleDrawer,
          ),
        ],
      ),
    );
  }
}

/// The ingredients drawer — tick an item to strike it through.
class _IngredientsDrawer extends StatelessWidget {
  const _IngredientsDrawer({required this.state, required this.onIngredient});

  final CookingSessionState state;
  final ValueChanged<int> onIngredient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.38,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.blackberryLight
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (i, ingredient) in state.detail.ingredients.indexed)
                InkWell(
                  onTap: () => onIngredient(i),
                  child: Opacity(
                    opacity: state.checkedIngredients.contains(i) ? 0.45 : 1,
                    child: SizedBox(
                      height: 42,
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: accent, width: 1.5),
                            ),
                            child: state.checkedIngredients.contains(i)
                                ? Icon(
                                    Icons.check,
                                    size: 12,
                                    color: accent,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ingredient.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: textColor,
                                decoration:
                                    state.checkedIngredients.contains(i)
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            ingredient.qty,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The meal has no written directions — nothing to step through.
class _NoSteps extends ConsumerWidget {
  const _NoSteps({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              content.getValue(ContentKeys.mpCookNoStepsTitle),
              style: AppTextStyles.sectionTitle.copyWith(color: textColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              content.getValue(ContentKeys.mpCookNoStepsBody),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ChoiceChipButton(
              label: content.getValue(ContentKeys.mpCookBackToMeal),
              onTap: onExit,
            ),
          ],
        ),
      ),
    );
  }
}

/// One step at a time: the step text fills the screen, its timers sit under
/// it, and the whole area is a back / next tap target.
class _CookingPhase extends ConsumerWidget {
  const _CookingPhase({
    required this.state,
    required this.onTimerToggle,
    required this.onTimerReset,
    required this.onBack,
    required this.onNext,
    required this.onDone,
  });

  final CookingSessionState state;
  final void Function(StepTimerState timer, bool running) onTimerToggle;
  final ValueChanged<StepTimerState> onTimerReset;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Oversized tap zones: the left quarter goes back, the right
              // quarter forward; a horizontal swipe does the same.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (d) {
                    if (d.primaryVelocity == null) return;
                    if (d.primaryVelocity! < 0) {
                      onNext();
                    } else {
                      onBack();
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onBack,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onNext,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The step itself, and its timers, sit above the tap zones so
              // the chips stay tappable.
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    8,
                    AppSpacing.md,
                    0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.currentStep,
                        key: ValueKey(
                          'meal_planning.cook_step_${state.stepIndex}',
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      if (state.currentTimers.isNotEmpty)
                        const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (state.currentTimers.isNotEmpty)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final timer in state.currentTimers)
                          TimerChip(
                            state: timer,
                            onToggle: () => onTimerToggle(timer, timer.running),
                            onReset: () => onTimerReset(timer),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ChoiceChipButton(
                    expand: true,
                    key: const ValueKey('meal_planning.cook_back'),
                    label: content.getValue(ContentKeys.mpCookBack),
                    enabled: !state.isFirstStep,
                    onTap: onBack,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: KylePrimaryButton(
                  key: ValueKey(
                    state.isLastStep
                        ? 'meal_planning.cook_done'
                        : 'meal_planning.cook_next',
                  ),
                  text: content.getValue(
                    state.isLastStep
                        ? ContentKeys.mpCookFinish
                        : ContentKeys.mpCookNextStep,
                  ),
                  height: 52,
                  onPressed: state.isLastStep ? onDone : onNext,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Done: the meal's name, then the one question worth asking — how was it.
class _DonePhase extends ConsumerWidget {
  const _DonePhase({
    required this.state,
    required this.mealId,
    required this.onStartOver,
    required this.onExit,
  });

  final CookingSessionState state;
  final String mealId;
  final VoidCallback onStartOver;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final vote = state.detail.vote;

    void setVote(int v) =>
        ref.read(mealDetailControllerProvider(mealId).notifier).vote(v);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        Text(
          ContentKeys.format(content.getValue(ContentKeys.mpCookDoneTitle), {
            'name': state.detail.meal.name,
          }),
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle.copyWith(
            color: textColor,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          content.getValue(ContentKeys.mpCookHowWasIt),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ChoiceChipButton(
                  expand: true,
                  key: const ValueKey('meal_planning.cook_vote_up'),
                  label: content.getValue(ContentKeys.mpCookVoteUp),
                  selected: vote == 1,
                  onTap: () => setVote(1),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ChoiceChipButton(
                  expand: true,
                  key: const ValueKey('meal_planning.cook_vote_down'),
                  label: content.getValue(ContentKeys.mpCookVoteDown),
                  selected: vote == -1,
                  onTap: () => setVote(-1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ChoiceChipButton(
                  expand: true,
                  key: const ValueKey('meal_planning.cook_start_over'),
                  label: content.getValue(ContentKeys.mpCookStartOver),
                  onTap: onStartOver,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KylePrimaryButton(
                key: const ValueKey('meal_planning.cook_exit'),
                text: content.getValue(ContentKeys.mpCookDone),
                height: 48,
                onPressed: onExit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
