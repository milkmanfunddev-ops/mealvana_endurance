import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../widgets/adjust_macros/edit_macros_dialog_widget.dart';
import '../widgets/adjust_macros/help_bottom_sheet_widget.dart';
import '../utils/macro_helpers.dart';
import '../../../../shared/widgets/generating_plan_overlay.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/macro_targets_controller.dart';
import '../providers/brick_input_controller.dart';
import '../../domain/macro_targets.dart' as domain;
import '../../../../core/utils/debug_logger.dart';
import '../../../../shared/domain/activity_type.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import '../utils/unit_formatter.dart';
import '../../../../shared/widgets/content_area.dart';

/// Adjust Macros Screen - Refactored with extracted widgets
/// Simplified from 1,005 lines using extracted components
class AdjustMacrosScreen extends ConsumerStatefulWidget {
  const AdjustMacrosScreen({super.key});

  @override
  ConsumerState<AdjustMacrosScreen> createState() => _AdjustMacrosScreenState();
}

class _AdjustMacrosScreenState extends ConsumerState<AdjustMacrosScreen> {
  @override
  void dispose() {
    // ⚠️ IMPORTANT: Cannot use ref.read() in dispose() - violates Riverpod safety
    // Draft cleanup is now handled by MacroTargetsController.ref.onDispose()
    // See: macro_targets_controller.dart for cleanup implementation
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(macroTargetsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, ref, asyncState.value),
      body: ContentArea(
        child: Stack(
          children: [
            asyncState.when(
              data: (state) => _buildContent(context, ref, state),
              loading: () => _buildLoadingState(context),
              error: (error, stackTrace) =>
                  _buildErrorState(context, ref, error),
            ),
            if (asyncState.value?.isCreatingPlan == true)
              const GeneratingPlanOverlay(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState? state,
  ) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          CustomAppBarBackButton(
            key: const ValueKey('adjust_macros.back_button'),
            onPressed: () => context.pop(),
            margin: EdgeInsets.zero,
            iconColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            key: const ValueKey('adjust_macros.title'),
            state?.adjustMacrosTitle ?? 'Adjust Your Macros',
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 17,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
  ) {
    if (state.macroTargets == null) {
      DebugLogger.error(
        '❌ ADJUST MACROS: Showing NO DATA state - this should not happen!',
      );
      return _buildNoDataState(context);
    }

    final macros = state.macroTargets!;
    final isBrick = macros.activityType == ActivityType.brick;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildActivityHeader(context, state),
          // Show per-segment pace/burn for bricks, single pace/burn for other sports
          if (isBrick)
            _buildBrickPaceBurnStats(context, ref, macros)
          else
            _buildPaceBurnStats(context, state, macros),
          _buildMacroTargetsSection(context, ref, state, macros),
          const SizedBox(height: 12),
          _buildActionButtons(context, ref, state, macros),
          const SizedBox(height: 16),
          _buildCreatePlanButton(context, ref, state),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActivityHeader(BuildContext context, MacroTargetsState state) {
    final activityTypeText = MacroHelpers.getActivityTypeText(
      state.macroTargets,
    );
    final activityInfo = MacroHelpers.formatActivityInfo(state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        children: [
          Text(
            key: const ValueKey('adjust_macros.activity_summary'),
            activityTypeText,
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (activityInfo.isNotEmpty)
            Text(
              activityInfo,
              style: TextStyle(
                fontFamily: 'Compadre',
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildPaceBurnStats(
    BuildContext context,
    MacroTargetsState state,
    domain.MacroTargets macros,
  ) {
    final pace = MacroHelpers.formatPaceValue(state);
    final totalBurn =
        '${macros.metrics.caloriesNetKcal.round().toString()} kcal';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: PaceBurnDisplay(
        pace: pace,
        totalBurn: totalBurn,
        backgroundColor: Colors.transparent,
        paceStatKey: const ValueKey('adjust_macros.pace_stat'),
        burnStatKey: const ValueKey('adjust_macros.calories_stat'),
      ),
    );
  }

  /// Build pace/burn stats for brick workouts - shows one widget per segment in a row
  Widget _buildBrickPaceBurnStats(
    BuildContext context,
    WidgetRef ref,
    domain.MacroTargets macros,
  ) {
    final brickFormState = ref.watch(brickInputControllerProvider);
    final segmentInputs = brickFormState.segmentInputs;
    final sportOrder = brickFormState.sportOrder;

    // Filter to only selected sports in order
    final orderedSelectedSports = sportOrder
        .where((sport) => brickFormState.selectedSports.contains(sport))
        .toList();

    // If no segments, show total burn only
    if (orderedSelectedSports.isEmpty) {
      final totalBurn = '${macros.metrics.caloriesNetKcal.round()} kcal';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Center(
          child: Text(
            'Total: $totalBurn',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: orderedSelectedSports.map((sport) {
          final input = segmentInputs[sport];
          if (input == null) {
            return const SizedBox.shrink();
          }

          // Format pace based on sport type
          String pace;
          String sportLabel;

          switch (sport) {
            case 'swimming':
              final paceSec = input.pacePer100mSeconds ?? 120;
              final minutes = paceSec ~/ 60;
              final seconds = paceSec % 60;
              pace = '$minutes:${seconds.toString().padLeft(2, '0')}/100m';
              sportLabel = 'SWIM';
              break;
            case 'cycling':
              final speed = input.speedMph ?? 15.0;
              pace = '${speed.toStringAsFixed(1)} mph';
              sportLabel = 'BIKE';
              break;
            case 'running':
              final paceMin = input.paceMinutesPerMile ?? 9.0;
              final minutes = paceMin.floor();
              final seconds = ((paceMin - minutes) * 60).round();
              pace = '$minutes:${seconds.toString().padLeft(2, '0')}/mi';
              sportLabel = 'RUN';
              break;
            default:
              pace = '--';
              sportLabel = sport.toUpperCase();
          }

          // Calculate segment duration for display
          final duration = input.effectiveDurationMinutes;

          return Expanded(
            child: _BrickSegmentPaceCard(
              sportLabel: sportLabel,
              pace: pace,
              duration: '$duration min',
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMacroTargetsSection(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
    domain.MacroTargets macros,
  ) {
    // Check if this is a brick activity
    final isBrick = macros.activityType == ActivityType.brick;

    if (isBrick) {
      // Render brick-specific UI with combined totals and phase breakdown
      return _buildBrickMacroSection(context, ref, state, macros);
    }

    // Default single-sport UI
    final useMetric = state.unitSystem == UnitSystem.metric;

    // Calculate fluid values based on unit preference
    final preFluids = useMetric
        ? macros.preRun.fluidsMl.round()
        : (macros.preRun.fluidsMl * UnitFormatter.kFlOzPerMl).round();

    final duringFluids = useMetric
        ? macros.duringRun.fluidTotalMl.round()
        : (macros.duringRun.fluidTotalMl * UnitFormatter.kFlOzPerMl).round();

    final postFluids = useMetric
        ? macros.postRun.fluidsMl.round()
        : (macros.postRun.fluidsMl * UnitFormatter.kFlOzPerMl).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: MacroTargetsTable(
        title: 'Your Nutritional Targets',
        useMetric: useMetric,
        macroData: MacroTableData(
          preCarbs: macros.preRun.carbsG.round(),
          duringCarbs: macros.duringRun.carbTotalG.round(),
          postCarbs: macros.postRun.carbsG.round(),
          preProtein: macros.preRun.proteinG.round(),
          duringProtein: 0,
          postProtein: macros.postRun.proteinG.round(),
          preFluids: preFluids,
          duringFluids: duringFluids,
          postFluids: postFluids,
          preSodium: macros.preRun.sodiumMg.round(),
          duringSodium: macros.duringRun.sodiumTotalMg.round(),
          postSodium: macros.postRun.sodiumMg.round(),
        ),
        onInfoPressed: () => _showHelpBottomSheet(context, ref, state),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildBrickMacroSection(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
    domain.MacroTargets macros,
  ) {
    // Use the standard MacroTargetsTable for brick workouts
    // Shows same layout as running/cycling/swimming tabs
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: MacroTargetsTable(
        title: 'Your Nutritional Targets',
        macroData: MacroTableData(
          preCarbs: macros.preRun.carbsG.round(),
          duringCarbs: macros.duringRun.carbTotalG.round(),
          postCarbs: macros.postRun.carbsG.round(),
          preProtein: macros.preRun.proteinG.round(),
          duringProtein: 0,
          postProtein: macros.postRun.proteinG.round(),
          preFluids: macros.preRun.fluidsMl.round(),
          duringFluids: macros.duringRun.fluidTotalMl.round(),
          postFluids: macros.postRun.fluidsMl.round(),
          preSodium: macros.preRun.sodiumMg.round(),
          duringSodium: macros.duringRun.sodiumTotalMg.round(),
          postSodium: macros.postRun.sodiumMg.round(),
        ),
        onInfoPressed: () => _showHelpBottomSheet(context, ref, state),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
    domain.MacroTargets macros,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Row(
        children: [
          Expanded(
            child: KyleSecondaryButton(
              key: const ValueKey('adjust_macros.edit_macros_button'),
              text: 'Edit Macros',
              onPressed: () =>
                  _showEditMacrosDialog(context, ref, state, macros),
              isFullWidth: true,
              variant: SecondaryButtonVariant.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: KyleSecondaryButton(
              key: const ValueKey('adjust_macros.reset_all_button'),
              text: state.resetAllButton,
              onPressed: () => _handleResetAll(context, ref),
              isFullWidth: true,
              variant: SecondaryButtonVariant.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePlanButton(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: KylePrimaryButton(
        key: const ValueKey('adjust_macros.create_plan_button'),
        text: state.createPlanButton,
        onPressed: () => _handleCreatePlan(context, ref),
        isFullWidth: true,
        isLoading: state.isCreatingPlan,
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.orange),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loading macros...',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.triangleExclamation,
            size: 48,
            color: AppColors.dragonfruit,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Error loading macros',
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.dragonfruit,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.toString(),
            style: AppTextStyles.bodyLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
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
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.circleInfo,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No macro data available',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Please go back and generate macros first.',
              style: AppTextStyles.bodyLarge.copyWith(
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

  // Action handlers
  Future<void> _handleResetAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset to Recommended', style: AppTextStyles.sectionTitle),
        content: Text(
          'This will reset all macro values to the recommended amounts. Continue?',
          style: AppTextStyles.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.dragonfruit,
              ),
            ),
          ),
          KylePrimaryButton(
            text: 'Reset',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'reset_all_macros_tapped',
            properties: {'screen': 'adjust_macros'},
          );

      await ref
          .read(macroTargetsControllerProvider.notifier)
          .resetToRecommended();
    }
  }

  Future<void> _handleCreatePlan(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(appExternalDepsProvider).logger;
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'create_plan_button_tapped',
          properties: {'screen': 'adjust_macros'},
        );

    final macroStateBefore = ref.read(macroTargetsControllerProvider).value;
    logger.warning(
      'Coach create-plan tapped',
      context: 'ADJUST_MACROS_SCREEN',
      data: {
        'activityId': macroStateBefore?.activityId,
        'eventId': macroStateBefore?.eventId,
        'forUserId': macroStateBefore?.forUserId,
      },
    );

    // CRITICAL FIX: Get activityId directly from return value instead of state
    // This prevents race conditions where state hasn't propagated yet
    String? activityId;
    try {
      activityId = await ref
          .read(macroTargetsControllerProvider.notifier)
          .createNutritionPlan();
    } catch (e) {
      if (!context.mounted) return;
      MealvanaSnackbar.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }

    if (context.mounted && activityId != null) {
      final macroState = ref.read(macroTargetsControllerProvider).value;
      final isCoachView = macroState?.forUserId != null;

      if (isCoachView) {
        // Force a fresh route load so we don't surface stale pre-generation state.
        logger.warning(
          'Coach create-plan navigating to fresh activity detail route',
          context: 'ADJUST_MACROS_SCREEN',
          data: {'activityId': activityId, 'isCoachView': true},
        );
        context.go(
          '/plan',
          extra: {'activityId': activityId, 'isCoachView': true},
        );
      } else {
        context.push(
          '/current-plan',
          extra: {'activityId': activityId, 'isNewActivity': true},
        );
      }
    } else if (activityId == null) {
      DebugLogger.error(
        '🚫 ADJUST_MACROS: Cannot navigate - activityId is null!',
      );
      if (context.mounted) {
        final asyncState = ref.read(macroTargetsControllerProvider);
        final message =
            asyncState.error?.toString().replaceFirst('Exception: ', '') ??
            'Could not save nutrition plan. Please try again.';
        logger.error(
          'Create-plan returned null activityId',
          context: 'ADJUST_MACROS_SCREEN',
          data: {
            'activityId': macroStateBefore?.activityId,
            'eventId': macroStateBefore?.eventId,
            'forUserId': macroStateBefore?.forUserId,
            'providerError': asyncState.error?.toString(),
          },
          error: asyncState.error,
          stackTrace: asyncState.stackTrace,
        );
        MealvanaSnackbar.showError(context, message);
      }
    }
  }

  void _showEditMacrosDialog(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
    domain.MacroTargets macros,
  ) {
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'edit_macros_button_tapped',
          properties: {'screen': 'adjust_macros'},
        );

    showDialog(
      context: context,
      builder: (context) => EditMacrosDialogWidget(
        macros: macros,
        activityId: state.activityId,
        useMetric: state.unitSystem == UnitSystem.metric,
      ),
    );
  }

  void _showHelpBottomSheet(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
  ) {
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track('help_icon_tapped', properties: {'screen': 'adjust_macros'});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => HelpBottomSheetWidget(state: state),
    );
  }
}

/// Compact card showing pace info for a single brick segment
class _BrickSegmentPaceCard extends StatelessWidget {
  const _BrickSegmentPaceCard({
    required this.sportLabel,
    required this.pace,
    required this.duration,
  });

  final String sportLabel;
  final String pace;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.blackberry : AppColors.cream).withValues(
          alpha: 0.3,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sportLabel,
            style: AppTextStyles.descriptor.copyWith(
              color: AppColors.orange,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pace,
            style: AppTextStyles.dataNumber.copyWith(
              color: isDark ? AppColors.cream : AppColors.blackberry,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            duration,
            style: AppTextStyles.descriptor.copyWith(
              color: (isDark ? AppColors.cream : AppColors.blackberry)
                  .withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
