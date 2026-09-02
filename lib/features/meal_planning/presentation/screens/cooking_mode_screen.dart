import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/cooking_session_controller.dart';
import '../widgets/step_progress_dots.dart';
import '../widgets/timer_chip.dart';

/// `/food/cook/:id` (05 §4): overview → cooking → done. The screen owns the
/// platform side of cooking mode — wake lock held only while cooking, a
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
          return switch (state.phase) {
            CookingPhase.overview => _OverviewPhase(
              state: state,
              onStart: () => ref
                  .read(cookingSessionControllerProvider(widget.mealId).notifier)
                  .start(),
            ),
            CookingPhase.cooking => _CookingPhase(
              state: state,
              drawerOpen: _drawerOpen,
              onToggleDrawer: () => setState(() => _drawerOpen = !_drawerOpen),
              onIngredient: (i) => ref
                  .read(cookingSessionControllerProvider(widget.mealId).notifier)
                  .toggleIngredient(i),
              onTimerToggle: (timer, running) {
                final controller = ref.read(
                  cookingSessionControllerProvider(widget.mealId).notifier,
                );
                final stepIndex = state.stepIndex;
                final timerIndex = state.currentTimers.indexOf(timer);
                if (running) {
                  controller.pauseTimer(stepIndex, timerIndex);
                } else {
                  controller.startTimer(stepIndex, timerIndex);
                }
              },
              onTimerReset: (timer) {
                final controller = ref.read(
                  cookingSessionControllerProvider(widget.mealId).notifier,
                );
                controller.resetTimer(
                  state.stepIndex,
                  state.currentTimers.indexOf(timer),
                );
              },
              onBack: () => ref
                  .read(cookingSessionControllerProvider(widget.mealId).notifier)
                  .back(),
              onNext: () => ref
                  .read(cookingSessionControllerProvider(widget.mealId).notifier)
                  .next(),
              onDone: () {
                ref
                    .read(
                      cookingSessionControllerProvider(widget.mealId).notifier,
                    )
                    .finish();
              },
            ),
            CookingPhase.done => _DonePhase(
              state: state,
              onStartOver: () => ref
                  .read(cookingSessionControllerProvider(widget.mealId).notifier)
                  .startOver(),
              onExit: () => context.pop(),
            ),
          };
        },
      ),
    );
  }
}

class _OverviewPhase extends ConsumerWidget {
  const _OverviewPhase({required this.state, required this.onStart});

  final CookingSessionState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final detail = state.detail;

    if (!state.hasSteps) {
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
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(content.getValue(ContentKeys.mpCookDone)),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BackButton(),
            if (detail.image?.url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: Image.network(
                  detail.image!.url,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              detail.meal.name,
              style: AppTextStyles.pageTitle.copyWith(color: textColor),
            ),
            Text(
              '${state.stepCount} steps · ${detail.prep ?? ''} · ${detail.servings} servings'
                  .replaceAll(' ·  · ', ' · '),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  size: 12,
                  color: secondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    content.getValue(ContentKeys.mpCookAiDisclaimer),
                    style: AppTextStyles.bodySmall.copyWith(color: secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              content.getValue(ContentKeys.mpCookIngredients),
              style: AppTextStyles.sectionTitle.copyWith(
                color: textColor,
                fontSize: 18,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final ingredient in detail.ingredients)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ingredient.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: textColor,
                              ),
                            ),
                          ),
                          if (ingredient.qty.isNotEmpty)
                            Text(
                              ingredient.qty,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('meal_planning.cook_start'),
                onPressed: onStart,
                style: TextButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.16),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                child: Text(
                  ContentKeys.format(
                    content.getValue(ContentKeys.mpCookStartStep),
                    {'n': state.stepCount},
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.blackberry,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookingPhase extends ConsumerWidget {
  const _CookingPhase({
    required this.state,
    required this.drawerOpen,
    required this.onToggleDrawer,
    required this.onIngredient,
    required this.onTimerToggle,
    required this.onTimerReset,
    required this.onBack,
    required this.onNext,
    required this.onDone,
  });

  final CookingSessionState state;
  final bool drawerOpen;
  final VoidCallback onToggleDrawer;
  final ValueChanged<int> onIngredient;
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
    final secondary = textColor.withValues(alpha: 0.65);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                IconButton(
                  icon: FaIcon(FontAwesomeIcons.barsStaggered, size: 18),
                  color: secondary,
                  onPressed: onToggleDrawer,
                ),
                Expanded(
                  child: StepProgressDots(
                    count: state.stepCount,
                    current: state.stepIndex,
                  ),
                ),
                Text(
                  ContentKeys.format(
                    content.getValue(ContentKeys.mpCookStepOf),
                    {'n': state.stepIndex + 1, 'total': state.stepCount},
                  ),
                  style: AppTextStyles.bodySmall.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          if (state.currentTimers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.xs,
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
          Expanded(
            child: GestureDetector(
              // Oversized tap zones: left third back, right two-thirds next
              // (05 §4); horizontal swipes do the same.
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < 0) {
                  onNext();
                } else {
                  onBack();
                }
              },
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBack,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onNext,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Text(
              state.currentStep,
              key: ValueKey('meal_planning.cook_step_${state.stepIndex}'),
              textAlign: TextAlign.center,
              style: AppTextStyles.pageTitle.copyWith(
                color: textColor,
                fontSize: 22,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('meal_planning.cook_back'),
                    onPressed: onBack,
                    child: Text(content.getValue(ContentKeys.mpCookBack)),
                  ),
                ),
                Expanded(
                  child: state.isLastStep
                      ? TextButton(
                          key: const ValueKey('meal_planning.cook_done'),
                          onPressed: onDone,
                          child: Text(
                            content.getValue(ContentKeys.mpCookDone),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : TextButton(
                          key: const ValueKey('meal_planning.cook_next'),
                          onPressed: onNext,
                          child: Text(
                            content.getValue(ContentKeys.mpCookNext),
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (drawerOpen)
            SizedBox(
              height: 220,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                children: [
                  for (final (i, ingredient) in state.detail.ingredients.indexed)
                    CheckboxListTile(
                      dense: true,
                      value: state.checkedIngredients.contains(i),
                      onChanged: (_) => onIngredient(i),
                      title: Text(
                        '${ingredient.name}${ingredient.qty.isEmpty ? '' : ' — ${ingredient.qty}'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: textColor,
                          decoration: state.checkedIngredients.contains(i)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonePhase extends ConsumerWidget {
  const _DonePhase({
    required this.state,
    required this.onStartOver,
    required this.onExit,
  });

  final CookingSessionState state;
  final VoidCallback onStartOver;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.circleCheck, color: accent, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            content.getValue(ContentKeys.mpCookDoneThanks),
            style: AppTextStyles.sectionTitle.copyWith(color: textColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            key: const ValueKey('meal_planning.cook_start_over'),
            onPressed: onStartOver,
            child: Text(content.getValue(ContentKeys.mpCookStartOver)),
          ),
          TextButton(
            key: const ValueKey('meal_planning.cook_exit'),
            onPressed: onExit,
            child: Text(
              content.getValue(ContentKeys.mpCookDone),
              style: AppTextStyles.bodyMedium.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
