import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/generating_plan_overlay.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/distance_page_gut_entry_controller.dart';
import '../../domain/macro_targets.dart';

/// Modern Adjust Macros Screen with beautiful design
/// Inspired by eat_my_ride screen with colorful icons and gradients
class AdjustMacrosScreen extends ConsumerWidget {
  const AdjustMacrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(distancePageGutEntryControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: _buildAppBar(context, ref),
      body: Stack(
        children: [
          asyncState.when(
            data: (state) => _buildContent(context, ref, state),
            loading: () => _buildLoadingState(context),
            error: (error, stackTrace) => _buildErrorState(context, ref, error),
          ),
          // Show loading overlay when creating plan
          if (asyncState.value?.isCreatingPlan == true)
            const GeneratingPlanOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppTheme.baseCream,
      elevation: 0,
      centerTitle: false,
      leading: CustomAppBarBackButton(
        onPressed: () => context.pop(),
      ),
      title: Consumer(
        builder: (context, ref, _) {
          final asyncState = ref.watch(distancePageGutEntryControllerProvider);
          return asyncState.when(
            data: (state) => Text(
              state.adjustMacrosTitle,
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.baseBlack,
                fontSize: 18.sp,
              ),
            ),
            loading: () => Text(
              'Adjust Your Macros',
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.baseBlack,
                fontSize: 18.sp,
              ),
            ),
            error: (_, __) => Text(
              'Adjust Your Macros',
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.baseBlack,
                fontSize: 18.sp,
              ),
            ),
          );
        },
      ),
      actions: [
        SizedBox(width: 16.w),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, DistancePageGutEntryState state) {
    if (state.macroTargets == null) {
      return _buildNoDataState(context);
    }

    final macros = state.macroTargets!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section with Run Summary
          _buildHeaderSection(macros),
          
          SizedBox(height: 32.h),
          
          // Main macro display with open layout
          _buildOpenMacroLayout(context, ref, macros, state),
          
          SizedBox(height: 40.h),
          
          // Action Buttons
          _buildActionButtons(context, ref, state),
          
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(MacroTargets macros) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary50.withValues(alpha: 0.8),
            AppTheme.highlight50.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary600.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Activity Summary
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.directions_run,
                  color: AppTheme.primary600,
                  size: 24.w,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'During this activity',
                      style: AppTheme.subtitleStyle.copyWith(
                        fontSize: 16.sp,
                        color: AppTheme.baseBlack,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${macros.metrics.durationH.toStringAsFixed(1)}h - ${macros.metrics.distanceMi.toStringAsFixed(1)}mi',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.baseGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20.h),
          
          // Key Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.speed,
                  iconColor: Colors.green,
                  label: 'Pace',
                  value: '${macros.metrics.formattedPace} min/mile',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  label: 'Total burn',
                  value: '${macros.metrics.caloriesNetKcal.round()} cal',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20.w,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.baseGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenMacroLayout(BuildContext context, WidgetRef ref, MacroTargets macros, DistancePageGutEntryState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title with Edit Button
        Row(
          children: [
            Expanded(
              child: Text(
                'Your nutrition targets',
                style: AppTheme.subtitleStyle.copyWith(
                  color: AppTheme.primary900,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primary600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: IconButton(
                onPressed: () => _showEditAllMacrosDialog(context, ref, macros),
                icon: Icon(
                  Icons.edit,
                  color: AppTheme.primary600,
                  size: 20.w,
                ),
                padding: EdgeInsets.all(8.w),
                constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 24.h),
        
        // Unified Macro Display - Table Layout
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppTheme.baseWhite,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary600.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: AppTheme.primary600.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header row
              _buildHeaderRow(context, ref),
              SizedBox(height: 16.h),
              // Carbs row
              _buildMacroTableRow(
                icon: Icons.grain,
                iconColor: Colors.orange,
                label: 'Carbs',
                preValue: macros.preRun.carbsG,
                duringValue: macros.duringRun.carbTotalG,
                postValue: macros.postRun.carbsG,
                unit: 'g',
              ),
              SizedBox(height: 12.h),
              // Protein row
              _buildMacroTableRow(
                icon: Icons.fitness_center,
                iconColor: Colors.pink,
                label: 'Protein',
                preValue: macros.preRun.proteinG,
                duringValue: 0, // No protein during run
                postValue: macros.postRun.proteinG,
                unit: 'g',
              ),
              SizedBox(height: 12.h),
              // Fluids row
              _buildMacroTableRow(
                icon: Icons.water_drop,
                iconColor: Colors.blue,
                label: 'Fluids',
                preValue: macros.preRun.fluidsMl,
                duringValue: macros.duringRun.fluidTotalMl,
                postValue: macros.postRun.fluidsMl,
                unit: 'ml',
              ),
              SizedBox(height: 12.h),
              // Sodium row
              _buildMacroTableRow(
                icon: Icons.scatter_plot,
                iconColor: Colors.purple,
                label: 'Sodium',
                preValue: macros.preRun.sodiumMg,
                duringValue: macros.duringRun.sodiumTotalMg,
                postValue: macros.postRun.sodiumMg,
                unit: 'mg',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Help icon positioned at the left, above the Carbs icon
        GestureDetector(
          onTap: () {
            ref.read(appExternalDepsProvider).analytics.track('help_button_tapped', properties: {
              'screen': 'adjust_macros',
            });
            _showHelpBottomSheet(context, ref);
          },
          child: Container(
            padding: EdgeInsets.all(4.w),
            child: Icon(
              Icons.help_outline,
              color: AppTheme.primary900,
              size: 20.sp,
            ),
          ),
        ),
        // Space for the rest of the icon + label column
        SizedBox(width: 56.w),
        // Column headers
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Text(
                    'Pre',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.baseGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    'During',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.baseGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 4.w),
                  child: Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.baseGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroTableRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double preValue,
    required double duringValue,
    required double postValue,
    required String unit,
  }) {
    return Row(
      children: [
        // Icon and label
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 16.w,
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 52.w,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.baseBlack,
                ),
              ),
            ),
          ],
        ),
        // Values aligned in columns
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: _buildTableValue(preValue, unit),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: _buildTableValue(duringValue, unit),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 4.w),
                  child: _buildTableValue(postValue, unit),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableValue(double value, String unit) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppTheme.primary50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppTheme.primary600.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        '${value.toStringAsFixed(value < 10 && value != 0 ? 1 : 0)}$unit',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary900,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, DistancePageGutEntryState state) {
    return Column(
      children: [
        // Reset All Button
        TextButton.icon(
          onPressed: state.isCreatingPlan ? null : () {
            ref.read(distancePageGutEntryControllerProvider.notifier)
                .resetToRecommended();
          },
          icon: Icon(
            Icons.refresh,
            color: AppTheme.baseGrey,
            size: 18.w,
          ),
          label: Text(
            state.resetAllButton,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.baseGrey,
            ),
          ),
        ),
        
        SizedBox(height: 16.h),
        
        // Create Plan Button
        PrimaryButton(
          text: state.isCreatingPlan ? 'Creating...' : state.createPlanButton,
          isLoading: state.isCreatingPlan,
          onPressed: state.isCreatingPlan ? null : () async {
            await ref.read(distancePageGutEntryControllerProvider.notifier)
                .createNutritionPlan();

            if (context.mounted) {
              // Navigate to activity detail screen in create mode
              context.push('/current-plan', extra: {
                'mode': 'create',
                'pendingActivityData': state.pendingActivityData,
                'macroTargets': state.macroTargets,
              });
            }
          },
          width: double.infinity,
          height: 56.h,
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: AppTheme.highlight600,
          ),
          SizedBox(height: 16.h),
          Text(
            'Error loading content',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.baseBlack,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error.toString(),
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.baseGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_food,
            size: 64.w,
            color: AppTheme.baseGrey,
          ),
          SizedBox(height: 16.h),
          Text(
            'No macro targets available',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.baseBlack,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Generate a nutrition plan first',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.baseGrey,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAllMacrosDialog(BuildContext context, WidgetRef ref, MacroTargets macros) {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    analytics.track('edit_all_macros_opened', properties: {
      'plan_id': 'pre_generation',
      'screen': 'adjust_macros_screen',
      'experiment_variant': 'auto_items_v1',
    });

    showDialog(
      context: context,
      builder: (context) => _EditAllMacrosDialog(
        macros: macros,
      ),
    );
  }

  void _showHelpBottomSheet(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    analytics.track('guidelines_opened', properties: {
      'plan_id': 'pre_generation',
      'screen': 'adjust_macros_screen',
      'experiment_variant': 'auto_items_v1',
      'topic': 'macro_calculation',
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HelpBottomSheet(),
    );
  }
}

class _EditAllMacrosDialog extends ConsumerStatefulWidget {
  final MacroTargets macros;

  const _EditAllMacrosDialog({
    required this.macros,
  });

  @override
  ConsumerState<_EditAllMacrosDialog> createState() => _EditAllMacrosDialogState();
}

class _EditAllMacrosDialogState extends ConsumerState<_EditAllMacrosDialog> {
  late Map<String, TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers for all 12 values
    controllers = {
      'preCarbs': TextEditingController(text: widget.macros.preRun.carbsG.toStringAsFixed(1)),
      'preFluids': TextEditingController(text: widget.macros.preRun.fluidsMl.toStringAsFixed(0)),
      'preProtein': TextEditingController(text: widget.macros.preRun.proteinG.toStringAsFixed(1)),
      'preSodium': TextEditingController(text: widget.macros.preRun.sodiumMg.toStringAsFixed(0)),
      
      'duringCarbs': TextEditingController(text: widget.macros.duringRun.carbTotalG.toStringAsFixed(1)),
      'duringFluids': TextEditingController(text: widget.macros.duringRun.fluidTotalMl.toStringAsFixed(0)),
      'duringProtein': TextEditingController(text: '0.0'), // No protein during run
      'duringSodium': TextEditingController(text: widget.macros.duringRun.sodiumTotalMg.toStringAsFixed(0)),
      
      'postCarbs': TextEditingController(text: widget.macros.postRun.carbsG.toStringAsFixed(1)),
      'postFluids': TextEditingController(text: widget.macros.postRun.fluidsMl.toStringAsFixed(0)),
      'postProtein': TextEditingController(text: widget.macros.postRun.proteinG.toStringAsFixed(1)),
      'postSodium': TextEditingController(text: widget.macros.postRun.sodiumMg.toStringAsFixed(0)),
    };
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400.w,
        ),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppTheme.primary600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: AppTheme.primary600,
                    size: 24.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Edit All Macro Values',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: AppTheme.baseGrey,
                      size: 20.w,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    _buildMacroEditSection('Carbohydrates', 'g', 'Carbs', Colors.orange),
                    SizedBox(height: 20.h),
                    _buildMacroEditSection('Protein', 'g', 'Protein', Colors.pink),
                    SizedBox(height: 20.h),
                    _buildMacroEditSection('Fluids', 'ml', 'Fluids', Colors.blue),
                    SizedBox(height: 20.h),
                    _buildMacroEditSection('Sodium', 'mg', 'Sodium', Colors.purple),
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppTheme.baseGrey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.baseGrey,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: PrimaryButton(
                      text: 'Save',
                      onPressed: _saveChanges,
                      height: 44.h,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroEditSection(String label, String unit, String key, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Container(
                width: 4.w,
                height: 4.w,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.baseBlack,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                label: 'Pre',
                controller: controllers['pre$key']!,
                unit: unit,
                color: AppTheme.highlight600Alt,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildInputField(
                label: 'During',
                controller: controllers['during$key']!,
                unit: unit,
                color: AppTheme.primary600,
                enabled: key != 'Protein', // Disable protein during run
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildInputField(
                label: 'Post',
                controller: controllers['post$key']!,
                unit: unit,
                color: AppTheme.highlight600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String unit,
    required Color color,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.baseGrey,
          ),
        ),
        SizedBox(height: 4.h),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.baseGrey,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: color, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.baseGrey.withValues(alpha: 0.2)),
            ),
          ),
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.baseBlack : AppTheme.baseGrey,
          ),
        ),
      ],
    );
  }

  void _saveChanges() async {
    if (!mounted) return;
    
    // All business logic moved to controller
    try {
      final controller = ref.read(distancePageGutEntryControllerProvider.notifier);
      
      // Parse all values and save via controller
      await controller.saveAllMacroChanges(
        // Pre-run values
        preRunCarbs: double.parse(controllers['preCarbs']!.text),
        preRunProtein: double.parse(controllers['preProtein']!.text),
        preRunFluids: double.parse(controllers['preFluids']!.text),
        preRunSodium: double.parse(controllers['preSodium']!.text),
        // During-run values
        duringRunCarbs: double.parse(controllers['duringCarbs']!.text),
        duringRunFluids: double.parse(controllers['duringFluids']!.text),
        duringRunSodium: double.parse(controllers['duringSodium']!.text),
        // Post-run values
        postRunCarbs: double.parse(controllers['postCarbs']!.text),
        postRunProtein: double.parse(controllers['postProtein']!.text),
        postRunFluids: double.parse(controllers['postFluids']!.text),
        postRunSodium: double.parse(controllers['postSodium']!.text),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Error handling - silently fail for now
      // TODO: Show user-friendly error message
    }
  }
}

class _HelpBottomSheet extends StatefulWidget {
  const _HelpBottomSheet();

  @override
  State<_HelpBottomSheet> createState() => _HelpBottomSheetState();
}

class _HelpBottomSheetState extends State<_HelpBottomSheet> {
  // Track which sections are expanded
  String? expandedSection = 'Carbohydrates'; // Default expanded section

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 20.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
        ),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.baseGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Nutrition Guidelines',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary900,
              ),
            ),
            SizedBox(height: 20.h),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Accordion sections
                    _buildAccordionSection(
                      title: 'Carbohydrates',
                      content: '''**How we calculate it:** Duration establishes a safe **absorption band**. We adjust for **intensity (MET)**, **gut training**, **body size**, and fuel mix—then **cap** based on what your gut can process.

Replenish with high-quality carbs immediately after exercise to jumpstart recovery and restore glycogen.''',
                      isExpanded: expandedSection == 'Carbohydrates',
                      onTap: () {
                        setState(() {
                          expandedSection = expandedSection == 'Carbohydrates' ? null : 'Carbohydrates';
                        });
                      },
                    ),
                    
                    _buildAccordionSection(
                      title: 'Sodium',
                      content: '''**How we calculate it:** If you know your **sweat rate**, we estimate hourly sodium loss (**sweat sodium × sweat rate**) and target **~50–70%** of that (clamped at **300–1200 mg/h**). If not, we determine needs based on your **sweater type** (low/medium/high) and adjust for **heat/humidity**.

Include sodium in your **pre-run** and **post-run** drinks to enhance fluid retention and improve rehydration.''',
                      isExpanded: expandedSection == 'Sodium',
                      onTap: () {
                        setState(() {
                          expandedSection = expandedSection == 'Sodium' ? null : 'Sodium';
                        });
                      },
                    ),
                    
                    _buildAccordionSection(
                      title: 'Fluids',
                      content: '''**How we calculate it:** We begin with a running-friendly range (**~0.4–0.8 L/h**), adjust for **body size** and **intensity (MET)**, then modify based on **weather** (less in cool conditions, more in hot/humid). For those with a **measured sweat rate**, we target **~70–80%** of that rate, staying within the safe range to prevent overhydration.

Post-run, replenish approximately **125%** of your **estimated fluid deficit** using a drink containing **~500–700 mg/L sodium**.''',
                      isExpanded: expandedSection == 'Fluids',
                      onTap: () {
                        setState(() {
                          expandedSection = expandedSection == 'Fluids' ? null : 'Fluids';
                        });
                      },
                    ),
                    
                    _buildAccordionSection(
                      title: 'Protein',
                      content: '''**How we calculate it:**

- **Pre-run:** small amount, **~0.15–0.25 g/kg** (varies with timing) for satiety without digestive discomfort.
- **During:** **0 g/h** for runs ≤3.5 h (minimal amounts only for ultramarathons).
- **After:** **~0.3 g/kg** within the first hour; 20–40 g high-quality protein containing **~2–3 g leucine**.

Remember: "carbs first, protein **right after**" for optimal recovery.''',
                      isExpanded: expandedSection == 'Protein',
                      onTap: () {
                        setState(() {
                          expandedSection = expandedSection == 'Protein' ? null : 'Protein';
                        });
                      },
                    ),
                    
                    _buildAccordionSection(
                      title: 'Fats',
                      content: '''**How we calculate it:**

- **Pre-run:** modest intake, **~0.1–0.2 g/kg** (reduce fiber/fat closer to start time).
- **During:** **0–2 g/h** maximum (minimized to protect gut function).
- **After:** approximately **~0.2 g/kg** as part of your recovery meal—supports satiety and overall energy intake.

Prioritize **unsaturated fats** (e.g., olive oil, nuts) in your recovery meals.''',
                      isExpanded: expandedSection == 'Fats',
                      onTap: () {
                        setState(() {
                          expandedSection = expandedSection == 'Fats' ? null : 'Fats';
                        });
                      },
                    ),
                    
                    SizedBox(height: 24.h),
                    
                    // Key References section (always visible)
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppTheme.primary50.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppTheme.primary600.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Key References',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary900,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            '• ACSM Metabolic Calculations Handbook; ACSM Guidelines 10e\n'
                            '• Jeukendrup AE (2004, 2011)\n'
                            '• ACSM/AND/DC 2016; NATA & ACSM hydration position stands\n'
                            '• Thomas et al., JAND 2016\n'
                            '• IOC/consensus updates on recovery protein\n'
                            '• Burke et al., IOC consensus on athlete nutrition',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppTheme.baseGrey,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20.h),
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
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isExpanded 
              ? AppTheme.primary600.withValues(alpha: 0.3)
              : AppTheme.baseGrey.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: isExpanded 
            ? [
                BoxShadow(
                  color: AppTheme.primary600.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(12.r),
              bottom: Radius.circular(isExpanded ? 0 : 12.r),
            ),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isExpanded 
                    ? AppTheme.primary50.withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12.r),
                  bottom: Radius.circular(isExpanded ? 0 : 12.r),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isExpanded 
                            ? AppTheme.primary900
                            : AppTheme.baseBlack,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded 
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isExpanded 
                        ? AppTheme.primary600
                        : AppTheme.baseGrey,
                    size: 24.w,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              padding: EdgeInsets.all(16.w),
              child: Text(
                _formatMarkdownText(content),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.baseGrey,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMarkdownText(String text) {
    // Simple markdown processing - remove markdown formatting for display
    return text
        .replaceAll('**', '') // Remove bold markdown
        .replaceAll('*', '') // Remove italic markdown
        .replaceAll('~', '') // Remove strikethrough
        .trim();
  }
}
