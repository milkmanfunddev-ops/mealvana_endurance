import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/adjust_macros/edit_macros_dialog_widget.dart';
import '../widgets/adjust_macros/help_bottom_sheet_widget.dart';
import '../utils/macro_helpers.dart';
import '../../../../shared/widgets/generating_plan_overlay.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/macro_targets_controller.dart';
import '../../domain/macro_targets.dart' as domain;
import '../../../../core/utils/debug_logger.dart';

/// Adjust Macros Screen - Refactored with extracted widgets
/// Simplified from 1,005 lines using extracted components
class AdjustMacrosScreen extends ConsumerStatefulWidget {
  const AdjustMacrosScreen({super.key});

  @override
  ConsumerState<AdjustMacrosScreen> createState() => _AdjustMacrosScreenState();
}

class _AdjustMacrosScreenState extends ConsumerState<AdjustMacrosScreen> {
  int _buildCount = 0;

  @override
  void dispose() {
    // ⚠️ IMPORTANT: Cannot use ref.read() in dispose() - violates Riverpod safety
    // Draft cleanup is now handled by MacroTargetsController.ref.onDispose()
    // See: macro_targets_controller.dart for cleanup implementation
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final asyncState = ref.watch(macroTargetsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, ref, asyncState.value),
      body: Stack(
        children: [
          asyncState.when(
            data: (state) => _buildContent(context, ref, state),
            loading: () => _buildLoadingState(context),
            error: (error, stackTrace) => _buildErrorState(context, ref, error),
          ),
          if (asyncState.value?.isCreatingPlan == true)
            const GeneratingPlanOverlay(),
        ],
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.arrowLeft,
                size: AppIconSizes.controlIcon,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => context.pop(),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
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
      DebugLogger.error('❌ ADJUST MACROS: Showing NO DATA state - this should not happen!');
      return _buildNoDataState(context);
    }

    final macros = state.macroTargets!;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildActivityHeader(context, state),
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

  Widget _buildActivityHeader(
    BuildContext context,
    MacroTargetsState state,
  ) {
    final activityTypeText = MacroHelpers.getActivityTypeText(state.macroTargets);
    final activityInfo = MacroHelpers.formatActivityInfo(state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        children: [
          Text(
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
    final totalBurn = '${macros.metrics.caloriesNetKcal.round().toString()} kcal';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: PaceBurnDisplay(
        pace: pace,
        totalBurn: totalBurn,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildMacroTargetsSection(
    BuildContext context,
    WidgetRef ref,
    MacroTargetsState state,
    domain.MacroTargets macros,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
              text: 'Edit Macros',
              onPressed: () => _showEditMacrosDialog(context, ref, state, macros),
              isFullWidth: true,
              variant: SecondaryButtonVariant.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: KyleSecondaryButton(
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
        children: [
          CircularProgressIndicator(
            color: AppColors.orange,
          ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
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
      ),
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
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
        title: Text(
          'Reset to Recommended',
          style: AppTextStyles.sectionTitle,
        ),
        content: Text(
          'This will reset all macro values to the recommended amounts. Continue?',
          style: AppTextStyles.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.dragonfruit),
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
          .track('reset_all_macros_tapped', properties: {
        'screen': 'adjust_macros',
      });

      await ref
          .read(macroTargetsControllerProvider.notifier)
          .resetToRecommended();
    }
  }

  Future<void> _handleCreatePlan(BuildContext context, WidgetRef ref) async {
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track('create_plan_button_tapped', properties: {
      'screen': 'adjust_macros',
    });

    // CRITICAL FIX: Get activityId directly from return value instead of state
    // This prevents race conditions where state hasn't propagated yet
    final activityId = await ref
        .read(macroTargetsControllerProvider.notifier)
        .createNutritionPlan();

    if (context.mounted && activityId != null) {
      context.push('/current-plan', extra: {
        'activityId': activityId,
        'isNewActivity': true,
      });
    } else if (activityId == null) {
      DebugLogger.error('🚫 ADJUST_MACROS: Cannot navigate - activityId is null!');
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
        .track('edit_macros_button_tapped', properties: {
      'screen': 'adjust_macros',
    });

    showDialog(
      context: context,
      builder: (context) => EditMacrosDialogWidget(
        macros: macros,
        activityId: state.activityId,
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
        .track('help_icon_tapped', properties: {
      'screen': 'adjust_macros',
    });

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
