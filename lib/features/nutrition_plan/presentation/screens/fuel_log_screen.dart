import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';
import '../../domain/carb_adjustment_level.dart';
import '../../domain/fuel_log_data.dart';
import '../providers/activity_detail_controller.dart';
import '../providers/activity_detail_state.dart';
import '../utils/activity_detail_helpers.dart';
import '../widgets/fuel_log/fuel_log_feedback_section.dart';
import '../widgets/fuel_log/fuel_log_no_plan_state.dart';
import '../widgets/fuel_log/fuel_log_section_widget.dart';
import '../widgets/fuel_log/fuel_log_success_overlay.dart';

class FuelLogScreen extends ConsumerStatefulWidget {
  const FuelLogScreen({
    super.key,
    required this.activityId,
    required this.isNewActivity,
  });

  final String activityId;
  final bool isNewActivity;

  @override
  ConsumerState<FuelLogScreen> createState() => _FuelLogScreenState();
}

class _FuelLogScreenState extends ConsumerState<FuelLogScreen> {
  bool _didInitializeFuelLog = false;
  bool _didCompleteFuelLog = false;

  int _fuelLogRating = 0;
  int? _fuelLogNutritionRating;
  String? _fuelLogNotes;

  /// Cached controller reference so we can safely call it in dispose()
  /// without touching ref after deactivation.
  ActivityDetailController? _cachedController;

  ActivityDetailController _controller() {
    final ctrl = ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ).notifier,
    );
    _cachedController = ctrl;
    return ctrl;
  }

  @override
  void dispose() {
    if (!_didCompleteFuelLog) {
      final controller = _cachedController;
      if (controller != null) {
        // Defer provider modification to avoid modifying state during dispose.
        Future.microtask(() => controller.exitFuelLogMode());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _closeWithoutSaving,
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log Workout Fuel',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Adjust what you consumed',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          // Done is meaningful only when there's a plan to save against.
          // The no-plan empty state surfaces its own close affordance.
          if (asyncState.value?.nutritionPlan != null)
            TextButton(
              onPressed: asyncState.isLoading
                  ? null
                  : () async {
                      final state = asyncState.value;
                      if (state != null) {
                        await _completeFuelLog();
                      }
                    },
              child: Text(
                'Done',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ContentArea(
        child: asyncState.when(
          loading: _buildLoadingState,
          error: (error, _) => _buildErrorState(context, error),
          data: (state) {
            _initializeFuelLogIfReady(state);
            return _buildContent(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppIconSizes.xxl,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load fuel log',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error.toString(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ActivityDetailState state) {
    final plan = state.nutritionPlan;

    // No-plan empty state: the activity arrived from a connected provider
    // (typically Garmin) without a nutrition plan. The fuel-log surface still
    // opens — both because the activity-upload push routes here, and so the
    // user has a clear path to either generate a plan or just close out.
    if (plan == null && state.activity != null && !state.isSaving) {
      return FuelLogNoPlanState(
        activity: state.activity!,
        onGeneratePlan: _handleGeneratePlanFromEmptyState,
        onClose: _closeWithoutSaving,
      );
    }

    final fuelLog =
        state.fuelLogData ??
        (plan != null ? FuelLogData.fromNutritionPlan(plan) : null);
    if (plan == null || fuelLog == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show Garmin attribution when the activity displays Garmin-sourced data,
    // including TP/FS-planned workouts completed by a Garmin push.
    final hasGarminData = state.activity?.hasGarminData ?? false;

    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          if (hasGarminData) ...[
            // Required by Garmin Developer API Brand Guidelines whenever
            // screens display data derived from a Garmin Connect upload.
            GarminAttributionMessage(
              deviceName: state.activity?.garminDeviceName,
              subject: 'Workout calories and duration',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildFuelLogSections(context, state, fuelLog),
          const SizedBox(height: AppSpacing.md),
          FuelLogFeedbackSection(
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
              _controller().updateFuelLogFeedback(overallSatisfaction: rating);
            },
            onNutritionRatingChanged: (rating) {
              _fuelLogNutritionRating = rating;
              _controller().updateFuelLogFeedback(nutritionRating: rating);
            },
            onNotesChanged: (notes) {
              _fuelLogNotes = notes;
              _controller().updateFuelLogFeedback(notes: notes);
            },
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildFuelLogSections(
    BuildContext context,
    ActivityDetailState state,
    FuelLogData fuelLog,
  ) {
    final plan = state.nutritionPlan;
    if (plan == null) return const SizedBox.shrink();

    final activityType = state.activity?.activityType ?? ActivityType.running;
    final sectionWidgets = <Widget>[];

    for (final section in plan.sections) {
      final sectionId = section.id;
      final sectionItems = fuelLog.itemsForSection(sectionId);
      final sectionColor = _sectionColor(context, sectionId);
      final sectionTitle = activityType.isBrick
          ? section.title
          : activityType.getSectionTitle(sectionId);

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
          subPhaseGroups: subPhaseGroups?.map(
            (k, v) => MapEntry(k, v.cast()),
          ),
          isViewOnly: false,
          onIncrement: (foodId, secId) {
            _controller().updateFuelLogItemQuantity(foodId, secId, 0.5);
          },
          onDecrement: (foodId, secId) {
            _controller().updateFuelLogItemQuantity(foodId, secId, -0.5);
          },
          onAddFood: () => _addFood(context, sectionId),
        ),
      );
    }

    return Column(children: sectionWidgets);
  }

  void _initializeFuelLogIfReady(ActivityDetailState state) {
    if (_didInitializeFuelLog) return;
    if (state.nutritionPlan == null) return;
    if (state.isFuelLogMode && state.fuelLogData != null) {
      _didInitializeFuelLog = true;
      return;
    }

    _didInitializeFuelLog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller().enterFuelLogMode();
    });
  }

  Future<void> _closeWithoutSaving() async {
    _controller().exitFuelLogMode();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/plan', extra: {'activityId': widget.activityId});
    }
  }

  Future<void> _completeFuelLog() async {
    if (_fuelLogRating <= 0) {
      MealvanaSnackbar.showWarning(
        context,
        'Please add a rating before completing',
      );
      return;
    }

    final carbAdjustment = CarbAdjustmentLevel.fromRatingValue(
      _fuelLogNutritionRating,
    );
    if (carbAdjustment != null) {
      await _controller().applyCarbFeedbackAdjustment(
        carbAdjustment,
        isEdit: false,
      );
    }

    await _controller().saveFuelLogAndComplete(
      overallSatisfaction: _fuelLogRating,
      textNotes: _fuelLogNotes,
      nutritionRating: _fuelLogNutritionRating,
    );

    if (!mounted) return;
    _didCompleteFuelLog = true;

    await FuelLogSuccessOverlay.show(
      context,
      onDismiss: () {
        if (!mounted) return;
        Navigator.of(context).pop();
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/plan', extra: {'activityId': widget.activityId});
        }
      },
    );
  }

  void _addFood(BuildContext context, String category) {
    context.push(
      '/swap-food',
      extra: {
        'foodToSwapId': null,
        'foodToSwapName': null,
        'category': category,
        'activityId': widget.activityId,
        'isNewActivity': widget.isNewActivity,
        'isCoachView': false,
      },
    );
  }

  /// Routes the user from the no-plan empty state into plan generation. The
  /// fuel-log screen pops first (so we don't leave a stale fuel-log on the
  /// stack); the activity detail screen owns the actual generate flow.
  void _handleGeneratePlanFromEmptyState() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/plan', extra: {'activityId': widget.activityId});
    }
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
}
