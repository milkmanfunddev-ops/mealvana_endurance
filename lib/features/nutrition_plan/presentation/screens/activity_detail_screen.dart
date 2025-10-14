import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/plan_container.dart';
import '../widgets/macro_targets_widget.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../providers/nutrition_plan_controller.dart';
import '../providers/activity_detail_controller.dart';
import '../../domain/macro_targets.dart' as targets_model;
import '../providers/distance_page_gut_entry_controller.dart';

/// Activity Detail Screen - Shows nutrition plan and activity details
/// Handles both create mode (new activity) and view mode (existing activity)
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({
    super.key,
    this.mode = 'view',
    this.activityId,
    this.pendingActivityData,
    this.macroTargets,
  });

  final String mode; // 'create' or 'view'
  final String? activityId; // For view mode
  final PendingActivityData? pendingActivityData; // For create mode
  final targets_model.MacroTargets? macroTargets; // For create mode

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  String? _lastPlanId;
  int? _lastPlanUpdateCount;

  /// Get next Saturday at 7am as default date
  DateTime _getDefaultDateTime() {
    final now = DateTime.now();
    final daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
    final nextSaturday = now.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
    return DateTime(nextSaturday.year, nextSaturday.month, nextSaturday.day, 7, 0);
  }

  /// Format date/time for display
  String _formatDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('EEEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  }

  /// Show date/time picker
  Future<void> _showDateTimePicker(DateTime currentDateTime) async {
    final controller = ref.read(activityDetailControllerProvider(
      mode: widget.mode,
      activityId: widget.activityId,
      pendingActivityData: widget.pendingActivityData,
      macroTargets: widget.macroTargets,
    ).notifier);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary600,
              onPrimary: AppTheme.baseWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary600,
              onPrimary: AppTheme.baseWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !mounted) return;

    final newDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Update both the activity detail controller and the nutrition plan
    await controller.updateScheduledDateTime(newDateTime);

    // Also update the nutrition plan's runDateTime
    final planState = ref.read(nutritionPlanControllerProvider);
    planState.whenData((planData) {
      if (planData.plan != null) {
        ref
            .read(nutritionPlanControllerProvider.notifier)
            .updateRunDateTime(planData.plan!.id, newDateTime);
      }
    });
  }

  /// Handle save button press
  Future<void> _handleSave() async {
    final controller = ref.read(activityDetailControllerProvider(
      mode: widget.mode,
      activityId: widget.activityId,
      pendingActivityData: widget.pendingActivityData,
      macroTargets: widget.macroTargets,
    ).notifier);

    await controller.saveActivity();

    if (mounted && widget.mode == 'create') {
      // Pop any Navigator.push screens (like ActivityCreationScreen) before going to main
      // This handles the case where we went: TabsScreen -> ActivityCreationScreen (Navigator.push) -> adjust-macros (go_router) -> here
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // Now navigate to tabs screen
      context.go('/main');
    } else if (mounted) {
      // Stay on screen or go back
      context.go('/main');
    }
  }

  /// Show complete workout bottom sheet
  Future<void> _showCompleteWorkoutSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompleteWorkoutBottomSheet(
        onComplete: (overallSatisfaction, textNotes) async {
          final controller = ref.read(activityDetailControllerProvider(
            mode: widget.mode,
            activityId: widget.activityId,
            pendingActivityData: widget.pendingActivityData,
            macroTargets: widget.macroTargets,
          ).notifier);

          await controller.completeActivity(
            overallSatisfaction: overallSatisfaction,
            textNotes: textNotes,
          );

          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityDetailState = ref.watch(activityDetailControllerProvider(
      mode: widget.mode,
      activityId: widget.activityId,
      pendingActivityData: widget.pendingActivityData,
      macroTargets: widget.macroTargets,
    ));
    final planState = ref.watch(nutritionPlanControllerProvider);

    // Detect changes in nutrition plan to mark activity as changed
    planState.whenData((planData) {
      if (planData.plan != null) {
        final currentPlanId = planData.plan!.id;
        // Count all food items across all sections
        final currentUpdateCount = planData.plan!.sections
            .fold<int>(0, (sum, section) => sum + section.foodItems.length);

        // If plan exists and we've seen it before, check for changes
        if (_lastPlanId == currentPlanId && _lastPlanUpdateCount != null) {
          if (currentUpdateCount != _lastPlanUpdateCount) {
            // Plan has changed - mark as dirty
            final controller = ref.read(activityDetailControllerProvider(
              mode: widget.mode,
              activityId: widget.activityId,
              pendingActivityData: widget.pendingActivityData,
              macroTargets: widget.macroTargets,
            ).notifier);
            controller.markAsChanged();
          }
        }

        // Update tracking variables
        _lastPlanId = currentPlanId;
        _lastPlanUpdateCount = currentUpdateCount;
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/main');
            }
          },
        ),
        title: Text(
          widget.mode == 'create' ? 'New Activity' : 'Activity Details',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: activityDetailState.when(
        data: (state) => _buildContent(context, state, planState),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ActivityDetailState state,
    AsyncValue planState,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image at top (like original current_plan_screen)
          SizedBox(
            height: 200.h,
            width: double.infinity,
            child: Image.asset(
              'assets/images/checklist.png',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),

          SizedBox(height: 24.h),

          // Workout Reference Section (distance and pace)
          if (state.macroTargets != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(8.w, 0.h, 16.w, 12.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_run,
                      color: AppTheme.primary600,
                      size: 20.sp,
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        '${state.macroTargets!.metrics.distanceMi.toStringAsFixed(1)} miles at ${state.macroTargets!.metrics.formattedPace} pace',
                        style: AppTheme.textStyle.copyWith(
                          color: AppTheme.primary900,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Date/Time Section (simplified like original)
          _buildDateTimeSection(state),

          // Macro Targets Widget (if we have macro targets)
          if (state.macroTargets != null)
            planState.when(
              data: (planData) {
                if (planData.plan != null) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0.w),
                    child: MacroTargetsWidget(
                      plan: planData.plan!,
                      targets: state.macroTargets,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // SizedBox(height: 24.h),

          // Nutrition Plan Section with full functionality
          planState.when(
            data: (planData) {
              if (planData.plan != null) {
                return PlanContainer(
                  plan: planData.plan!,
                  macroTargets: state.macroTargets,
                  onFoodItemTap: (foodItemId) {
                    // Handle food item tap - expand details
                  },
                  onSwapFood: (foodItemId, foodName, category) {
                    context.push(
                      '/swap-food',
                      extra: {
                        'foodToSwapId': foodItemId,
                        'foodToSwapName': foodName,
                        'category': category,
                      },
                    );
                  },
                  onDeleteFood: (foodItemId, category) async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Food Item'),
                        content: const Text(
                          'Are you sure you want to remove this item from your plan?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: AppTheme.highlight600),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref
                          .read(nutritionPlanControllerProvider.notifier)
                          .deleteFoodItem(foodItemId, category);
                    }
                  },
                  onUpdateQuantity: (foodItemId, category, newQuantity) async {
                    await ref
                        .read(nutritionPlanControllerProvider.notifier)
                        .updateFoodQuantity(foodItemId, category, newQuantity);
                  },
                );
              } else {
                return _buildNoPlanState();
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildNoPlanState(),
          ),

          SizedBox(height: 16.h),

          // Action Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                if (state.isCreateMode) ...[
                  _buildSaveButton(state),
                ] else ...[
                  // Show Save button if there are unsaved changes (even if completed)
                  if (state.hasUnsavedChanges) ...[
                    _buildSaveChangesButton(state),
                    SizedBox(height: 12.h),
                  ],

                  // Edit Nutrition Plan button (only if not completed and no unsaved changes)
                  if (!state.isCompleted && !state.hasUnsavedChanges && state.macroTargets != null) ...[
                    _buildEditPlanButton(state),
                    SizedBox(height: 12.h),
                  ],

                  // Complete Workout button (only if not completed and no unsaved changes)
                  if (!state.isCompleted && !state.hasUnsavedChanges)
                    _buildCompleteWorkoutButton(state),

                  // Completion info (if completed and no unsaved changes)
                  if (state.isCompleted && !state.hasUnsavedChanges)
                    _buildCompletionInfo(state),
                ],
              ],
            ),
          ),

          SizedBox(height: 120.h), // Bottom padding for FAB
        ],
      ),
    );
  }

  Widget _buildDateTimeSection(ActivityDetailState state) {
    final planState = ref.watch(nutritionPlanControllerProvider);
    final dateTime = state.scheduledDateTime ?? _getDefaultDateTime();

    final displayDateTime = planState.when(
      data: (planData) => state.scheduledDateTime ?? planData.plan?.runDateTime ?? _getDefaultDateTime(),
      loading: () => dateTime,
      error: (_, __) => dateTime,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(8.w, 0.h, 16.w, 12.h),
        child: InkWell(
          onTap: () => _showDateTimePicker(displayDateTime),
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppTheme.primary600,
                  size: 20.sp,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    'Run scheduled for ${_formatDateTime(displayDateTime)}',
                    style: AppTheme.textStyle.copyWith(
                      color: AppTheme.primary900,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit,
                  color: AppTheme.baseGrey,
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoPlanState() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Text(
          'No nutrition plan available',
          style: TextStyle(
            fontSize: 14.sp,
            color: AppTheme.baseGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ActivityDetailState state) {
    return PrimaryButton(
      text: state.isSaving ? 'Saving...' : 'Save Activity',
      isLoading: state.isSaving,
      onPressed: state.isSaving ? null : _handleSave,
      width: double.infinity,
      height: 56.h,
    );
  }

  Widget _buildSaveChangesButton(ActivityDetailState state) {
    return PrimaryButton(
      text: state.isSaving ? 'Saving...' : 'Save Changes',
      isLoading: state.isSaving,
      onPressed: state.isSaving ? null : () async {
        final controller = ref.read(activityDetailControllerProvider(
          mode: widget.mode,
          activityId: widget.activityId,
          pendingActivityData: widget.pendingActivityData,
          macroTargets: widget.macroTargets,
        ).notifier);

        // Save the activity (this will save the nutrition plan changes)
        await controller.saveActivity();

        // Clear the unsaved changes flag
        controller.clearChanges();
      },
      width: double.infinity,
      height: 56.h,
    );
  }

  Widget _buildCompleteWorkoutButton(ActivityDetailState state) {
    return PrimaryButton(
      text: state.isCompleting ? 'Completing...' : 'Complete Workout',
      isLoading: state.isCompleting,
      onPressed: state.isCompleting ? null : _showCompleteWorkoutSheet,
      width: double.infinity,
      height: 56.h,
    );
  }

  Widget _buildCompletionInfo(ActivityDetailState state) {
    final completion = state.completion;
    if (completion == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.primary600.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Workout Completed',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.baseBlack,
                ),
              ),
              Text(
                _getEmojiForRating(completion.overallSatisfaction ?? 3),
                style: TextStyle(fontSize: 24.sp),
              ),
            ],
          ),
          if (completion.textNotes != null && completion.textNotes!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    completion.textNotes!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.baseGrey,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 18.sp, color: AppTheme.primary600),
                  onPressed: () => _showEditNotesDialog(state),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  icon: Icon(Icons.delete, size: 18.sp, color: AppTheme.highlight600),
                  onPressed: () => _handleDeleteNotes(state),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ] else ...[
            SizedBox(height: 12.h),
            TextButton.icon(
              onPressed: () => _showEditNotesDialog(state),
              icon: Icon(Icons.add, size: 18.sp),
              label: const Text('Add notes'),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmojiForRating(int rating) {
    switch (rating) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  Future<void> _showEditNotesDialog(ActivityDetailState state) async {
    final controller = TextEditingController(text: state.completion?.textNotes ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout Notes'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'How did it go? Any observations?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.primary600, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final activityController = ref.read(activityDetailControllerProvider(
        mode: widget.mode,
        activityId: widget.activityId,
        pendingActivityData: widget.pendingActivityData,
        macroTargets: widget.macroTargets,
      ).notifier);

      await activityController.updateWorkoutNotes(result.isEmpty ? null : result);
    }

    controller.dispose();
  }

  Future<void> _handleDeleteNotes(ActivityDetailState state) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notes'),
        content: const Text('Are you sure you want to delete these workout notes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppTheme.highlight600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final activityController = ref.read(activityDetailControllerProvider(
        mode: widget.mode,
        activityId: widget.activityId,
        pendingActivityData: widget.pendingActivityData,
        macroTargets: widget.macroTargets,
      ).notifier);

      await activityController.updateWorkoutNotes(null);
    }
  }

  Widget _buildEditPlanButton(ActivityDetailState state) {
    return SecondaryButton(
      text: 'Edit Nutrition Plan',
      onPressed: () {
        // Navigate to distance/pace/gut entry screen
        // The user will re-enter their distance/pace/gut level to regenerate the plan
        context.push('/distance-pace-gut-entry');
      },
      width: double.infinity,
      height: 56.h,
    );
  }
}

/// Complete Workout Bottom Sheet
class _CompleteWorkoutBottomSheet extends StatefulWidget {
  const _CompleteWorkoutBottomSheet({
    required this.onComplete,
  });

  final Function(int overallSatisfaction, String? textNotes) onComplete;

  @override
  State<_CompleteWorkoutBottomSheet> createState() => _CompleteWorkoutBottomSheetState();
}

class _CompleteWorkoutBottomSheetState extends State<_CompleteWorkoutBottomSheet> {
  int _overallSatisfaction = 3;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getEmojiForRating(int rating) {
    switch (rating) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Complete Workout',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary900,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, size: 24.w),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Emoji Slider
          Text(
            'How was it?',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.baseBlack,
            ),
          ),
          SizedBox(height: 16.h),

          // Emoji display
          Center(
            child: Text(
              _getEmojiForRating(_overallSatisfaction),
              style: TextStyle(fontSize: 48.sp),
            ),
          ),

          SizedBox(height: 8.h),

          // Slider
          Slider(
            value: _overallSatisfaction.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: AppTheme.primary600,
            onChanged: (value) {
              setState(() => _overallSatisfaction = value.round());
            },
          ),

          SizedBox(height: 20.h),

          // Notes TextField
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Workout Notes (optional)',
              hintText: 'How did it go? Any observations?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: AppTheme.primary600, width: 2),
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Save Button
          PrimaryButton(
            text: 'Save Completion',
            onPressed: () {
              widget.onComplete(
                _overallSatisfaction,
                _notesController.text.isEmpty ? null : _notesController.text,
              );
            },
            width: double.infinity,
            height: 56.h,
          ),
        ],
      ),
    );
  }
}
