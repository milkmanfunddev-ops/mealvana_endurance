import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/activity_detail/activity_detail_app_bar.dart';
import '../widgets/activity_detail/activity_detail_action_buttons.dart';
import '../widgets/activity_detail/nutrition_sections_builder.dart';
import '../widgets/activity_detail/no_nutrition_plan_state.dart';
import '../widgets/activity_detail/single_sport_hero_image.dart';
import '../widgets/activity_detail/activity_schedule_info.dart';
import '../widgets/activity_detail/brick_header.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/activity_detail_controller.dart';
import '../../domain/carb_adjustment_level.dart';
import '../../../activities/domain/activity.dart';
import '../../../coach_mode/presentation/widgets/activity_coach_feedback_widget.dart';
import '../../../coach_mode/presentation/providers/coach_activity_detail_controller.dart';
import '../providers/activity_detail_state.dart';
import '../widgets/stale_plan_warning.dart';
import '../widgets/low_fuel_risk_badge.dart';
import '../../../formula_kit/presentation/widgets/pin_status_banner.dart';
import '../../../formula_kit/domain/pin_decision.dart';
import '../../domain/plan_section.dart';
import '../../../personal_templates/presentation/widgets/save_template_dialog.dart';
import '../../../personal_templates/presentation/providers/personal_templates_controller.dart';
import '../widgets/fuel_log/fuel_log_section_widget.dart';
import '../widgets/fuel_log/fuel_log_feedback_section.dart';
import '../widgets/fuel_log/fuel_log_success_overlay.dart';
import '../utils/activity_detail_helpers.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../integrations/presentation/widgets/garmin_attribution.dart';

/// Activity Detail Screen - Refactored with extracted widgets
/// Shows activity details with nutrition sections and food items
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    this.isNewActivity = false,
    this.isCoachView = false,
    this.fromTemplate = false,
  });

  final String activityId;
  final bool isNewActivity;
  final bool isCoachView;

  /// True when this activity was created from a template (hide "Save as Template" button)
  final bool fromTemplate;

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen>
    with TickerProviderStateMixin {
  bool _hasShownSwipeHint = false;
  bool _swipeHintChecked = false;

  /// Tracks whether we've already auto-routed this State instance to the
  /// fuel-log entry surface. Set true after the first push, also set true
  /// when the user actively dismisses the fuel-log screen so we honor their
  /// choice for the rest of this navigation session. Resets when this State
  /// is recreated (i.e., user navigates away and back).
  bool _didAutoRedirectToFuelLog = false;

  // Fuel log animation
  late final AnimationController _fuelLogAnimation;
  late final Animation<double> _heroFadeOut;
  late final Animation<double> _extrasFadeOut;
  late final Animation<double> _sectionsCrossfade;
  late final Animation<double> _feedbackFadeIn;

  // Fuel log feedback state (held locally for Done button)
  int _fuelLogRating = 0;
  int? _fuelLogNutritionRating;
  String? _fuelLogNotes;

  /// Activity IDs for which we've already emitted `pin_status_banner_shown`.
  /// Prevents re-firing the analytics event on rebuilds. Cleared with State.
  /// Formula Kit PR 2 substep 9.
  final Set<String> _pinBannerShownForActivities = <String>{};

  @override
  void initState() {
    super.initState();
    _checkSwipeHintShown();

    _fuelLogAnimation = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _heroFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fuelLogAnimation,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _extrasFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fuelLogAnimation,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _sectionsCrossfade = CurvedAnimation(
      parent: _fuelLogAnimation,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    );
    _feedbackFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fuelLogAnimation,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _fuelLogAnimation.dispose();
    super.dispose();
  }

  void _checkSwipeHintShown() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final controller = _getControllerNotifier();
      final hasShown = controller.checkSwipeHintShown(prefs);
      if (mounted) {
        setState(() {
          _hasShownSwipeHint = hasShown;
          _swipeHintChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasShownSwipeHint = true;
          _swipeHintChecked = true;
        });
      }
    }
  }

  bool _consumeSwipeHint() {
    if (!_swipeHintChecked) return false;
    if (_hasShownSwipeHint) return false;
    _hasShownSwipeHint = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final controller = _getControllerNotifier();
      controller.markSwipeHintShown(prefs);
    } catch (e) {
      // Silently fail
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<dynamic> activityDetailAsync = widget.isCoachView
        ? ref.watch(coachActivityDetailControllerProvider(widget.activityId))
        : ref.watch(
            activityDetailControllerProvider(
              activityId: widget.activityId,
              isNewActivity: widget.isNewActivity,
            ),
          );

    // Read fuel log mode from state for AppBar
    final isFuelLogMode =
        activityDetailAsync.whenOrNull(
          data: (data) {
            if (data is ActivityDetailState) return data.isFuelLogMode;
            return false;
          },
        ) ??
        false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ActivityDetailAppBar(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
        isCoachView: widget.isCoachView,
        onSaveTemplate: () => _showSaveTemplateDialog(context),
        onEdit: () => _navigateToEditActivity(context),
        onDelete: () => _showDeleteConfirmationDialog(context),
        onEditFuelLog: () => _enterFuelLogMode(),
        isFuelLogMode: isFuelLogMode,
        onDoneFuelLog: () => _completeFuelLog(context),
        onBackFromFuelLog: () => _exitFuelLogMode(),
      ),
      body: ContentArea(
        child: activityDetailAsync.when(
          data: (data) {
            final ActivityDetailState state;
            if (data is ActivityDetailState) {
              state = data;
            } else {
              final dynamic d = data;
              state = ActivityDetailState(
                activity: d.activity,
                nutritionPlan: d.nutritionPlan,
                completion: d.completion,
                scheduledDateTime: d.scheduledDateTime,
                isNewActivity: widget.isNewActivity,
                isSaving: d.isSaving ?? false,
                isCompleting: d.isCompleting ?? false,
                hasUnsavedChanges: d.hasUnsavedChanges ?? false,
                error: d.error,
                fuelLogViewMode: d.fuelLogViewMode ?? FuelLogViewMode.planned,
                fuelLogData: d.fuelLogData,
              );
            }
            return _buildContent(context, state);
          },
          loading: () => _buildLoadingState(context),
          error: (error, stack) => _buildErrorState(context, error),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loading activity...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: AppIconSizes.xxl,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Error Loading Activity',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              error.toString(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            KyleSecondaryButton(
              text: 'Go Back',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ActivityDetailState state) {
    final activity = state.activity;
    if (activity == null) {
      return _buildErrorState(context, 'No activity data available');
    }

    // Auto-route to fuel-log when this is a completed activity that has a
    // nutrition plan but hasn't been fuel-logged yet. Covers all entry paths
    // (push tap, list tap, calendar tap) so the user lands on the entry
    // surface instead of the post-completion satisfaction view. Skipped for
    // coach view and new-activity flows (different intent), and for activities
    // without a plan (Garmin auto-create case — keep activity-detail with the
    // existing "Generate plan" CTA).
    _maybeAutoRouteToFuelLog(state);

    return AnimatedBuilder(
      animation: _fuelLogAnimation,
      builder: (context, _) => RefreshIndicator(
        color: AppColors.electrolyte,
        onRefresh: () => _handlePullToRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xxl),

            // Hero section — fades out when entering fuel log
            FadeTransition(
              opacity: _heroFadeOut,
              child: _heroFadeOut.value > 0.01
                  ? _buildHeroSection(context, state)
                  : const SizedBox.shrink(),
            ),

            // Top spacing when hero is hidden
            if (_heroFadeOut.value <= 0.01)
              const SizedBox(height: AppSpacing.sm),

            // Pin status banner (Formula Kit PR 2 substep 9). Visible only
            // when the plan was generated with pins supplied — the algorithm
            // attaches PinDecision to each affected phase / sub-phase.
            if (_extrasFadeOut.value > 0.01)
              FadeTransition(
                opacity: _extrasFadeOut,
                child: _buildPinStatusBanner(context, state),
              ),

            // Stale plan warning (hidden during fuel log)
            if (activity.needsNutritionRefresh == true &&
                _extrasFadeOut.value > 0.01)
              FadeTransition(
                opacity: _extrasFadeOut,
                child: Column(
                  children: [
                    StalePlanWarning(
                      onRegeneratePlan: () =>
                          _handleRegeneratePlan(context, state),
                      isRegenerating: state.isSaving,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),

            if (state.hasStaleDuringTarget && _extrasFadeOut.value > 0.01)
              FadeTransition(
                opacity: _extrasFadeOut,
                child: Column(
                  children: [
                    StalePlanWarning(
                      title: 'Nutrition Settings Changed',
                      message:
                          state.staleDuringTargetMessage ??
                          'Nutrition settings changed. Regenerate plan to apply new targets.',
                      icon: Icons.tune,
                      onRegeneratePlan: () =>
                          _handleRegeneratePlan(context, state),
                      isRegenerating: state.isSaving,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),

            // Low fuel risk badge (hidden during fuel log)
            if (state.nutritionPlan != null && _extrasFadeOut.value > 0.01)
              FadeTransition(
                opacity: _extrasFadeOut,
                child: LowFuelRiskBadge(nutritionPlan: state.nutritionPlan!),
              ),

            // Planned/Actual toggle for completed activities with fuel log
            if (state.isCompleted && state.hasFuelLog && !state.isFuelLogMode)
              _buildFuelLogViewToggle(context, state),

            // Nutrition sections — crossfade between normal and fuel log
            if (state.nutritionPlan != null)
              _buildNutritionOrFuelLogSections(context, state),

            if (state.nutritionPlan == null)
              NoNutritionPlanState(
                activity: state.activity,
                onGeneratePlan: () =>
                    _navigateToGeneratePlan(context, state.activity),
              ),

            // Fuel log feedback (fades in during fuel log mode)
            if (_feedbackFadeIn.value > 0.01)
              FadeTransition(
                opacity: _feedbackFadeIn,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: FuelLogFeedbackSection(
                    initialRating: _fuelLogRating,
                    initialNutritionRating: _fuelLogNutritionRating,
                    initialNotes: _fuelLogNotes,
                    duringCarbRateGPerH:
                        ActivityDetailHelpers.computeDuringCarbRateGPerH(
                          activity: state.activity,
                          nutritionPlan: state.nutritionPlan,
                        ),
                    onRatingChanged: (rating) {
                      _fuelLogRating = rating;
                      final controller =
                          _getControllerNotifier() as ActivityDetailController;
                      controller.updateFuelLogFeedback(
                        overallSatisfaction: rating,
                      );
                    },
                    onNutritionRatingChanged: (rating) {
                      _fuelLogNutritionRating = rating;
                      final controller =
                          _getControllerNotifier() as ActivityDetailController;
                      controller.updateFuelLogFeedback(nutritionRating: rating);
                    },
                    onNotesChanged: (notes) {
                      _fuelLogNotes = notes;
                      final controller =
                          _getControllerNotifier() as ActivityDetailController;
                      controller.updateFuelLogFeedback(notes: notes);
                    },
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),
            // Collapsible coach feedback section (hidden during fuel log)
            if (_extrasFadeOut.value > 0.01) ...[
              FadeTransition(
                opacity: _extrasFadeOut,
                child: ActivityCoachFeedbackWidget(
                  activityId: widget.activityId,
                  isCoachView: widget.isCoachView,
                  activityUserId: activity.userId,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeTransition(
                opacity: _extrasFadeOut,
                child: ActivityDetailActionButtons(
                  state: state,
                  isNewActivity: widget.isNewActivity,
                  isCoachView: widget.isCoachView,
                  onSave: () => _saveWorkout(context, state),
                  onSaveAsTemplate:
                      (widget.isNewActivity &&
                          !widget.isCoachView &&
                          !widget.fromTemplate &&
                          state.nutritionPlan != null)
                      ? () => _showSaveTemplateDialog(context)
                      : null,
                  onComplete:
                      (rating, notes, {isBrick = false, carbAdjustment}) =>
                          _handleCompletion(
                            context,
                            state,
                            rating,
                            notes,
                            isBrick: isBrick,
                            carbAdjustment: carbAdjustment,
                          ),
                  onRatingChanged: (rating) {
                    final controller = _getControllerNotifier();
                    controller.updateCompletionRating(rating);
                  },
                  onNotesChanged: (notes) {
                    final controller = _getControllerNotifier();
                    controller.updateWorkoutNotes(notes);
                  },
                  onEnterFuelLog: () => _openFuelLogScreen(context),
                ),
              ),
            ],
            // Derived-data attribution required by Garmin Developer API
            // Brand Guidelines: when Garmin-reported activity data is used
            // as an input to our nutrition/insight calculations, we credit
            // the specific device (or fall back to "Garmin Connect").
            if (activity.hasGarminData &&
                _extrasFadeOut.value > 0.01) ...[
              const SizedBox(height: AppSpacing.md),
              FadeTransition(
                opacity: _extrasFadeOut,
                child: _GarminDerivedDataFooter(
                  deviceName: activity.garminDeviceName,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
      ),
    );
  }

  // ===========================================================================
  // FUEL LOG METHODS
  // ===========================================================================

  Widget _buildNutritionOrFuelLogSections(
    BuildContext context,
    ActivityDetailState state,
  ) {
    final crossfadeValue = _sectionsCrossfade.value;

    // Show fuel log sections in actual view mode for completed activities
    if (state.isCompleted &&
        state.hasFuelLog &&
        state.fuelLogViewMode == FuelLogViewMode.actual &&
        !state.isFuelLogMode) {
      return _buildFuelLogSections(context, state);
    }

    // During animation: crossfade and zoom between normal and fuel log
    if (crossfadeValue > 0.01 && crossfadeValue < 0.99) {
      return Stack(
        children: [
          Opacity(
            opacity: 1.0 - crossfadeValue,
            child: Transform.scale(
              scale: 1.0 + (crossfadeValue * 0.05), // Zoom out slightly
              child: _buildNormalNutritionSections(context, state),
            ),
          ),
          Opacity(
            opacity: crossfadeValue,
            child: Transform.scale(
              scale: 0.95 + (crossfadeValue * 0.05), // Zoom in from 0.95 to 1.0
              child: _buildFuelLogSections(context, state),
            ),
          ),
        ],
      );
    }

    // Fuel log mode active
    if (state.isFuelLogMode) {
      return _buildFuelLogSections(context, state);
    }

    // Normal mode
    return _buildNormalNutritionSections(context, state);
  }

  Widget _buildNormalNutritionSections(
    BuildContext context,
    ActivityDetailState state,
  ) {
    return NutritionSectionsBuilder(
      state: state,
      onSwapFood: (foodId, foodName, category) =>
          _swapFood(context, state, foodId, foodName, category),
      onDeleteFood: (foodId, category) =>
          _deleteFood(context, state, foodId, category),
      onUpdateQuantity: (foodId, category, newQuantity) =>
          _updateFoodQuantity(context, state, foodId, category, newQuantity),
      onAddFood: (category) => _addFood(context, category),
      onInitializeByHour: (cat, duration) {
        final controller = _getControllerNotifier();
        controller.initializeByHourData(cat, duration);
      },
      onMoveFoodToTimeSlot: (foodId, cat, sourceSlot, newSlot) {
        final controller = _getControllerNotifier();
        controller.moveFoodToTimeSlot(foodId, cat, sourceSlot, newSlot);
      },
      onPlaceFoodInSlot: (foodId, cat, slot, qty, timingCategory, isSip) {
        final controller = _getControllerNotifier();
        controller.placeFoodInSlot(
          foodId,
          cat,
          slot,
          qty,
          timingCategory: timingCategory,
          isSipThroughout: isSip,
        );
      },
      onRemoveFoodFromSlot: (foodId, cat, slot) {
        final controller = _getControllerNotifier();
        controller.removeFoodFromSlot(foodId, cat, slot);
      },
      onAdjustSlotQuantity: (foodId, cat, slot, delta) {
        final controller = _getControllerNotifier();
        controller.adjustSlotQuantity(foodId, cat, slot, delta);
      },
      onMoveSipFoodToSlot: (foodId, cat, slot, qty, timingCategory) {
        final controller = _getControllerNotifier();
        controller.moveSipFoodToSlot(
          foodId,
          cat,
          slot,
          qty,
          timingCategory: timingCategory,
        );
      },
      onScaleSubPhase: (subPhaseIndex, foodIndex, newQuantity) {
        final controller = _getControllerNotifier();
        controller.updateSubPhaseQuantityWithScaling(
          subPhaseIndex,
          foodIndex,
          newQuantity,
        );
      },
      consumeSwipeHint: _consumeSwipeHint,
      enableSectionHeroes: true,
      heroTagSeed: widget.activityId,
    );
  }

  Widget _buildFuelLogSections(
    BuildContext context,
    ActivityDetailState state,
  ) {
    final fuelLog = state.fuelLogData;
    if (fuelLog == null) return const SizedBox.shrink();

    final plan = state.nutritionPlan;
    if (plan == null) return const SizedBox.shrink();

    final activityType = state.activity?.activityType ?? ActivityType.running;

    final sectionWidgets = <Widget>[];

    for (final section in plan.sections) {
      final sectionId = section.id;
      final sectionItems = fuelLog.itemsForSection(sectionId);
      if (sectionItems.isEmpty && !state.isFuelLogMode) continue;

      final sectionColor = _sectionColor(context, sectionId);
      final sectionTitle = activityType.isBrick
          ? section.title
          : activityType.getSectionTitle(sectionId);

      // Group by sub-phase if applicable
      Map<String, List>? subPhaseGroups;
      if (section.hasSubPhases) {
        subPhaseGroups = {};
        for (final sp in section.subPhases!) {
          final spItems = fuelLog.itemsForSubPhase(sectionId, sp.subPhaseType);
          if (spItems.isNotEmpty) {
            subPhaseGroups[sp.subPhaseType] = spItems;
          }
        }
      }

      sectionWidgets.add(
        FuelLogSectionWidget(
          sectionId: sectionId,
          title: sectionTitle,
          items: sectionItems,
          sectionColor: sectionColor,
          subPhaseGroups: subPhaseGroups?.map((k, v) => MapEntry(k, v.cast())),
          isViewOnly: !state.isFuelLogMode,
          onIncrement: (foodId, secId) {
            final controller =
                _getControllerNotifier() as ActivityDetailController;
            controller.updateFuelLogItemQuantity(foodId, secId, 0.5);
          },
          onDecrement: (foodId, secId) {
            final controller =
                _getControllerNotifier() as ActivityDetailController;
            controller.updateFuelLogItemQuantity(foodId, secId, -0.5);
          },
          onAddFood: () => _addFood(context, sectionId),
        ),
      );
    }

    return Column(children: sectionWidgets);
  }

  Widget _buildFuelLogViewToggle(
    BuildContext context,
    ActivityDetailState state,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              label: 'Planned',
              isSelected: state.fuelLogViewMode == FuelLogViewMode.planned,
              onTap: () {
                final controller = _getControllerNotifier();
                if (state.fuelLogViewMode != FuelLogViewMode.planned) {
                  controller.toggleFuelLogViewMode();
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _ToggleChip(
              label: 'Actual',
              isSelected: state.fuelLogViewMode == FuelLogViewMode.actual,
              onTap: () {
                final controller = _getControllerNotifier();
                if (state.fuelLogViewMode != FuelLogViewMode.actual) {
                  controller.toggleFuelLogViewMode();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _sectionColor(BuildContext context, String sectionId) {
    if (sectionId.contains('during')) {
      return Theme.of(context).colorScheme.secondary;
    }
    if (sectionId.contains('after')) {
      return AppColors.dragonfruit;
    }
    return AppColors.orange;
  }

  /// Evaluates whether to push the fuel-log screen automatically and does
  /// it on the next frame. The caller can be inside a build path so we never
  /// trigger navigation synchronously. Idempotent — once we've redirected (or
  /// the user has dismissed), we won't redirect again until this State is
  /// recreated.
  void _maybeAutoRouteToFuelLog(ActivityDetailState state) {
    if (_didAutoRedirectToFuelLog) return;
    if (widget.isCoachView || widget.isNewActivity) return;

    final activity = state.activity;
    if (activity == null) return;
    if (!state.isCompleted) return;
    if (state.nutritionPlan == null) return;
    // hasFuelLog == activity?.fuelLogData != null. If they've already
    // logged what they ate, the existing planned/actual toggle path covers
    // them — no need to force them back into entry mode.
    if (state.hasFuelLog) return;

    _didAutoRedirectToFuelLog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Push the dedicated fuel-log screen on top of activity-detail. When
      // they close it (with or without saving), the pop returns here and
      // the flag suppresses a re-redirect for this State instance.
      await _openFuelLogScreen(context);
    });
  }

  void _enterFuelLogMode() {
    final controller = _getControllerNotifier() as ActivityDetailController;
    controller.enterFuelLogMode();
    _fuelLogRating = 0;
    _fuelLogNutritionRating = null;
    _fuelLogNotes = null;
    _fuelLogAnimation.forward();
  }

  Future<void> _openFuelLogScreen(BuildContext context) {
    return context.pushNamed(
      'fuel-log',
      extra: {
        'activityId': widget.activityId,
        'isNewActivity': widget.isNewActivity,
      },
    );
  }

  void _exitFuelLogMode() {
    _fuelLogAnimation.reverse().then((_) {
      if (mounted) {
        final controller = _getControllerNotifier() as ActivityDetailController;
        controller.exitFuelLogMode();
      }
    });
  }

  Future<void> _completeFuelLog(BuildContext context) async {
    if (_fuelLogRating <= 0) {
      MealvanaSnackbar.showWarning(
        context,
        'Please add a rating before completing',
      );
      return;
    }

    final controller = _getControllerNotifier() as ActivityDetailController;

    // Apply carb feedback if provided
    final carbAdjustment = CarbAdjustmentLevel.fromRatingValue(
      _fuelLogNutritionRating,
    );
    if (carbAdjustment != null) {
      await controller.applyCarbFeedbackAdjustment(
        carbAdjustment,
        isEdit: false,
      );
    }

    await controller.saveFuelLogAndComplete(
      overallSatisfaction: _fuelLogRating,
      textNotes: _fuelLogNotes,
      nutritionRating: _fuelLogNutritionRating,
    );

    if (!mounted) return;

    // Reset animation state
    _fuelLogAnimation.reset();

    // Show success overlay
    await FuelLogSuccessOverlay.show(
      context,
      onDismiss: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  Widget _buildHeroSection(BuildContext context, ActivityDetailState state) {
    final activity = state.activity;
    final activityType = activity?.activityType ?? ActivityType.running;
    final scheduledDateTime = state.scheduledDateTime ?? DateTime.now();

    // Check if this is a brick workout
    if (activity != null &&
        activity.isBrick &&
        activity.brickMetadata != null) {
      return BrickHeader(brick: activity, metadata: activity.brickMetadata!);
    }

    // Standard single-sport header
    final hasGarminData = activity?.hasGarminData ?? false;

    return Column(
      children: [
        SingleSportHeroImage(activityType: activityType),
        const SizedBox(height: AppSpacing.lg),
        ActivityScheduleInfo(
          scheduledDateTime: scheduledDateTime,
          activityType: activityType,
          distanceMiles: activity?.distanceMiles,
          durationMinutes: activity?.durationMinutes,
          paceTargetMinutesPerMile: activity?.paceTargetMinutesPerMile,
          onDateTap: widget.isCoachView
              ? null
              : () => _showDatePicker(context, state),
          onTimeTap: widget.isCoachView
              ? null
              : () => _showTimePicker(context, state),
        ),
        // Garmin brand attribution (required by Garmin API Brand Guidelines).
        // Shown on detail screens whenever the activity originated from a
        // Garmin Connect upload — uses "Garmin [device model]" form when
        // we know the specific device, else "Garmin Connect".
        if (hasGarminData) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: GarminAttribution(
              deviceName: activity?.garminDeviceName,
              style: GarminAttributionStyle.standard,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// Navigate to NewActivityScreen with activity details pre-filled
  ///
  /// Returns a Future that completes when the pushed route is popped.
  Future<Object?> _navigateToGeneratePlan(
    BuildContext context,
    Activity? activity,
  ) {
    if (activity == null) return Future.value(null);

    return context.pushNamed<Object>(
      'distance-pace-gut-entry',
      extra: {
        'initialDate': activity.scheduledDateTime,
        'distance': activity.distanceMiles,
        'initialDurationMinutes': activity.durationMinutes,
        'goalPace': activity.paceTargetMinutesPerMile,
        'initialTitle': activity.title,
        'activityId': activity.id,
        if (widget.isCoachView) 'forUserId': activity.userId,
        'activityType': activity.activityType.name,
        'timeBeforeMinutes': activity.timeBeforeMinutes,
        // Cycling-specific parameters
        'cyclingSpeedMph': activity.cyclingSpeedMph,
        'cyclingTerrain': activity.cyclingTerrain,
        'cyclingIndoorOutdoor': activity.cyclingIndoorOutdoor,
        'cyclingElevationGainFt': activity.cyclingElevationGainFt,
        'cyclingSessionGoal': activity.cyclingSessionGoal,
        // Swimming-specific parameters
        'swimmingPacePer100mSeconds': activity.swimmingPacePer100mSeconds,
        'swimmingPoolOrOpenWater': activity.swimmingPoolOrOpenWater,
        'swimmingWaterTempC': activity.swimmingWaterTempC,
      },
    );
  }

  /// Pull-to-refresh: force sync activity data from Supabase
  Future<void> _handlePullToRefresh() async {
    try {
      final controller = _getControllerNotifier();
      if (controller is ActivityDetailController) {
        await controller.forceRefresh();
      }
    } catch (e) {
      // Best-effort refresh
    }
  }

  /// Navigate to NewActivityScreen with all activity fields pre-populated for editing
  void _navigateToEditActivity(BuildContext context) {
    final AsyncValue<dynamic> activityDetailAsync = widget.isCoachView
        ? ref.read(coachActivityDetailControllerProvider(widget.activityId))
        : ref.read(
            activityDetailControllerProvider(
              activityId: widget.activityId,
              isNewActivity: widget.isNewActivity,
            ),
          );

    final data = activityDetailAsync.value;
    if (data == null) return;

    final Activity? activity;
    if (data is ActivityDetailState) {
      activity = data.activity;
    } else {
      activity = (data as dynamic).activity as Activity?;
    }

    if (activity == null) return;

    context.pushNamed(
      'distance-pace-gut-entry',
      extra: {
        'initialDate': activity.scheduledDateTime,
        'distance': activity.distanceMiles,
        'initialDurationMinutes': activity.durationMinutes,
        'goalPace': activity.paceTargetMinutesPerMile,
        'initialTitle': activity.title,
        'activityId': activity.id,
        if (widget.isCoachView) 'forUserId': activity.userId,
        'activityType': activity.activityType.name,
        'timeBeforeMinutes': activity.timeBeforeMinutes,
        // Cycling-specific
        'cyclingSpeedMph': activity.cyclingSpeedMph,
        'cyclingTerrain': activity.cyclingTerrain,
        'cyclingIndoorOutdoor': activity.cyclingIndoorOutdoor,
        'cyclingElevationGainFt': activity.cyclingElevationGainFt,
        'cyclingSessionGoal': activity.cyclingSessionGoal,
        // Swimming-specific
        'swimmingPacePer100mSeconds': activity.swimmingPacePer100mSeconds,
        'swimmingPoolOrOpenWater': activity.swimmingPoolOrOpenWater,
        'swimmingWaterTempC': activity.swimmingWaterTempC,
      },
    );
  }

  // Helper to get the correct controller notifier based on view mode
  dynamic _getControllerNotifier() {
    if (widget.isCoachView) {
      return ref.read(
        coachActivityDetailControllerProvider(widget.activityId).notifier,
      );
    }
    return ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ).notifier,
    );
  }

  // Action handlers
  void _saveWorkout(BuildContext context, ActivityDetailState state) async {
    final controller = _getControllerNotifier();

    await controller.saveActivity();

    if (!widget.isCoachView) {
      controller.trackEvent('workout_saved', {
        'activity_id': state.activity?.id,
        'has_nutrition_plan': state.nutritionPlan != null,
        'is_new_activity': state.isNewActivity,
        'is_coach_view': widget.isCoachView,
      });
    }

    if (context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'Changes saved successfully!');

      if (widget.isCoachView) {
        // Coach view: always navigate back to coach portal after save
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/coach-portal');
        }
      } else if (widget.isNewActivity) {
        context.go('/main');
      }
    }
  }

  /// Handle workout completion after dialog confirmation
  Future<void> _handleCompletion(
    BuildContext context,
    ActivityDetailState state,
    int rating,
    String? notes, {
    required bool isBrick,
    CarbAdjustmentLevel? carbAdjustment,
  }) async {
    final controller = _getControllerNotifier();

    // Apply carb feedback adjustment and track analytics BEFORE
    // completing activity, because completeActivity() calls
    // ref.invalidateSelf() which disposes the provider and makes
    // subsequent ref usage throw UnmountedRefException.
    if (carbAdjustment != null && !isBrick) {
      await controller.applyCarbFeedbackAdjustment(
        carbAdjustment,
        isEdit: false,
      );
    }

    controller.trackEvent('workout_completed', {
      'activity_id': state.activity?.id,
      'rating': rating,
      'has_notes': notes?.isNotEmpty ?? false,
      'is_coach_view': widget.isCoachView,
      'is_brick': isBrick,
      if (carbAdjustment != null) 'carb_adjustment': carbAdjustment.name,
    });

    await controller.completeActivity(
      overallSatisfaction: rating,
      textNotes: notes,
      nutritionRating: carbAdjustment?.ratingValue,
    );

    if (mounted) {
      final message = isBrick
          ? 'Brick workout completed successfully!'
          : 'Workout completed successfully!';
      MealvanaSnackbar.showSuccess(context, message);
    }
  }

  void _swapFood(
    BuildContext context,
    ActivityDetailState state,
    String foodId,
    String foodName,
    String category,
  ) {
    final controller = _getControllerNotifier();
    controller.trackEvent('swap_food_tapped', {
      'food_id': foodId,
      'food_name': foodName,
      'section': category,
      'is_coach_view': widget.isCoachView,
    });

    context.push(
      '/swap-food',
      extra: {
        'foodToSwapId': foodId,
        'foodToSwapName': foodName,
        'category': category,
        'activityId': widget.activityId,
        'isNewActivity': widget.isNewActivity,
        'isCoachView': widget.isCoachView,
      },
    );
  }

  Future<void> _deleteFood(
    BuildContext context,
    ActivityDetailState state,
    String foodId,
    String category,
  ) async {
    final controller = _getControllerNotifier();

    await controller.deleteFoodItem(foodId, category);

    if (mounted) {
      MealvanaSnackbar.showInfo(context, 'Food item removed');
    }
  }

  Future<void> _updateFoodQuantity(
    BuildContext context,
    ActivityDetailState state,
    String foodId,
    String category,
    double newQuantity,
  ) async {
    final controller = _getControllerNotifier();

    await controller.updateFoodQuantity(foodId, category, newQuantity);
  }

  void _addFood(BuildContext context, String category) {
    final controller = _getControllerNotifier();
    controller.trackEvent('add_food_tapped', {'section': category});

    context.push(
      '/swap-food',
      extra: {
        'foodToSwapId': null,
        'foodToSwapName': null,
        'category': category,
        'activityId': widget.activityId,
        'isNewActivity': widget.isNewActivity,
        'isCoachView': widget.isCoachView,
      },
    );
  }

  Future<void> _showDatePicker(
    BuildContext context,
    ActivityDetailState state,
  ) async {
    final currentDate = state.scheduledDateTime ?? DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        currentDate.hour,
        currentDate.minute,
      );
      final controller = _getControllerNotifier();
      await controller.updateScheduledDateTime(newDateTime);
    }
  }

  Future<void> _showTimePicker(
    BuildContext context,
    ActivityDetailState state,
  ) async {
    final currentDate = state.scheduledDateTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDate),
    );
    if (picked != null && mounted) {
      final newDateTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        picked.hour,
        picked.minute,
      );
      final controller = _getControllerNotifier();
      await controller.updateScheduledDateTime(newDateTime);
    }
  }

  /// Handle regenerate plan button tap for stale nutrition plans
  ///
  /// Navigates to NewActivityScreen with activity details pre-filled so the
  /// user goes through the full plan creation flow (v2/v3 edge functions).
  /// Awaits the navigation so the controller is invalidated when the user
  /// returns, ensuring the stale banner disappears after regeneration.
  Future<void> _handleRegeneratePlan(
    BuildContext context,
    ActivityDetailState state,
  ) async {
    if (state.activity == null) {
      MealvanaSnackbar.showError(context, 'Activity not found');
      return;
    }

    await _navigateToGeneratePlan(context, state.activity);

    if (!mounted) return;

    // Invalidate the controller to re-read the activity from the database,
    // picking up the cleared needsNutritionRefresh flag
    ref.invalidate(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ),
    );
  }

  /// Show dialog to save the current activity's nutrition plan as a template
  Future<void> _showSaveTemplateDialog(BuildContext context) async {
    // Read the current activity state from the provider
    final asyncState = ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ),
    );

    final state = asyncState.value;
    final activity = state?.activity;
    final nutritionPlan = state?.nutritionPlan;

    if (activity == null || nutritionPlan == null) {
      MealvanaSnackbar.showError(
        context,
        'No nutrition plan to save as template',
      );
      return;
    }

    final activityTypeDisplay = activity.isBrick
        ? 'Brick'
        : activity.activityType.displayName;

    final defaultName = activity.title.isNotEmpty
        ? activity.title
        : 'My Template';

    final templateName = await SaveTemplateDialog.show(
      context,
      defaultName: defaultName,
      activityTypeDisplay: activityTypeDisplay,
    );

    if (templateName == null || !mounted) return;

    final templatesController = ref.read(
      personalTemplatesControllerProvider.notifier,
    );

    final result = await templatesController.saveTemplate(
      activity: activity,
      nutritionPlan: nutritionPlan,
      templateName: templateName,
    );

    if (!mounted) return;

    switch (result) {
      case SaveTemplateResult.success:
        // Also save the workout itself
        final controller = _getControllerNotifier();
        await controller.saveActivity();
        if (!mounted) return;

        controller.trackEvent('workout_saved_with_template', {
          'activity_id': activity.id,
          'template_name': templateName,
          'is_new_activity': widget.isNewActivity,
        });

        MealvanaSnackbar.showSuccess(context, 'Workout and template saved!');
        if (widget.isNewActivity) {
          context.go('/main');
        }
      case SaveTemplateResult.limitReached:
        MealvanaSnackbar.showWarning(
          context,
          'Template limit reached ($kMaxTemplateCount). Delete one to save a new template.',
        );
      case SaveTemplateResult.error:
        MealvanaSnackbar.showError(
          context,
          'Failed to save template. Please try again.',
        );
    }
  }

  /// Show confirmation dialog before deleting activity
  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text(
          'Are you sure you want to delete this activity? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dragonfruit),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteActivity(context);
    }
  }

  /// Delete the current activity and navigate back
  Future<void> _deleteActivity(BuildContext context) async {
    final controller = _getControllerNotifier();
    final success = await controller.deleteActivity();

    if (mounted) {
      if (success) {
        MealvanaSnackbar.showSuccess(context, 'Activity deleted successfully');
        if (widget.isCoachView) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/coach-portal');
          }
        } else {
          context.go('/main');
        }
      } else {
        MealvanaSnackbar.showError(
          context,
          'Failed to delete activity. Please try again.',
        );
      }
    }
  }

  /// Build the Formula Kit pin status banner shown above StalePlanWarning.
  /// Returns SizedBox.shrink when there are no pin decisions to surface.
  /// Formula Kit PR 2 substep 9.
  Widget _buildPinStatusBanner(
    BuildContext context,
    ActivityDetailState state,
  ) {
    final plan = state.nutritionPlan;
    if (plan == null) return const SizedBox.shrink();

    final rows = _collectPinBannerRows(plan.sections);
    if (rows.isEmpty) return const SizedBox.shrink();

    // Fire `pin_status_banner_shown` once per activity per State instance.
    final activityId = state.activity?.id;
    if (activityId != null &&
        !_pinBannerShownForActivities.contains(activityId)) {
      _pinBannerShownForActivities.add(activityId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = ref.read(
          activityDetailControllerProvider(
            activityId: widget.activityId,
            isNewActivity: widget.isNewActivity,
          ).notifier,
        );
        controller.trackEvent('pin_status_banner_shown', {
          'activity_id': activityId,
          'rows': rows.length,
          'honored_count':
              rows.where((r) => r.decision.usedPin).length,
        });
      });
    }

    return PinStatusBanner(
      rows: rows,
      onExpanded: () {
        final controller = ref.read(
          activityDetailControllerProvider(
            activityId: widget.activityId,
            isNewActivity: widget.isNewActivity,
          ).notifier,
        );
        controller.trackEvent('pin_status_banner_expanded', {
          'activity_id': activityId,
          'rows': rows.length,
        });
      },
      onFormulaLibraryTapped: () {
        final controller = ref.read(
          activityDetailControllerProvider(
            activityId: widget.activityId,
            isNewActivity: widget.isNewActivity,
          ).notifier,
        );
        controller.trackEvent('pin_status_banner_formula_library_tapped', {
          'activity_id': activityId,
        });
        // push (not go) so back returns to this activity detail screen.
        context.push('/settings/food-preferences/formula-library');
      },
    );
  }

  /// Walk the plan and pull out every phase / sub-phase that carries a
  /// non-null [PinDecision]. Order matches user-facing flow: Before
  /// sub-phases (meal → snack → top-off) then During.
  List<PinStatusBannerRow> _collectPinBannerRows(List<PlanSection> sections) {
    final rows = <PinStatusBannerRow>[];
    for (final section in sections) {
      // Before-phase sub-phases each carry their own decision.
      if (section.subPhases != null) {
        for (final sub in section.subPhases!) {
          final decision = sub.pinDecision;
          if (decision != null) {
            rows.add(
              PinStatusBannerRow(
                label: _subPhaseLabel(sub.subPhaseType),
                decision: decision,
              ),
            );
          }
        }
      }
      // During section carries its decision at the section level.
      if (section.pinDecision != null) {
        rows.add(
          PinStatusBannerRow(
            label: _sectionLabel(section.id),
            decision: section.pinDecision!,
          ),
        );
      }
    }
    return rows;
  }

  String _subPhaseLabel(String subPhaseType) {
    switch (subPhaseType) {
      case 'meal':
        return 'Meal';
      case 'snack':
        return 'Snack';
      case 'top_up':
        return 'Top-Off';
      default:
        return subPhaseType;
    }
  }

  String _sectionLabel(String sectionId) {
    switch (sectionId) {
      case 'during_run':
      case 'during':
        return 'During';
      case 'before_run':
      case 'before':
        return 'Before';
      case 'after_run':
      case 'after':
        return 'After';
      default:
        return sectionId;
    }
  }
}

/// A simple toggle chip used in the Planned/Actual segmented control.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.orange
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _GarminDerivedDataFooter extends StatelessWidget {
  const _GarminDerivedDataFooter({required this.deviceName});

  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final trimmed = deviceName?.trim();
    final attributionTarget =
        (trimmed == null || trimmed.isEmpty) ? 'Garmin Connect' : 'Garmin $trimmed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GarminAttribution(
            deviceName: deviceName,
            style: GarminAttributionStyle.compact,
          ),
          const SizedBox(height: 4),
          Text(
            'Insights derived in part from $attributionTarget data.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
