import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/generating_plan_overlay.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/domain/activity_type.dart';
import '../providers/macro_targets_controller.dart';
import '../../domain/macro_targets.dart' as domain;
import '../../../../core/utils/debug_logger.dart';

/// Adjust Macros Screen - Simplified Kyle's Design
/// Refactored from 1,151 lines to match Figma design exactly
class AdjustMacrosScreen extends ConsumerStatefulWidget {
  const AdjustMacrosScreen({super.key});

  @override
  ConsumerState<AdjustMacrosScreen> createState() => _AdjustMacrosScreenState();
}

class _AdjustMacrosScreenState extends ConsumerState<AdjustMacrosScreen> {
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final asyncState = ref.watch(macroTargetsControllerProvider);

    DebugLogger.info('🎬 ADJUST MACROS: Screen building (build #$_buildCount), asyncState type: ${asyncState.runtimeType}');
    asyncState.when(
      data: (state) {
        DebugLogger.info('📊 ADJUST MACROS: Has data - macroTargets null? ${state.macroTargets == null}');
        if (state.macroTargets != null) {
          DebugLogger.info('✅ ADJUST MACROS: MacroTargets present - preRun carbs: ${state.macroTargets!.preRun.carbsG}g');
        }
      },
      loading: () => DebugLogger.info('⏳ ADJUST MACROS: State is loading...'),
      error: (e, st) => DebugLogger.error('❌ ADJUST MACROS: State has error: $e'),
    );

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
          // Circular back button
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
          // Title from ContentService
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
    DebugLogger.info('📝 ADJUST MACROS: _buildContent called - macroTargets null? ${state.macroTargets == null}');

    if (state.macroTargets == null) {
      DebugLogger.error('❌ ADJUST MACROS: Showing NO DATA state - this should not happen!');
      return _buildNoDataState(context);
    }

    DebugLogger.info('✅ ADJUST MACROS: Rendering content with macros - preRun carbs: ${state.macroTargets!.preRun.carbsG}g');
    final macros = state.macroTargets!;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12), // Top padding

          // "During this Run" dynamic header
          _buildActivityHeader(context, state),

          // const SizedBox(height: 12),

          // PACE and TOTAL BURN stats
          _buildPaceBurnStats(context, state, macros),

          // const SizedBox(height: 12),

          // "Your Nutritional Targets" with table
          _buildMacroTargetsSection(context, ref, state, macros),

          const SizedBox(height: 12),

          // Edit Macros + Reset All buttons
          _buildActionButtons(context, ref, state, macros),

          const SizedBox(height: 16),

          // Create Plan button
          _buildCreatePlanButton(context, ref, state),

          const SizedBox(height: 40), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildActivityHeader(
    BuildContext context,
    MacroTargetsState state,
  ) {
    // Get dynamic activity type text
    final activityTypeText = _getActivityTypeText(state.pendingActivityData?.activityType);

    // Format activity info (duration • distance)
    final activityInfo = _formatActivityInfo(state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        children: [
          // "During this Run" (dynamic based on activity type)
          Text(
            activityTypeText,
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          // "1.8 h • 12MI"
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

  String _getActivityTypeText(ActivityType? type) {
    switch (type) {
      case ActivityType.running:
        return 'During this Run';
      case ActivityType.cycling:
        return 'During this Ride';
      case ActivityType.swimming:
        return 'During this Swim';
      default:
        return 'During this Activity';
    }
  }

  String _formatActivityInfo(MacroTargetsState state) {
    final pendingData = state.pendingActivityData;
    if (pendingData == null) return '';

    // Calculate duration from distance and pace
    final distance = pendingData.distanceMiles;
    final pace = pendingData.paceMinutesPerMile;
    final duration = (distance * pace) / 60.0; // Convert to hours

    // Format duration (hours with 1 decimal)
    final durationStr = '${duration.toStringAsFixed(1)} h';

    // Format distance based on activity type
    String distanceStr;
    if (pendingData.activityType == ActivityType.swimming) {
      // Convert miles to meters for swimming
      final meters = (distance * 1609.34).round();
      distanceStr = '${meters}m';
    } else {
      distanceStr = '${distance.toStringAsFixed(0)}MI';
    }

    return '$durationStr  •  $distanceStr';
  }

  Widget _buildPaceBurnStats(
    BuildContext context,
    MacroTargetsState state,
    domain.MacroTargets macros,
  ) {
    // Format pace value based on activity type
    final pace = _formatPaceValue(state);

    // Format total burn (calories)
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

  String _formatPaceValue(MacroTargetsState state) {
    final pendingData = state.pendingActivityData;
    if (pendingData == null) return '--';

    switch (pendingData.activityType) {
      case ActivityType.running:
        final pace = pendingData.paceMinutesPerMile;
        final minutes = pace.floor();
        final seconds = ((pace - minutes) * 60).round();
        return '$minutes:${seconds.toString().padLeft(2, '0')}/mi';

      case ActivityType.cycling:
        final speed = pendingData.cyclingSpeedMph ?? 0;
        return '${speed.toStringAsFixed(1)} mph';

      case ActivityType.swimming:
        final paceSeconds = pendingData.swimmingPacePer100mSeconds ?? 0;
        final minutes = paceSeconds ~/ 60;
        final seconds = paceSeconds % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}/100m';

      default:
        return '--';
    }
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
          duringProtein: 0, // No protein during activity
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
          // Edit Macros button (left)
          Expanded(
            child: KyleSecondaryButton(
              text: 'Edit Macros',
              onPressed: () => _showEditMacrosDialog(context, ref, state, macros),
              isFullWidth: true,
              variant: SecondaryButtonVariant.orange,
            ),
          ),

          const SizedBox(width: 16), // Gap between buttons

          // Reset All button (right)
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
    DebugLogger.error('🚨 ADJUST MACROS: _buildNoDataState being rendered - USER SEES "No macro data available"');
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
    // Show confirmation dialog
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

    await ref
        .read(macroTargetsControllerProvider.notifier)
        .createNutritionPlan();

    // Wait a brief moment for state updates to propagate through Riverpod
    await Future.delayed(const Duration(milliseconds: 100));

    // Navigate to activity detail screen after plan creation
    // SIMPLIFIED: Only activityId is needed - isNewActivity=true shows "Save Workout" button
    if (context.mounted) {
      final state = ref.read(macroTargetsControllerProvider).value;
      if (state != null && state.activityId != null) {
        context.push('/current-plan', extra: {
          'activityId': state.activityId,
          'isNewActivity': true, // Shows "Save Workout" button for first-time viewing
        });
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
        .track('edit_macros_button_tapped', properties: {
      'screen': 'adjust_macros',
    });

    showDialog(
      context: context,
      builder: (context) => _EditMacrosDialog(
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
      builder: (context) => _HelpBottomSheet(state: state),
    );
  }
}

/// Edit Macros Dialog
class _EditMacrosDialog extends ConsumerStatefulWidget {
  const _EditMacrosDialog({
    required this.macros,
    this.activityId,
  });

  final domain.MacroTargets macros;
  final int? activityId;

  @override
  ConsumerState<_EditMacrosDialog> createState() => _EditMacrosDialogState();
}

class _EditMacrosDialogState extends ConsumerState<_EditMacrosDialog> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'preCarbs': TextEditingController(text: widget.macros.preRun.carbsG.round().toString()),
      'duringCarbs': TextEditingController(text: widget.macros.duringRun.carbTotalG.round().toString()),
      'postCarbs': TextEditingController(text: widget.macros.postRun.carbsG.round().toString()),
      'preProtein': TextEditingController(text: widget.macros.preRun.proteinG.round().toString()),
      'duringProtein': TextEditingController(text: '0'),
      'postProtein': TextEditingController(text: widget.macros.postRun.proteinG.round().toString()),
      'preFluids': TextEditingController(text: widget.macros.preRun.fluidsMl.round().toString()),
      'duringFluids': TextEditingController(text: widget.macros.duringRun.fluidTotalMl.round().toString()),
      'postFluids': TextEditingController(text: widget.macros.postRun.fluidsMl.round().toString()),
      'preSodium': TextEditingController(text: widget.macros.preRun.sodiumMg.round().toString()),
      'duringSodium': TextEditingController(text: widget.macros.duringRun.sodiumTotalMg.round().toString()),
      'postSodium': TextEditingController(text: widget.macros.postRun.sodiumMg.round().toString()),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Macro Targets',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMacroSection('CARBS (g)', 'preCarbs', 'duringCarbs', 'postCarbs'),
            const SizedBox(height: AppSpacing.md),
            _buildMacroSection('PROTEIN (g)', 'preProtein', 'duringProtein', 'postProtein'),
            const SizedBox(height: AppSpacing.md),
            _buildMacroSection('FLUIDS (mL)', 'preFluids', 'duringFluids', 'postFluids'),
            const SizedBox(height: AppSpacing.md),
            _buildMacroSection('SODIUM (mg)', 'preSodium', 'duringSodium', 'postSodium'),
          ],
        ),
      ),
      actions: [
        KyleSecondaryButton(
          text: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          // variant: SecondaryButtonVariant.blackberry,
        ),
            const SizedBox(height: AppSpacing.lg),
        KylePrimaryButton(
          text: 'Save Changes',
          onPressed: _saveChanges,
        ),
      ],
    );
  }

  Widget _buildMacroSection(String label, String preKey, String duringKey, String postKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _buildTextField('PRE', preKey)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildTextField('DURING', duringKey)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildTextField('POST', postKey)),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controllers[key],
          keyboardType: TextInputType.number,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    try {
      // Parse values
      final preCarbs = double.parse(_controllers['preCarbs']!.text);
      final duringCarbs = double.parse(_controllers['duringCarbs']!.text);
      final postCarbs = double.parse(_controllers['postCarbs']!.text);
      final preProtein = double.parse(_controllers['preProtein']!.text);
      // Note: duringProtein is not used as there's no protein during activity
      final postProtein = double.parse(_controllers['postProtein']!.text);
      final preFluids = double.parse(_controllers['preFluids']!.text);
      final duringFluids = double.parse(_controllers['duringFluids']!.text);
      final postFluids = double.parse(_controllers['postFluids']!.text);
      final preSodium = double.parse(_controllers['preSodium']!.text);
      final duringSodium = double.parse(_controllers['duringSodium']!.text);
      final postSodium = double.parse(_controllers['postSodium']!.text);

      // Save to controller
      await ref
          .read(macroTargetsControllerProvider.notifier)
          .saveAllMacroChanges(
            preRunCarbs: preCarbs,
            duringRunCarbs: duringCarbs,
            postRunCarbs: postCarbs,
            preRunProtein: preProtein,
            postRunProtein: postProtein,
            preRunFluids: preFluids,
            duringRunFluids: duringFluids,
            postRunFluids: postFluids,
            preRunSodium: preSodium,
            duringRunSodium: duringSodium,
            postRunSodium: postSodium,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid input: ${e.toString()}'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
    }
  }
}

/// Help Bottom Sheet with detailed nutrition science
class _HelpBottomSheet extends ConsumerStatefulWidget {
  const _HelpBottomSheet({required this.state});

  final MacroTargetsState state;

  @override
  ConsumerState<_HelpBottomSheet> createState() => _HelpBottomSheetState();
}

class _HelpBottomSheetState extends ConsumerState<_HelpBottomSheet> {
  String? _expandedSection = 'Carbohydrates'; // Default expanded

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Nutrition Guidelines',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carbohydrates
                    _buildAccordionSection(
                      title: 'Carbohydrates',
                      content: '**How we calculate it:** Duration establishes a safe **absorption band**. We adjust for **intensity (MET)**, **gut training**, **body size**, and fuel mix—then **cap** based on what your gut can process.\n\nReplenish with high-quality carbs immediately after exercise to jumpstart recovery and restore glycogen.',
                      isExpanded: _expandedSection == 'Carbohydrates',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Carbohydrates' ? null : 'Carbohydrates';
                        });
                      },
                    ),

                    // Sodium
                    _buildAccordionSection(
                      title: 'Sodium',
                      content: '**How we calculate it:** If you know your **sweat rate**, we estimate hourly sodium loss (**sweat sodium × sweat rate**) and target **~50–70%** of that (clamped at **300–1200 mg/h**). If not, we determine needs based on your **sweater type** (low/medium/high) and adjust for **heat/humidity**.\n\nInclude sodium in your **pre-run** and **post-run** drinks to enhance fluid retention and improve rehydration.',
                      isExpanded: _expandedSection == 'Sodium',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Sodium' ? null : 'Sodium';
                        });
                      },
                    ),

                    // Fluids
                    _buildAccordionSection(
                      title: 'Fluids',
                      content: '**How we calculate it:** We begin with a running-friendly range (**~0.4–0.8 L/h**), adjust for **body size** and **intensity (MET)**, then modify based on **weather** (less in cool conditions, more in hot/humid). For those with a **measured sweat rate**, we target **~70–80%** of that rate, staying within the safe range to prevent overhydration.\n\nPost-run, replenish approximately **125%** of your **estimated fluid deficit** using a drink containing **~500–700 mg/L sodium**.',
                      isExpanded: _expandedSection == 'Fluids',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Fluids' ? null : 'Fluids';
                        });
                      },
                    ),

                    // Protein
                    _buildAccordionSection(
                      title: 'Protein',
                      content: '**How we calculate it:**\n\n- **Pre-run:** small amount, **~0.15–0.25 g/kg** (varies with timing) for satiety without digestive discomfort.\n- **During:** **0 g/h** for runs ≤3.5 h (minimal amounts only for ultramarathons).\n- **After:** **~0.3 g/kg** within the first hour; 20–40 g high-quality protein containing **~2–3 g leucine**.\n\nRemember: "carbs first, protein **right after**" for optimal recovery.',
                      isExpanded: _expandedSection == 'Protein',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Protein' ? null : 'Protein';
                        });
                      },
                    ),

                    // Fats
                    _buildAccordionSection(
                      title: 'Fats',
                      content: '**How we calculate it:**\n\n- **Pre-run:** modest intake, **~0.1–0.2 g/kg** (reduce fiber/fat closer to start time).\n- **During:** **0–2 g/h** maximum (minimized to protect gut function).\n- **After:** approximately **~0.2 g/kg** as part of your recovery meal—supports satiety and overall energy intake.\n\nPrioritize **unsaturated fats** (e.g., olive oil, nuts) in your recovery meals.',
                      isExpanded: _expandedSection == 'Fats',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Fats' ? null : 'Fats';
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Key References section
                    BaseCard(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppColors.orange.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Key References',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• ACSM Metabolic Calculations Handbook; ACSM Guidelines 10e\n'
                            '• Jeukendrup AE (2004, 2011)\n'
                            '• ACSM/AND/DC 2016; NATA & ACSM hydration position stands\n'
                            '• Thomas et al., JAND 2016\n'
                            '• IOC/consensus updates on recovery protein\n'
                            '• Burke et al., IOC consensus on athlete nutrition',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionSection({
    required String title,
    required String content,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppColors.orange.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? FontAwesomeIcons.chevronUp
                        : FontAwesomeIcons.chevronDown,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  _formatMarkdownText(content),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper to render simple markdown-like bold text
  String _formatMarkdownText(String text) {
    // Remove markdown ** symbols for now (could add RichText support later)
    return text.replaceAll('**', '');
  }
}
