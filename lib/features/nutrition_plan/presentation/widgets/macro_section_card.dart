import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/macro_targets.dart';

/// A collapsible card displaying macro adjustment fields for a specific section
/// (Pre-Run, During-Run, or Post-Run) with editable input fields
class MacroSectionCard extends StatefulWidget {
  const MacroSectionCard({
    super.key,
    required this.title,
    required this.section,
    required this.macroTargets,
    required this.isExpanded,
    required this.onValueChanged,
  });

  final String title;
  final MacroSection section;
  final MacroTargets macroTargets;
  final bool isExpanded;
  final void Function(MacroField field, double newValue) onValueChanged;

  @override
  State<MacroSectionCard> createState() => _MacroSectionCardState();
}

class _MacroSectionCardState extends State<MacroSectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  
  // Track validation messages for each field
  final Map<MacroField, String?> _validationMessages = {};

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          // Header with title and expand/collapse button
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Validation status indicator
                  _buildValidationIndicator(context),
                  SizedBox(width: 8.w),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: _isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: EdgeInsets.all(16.w),
              child: _buildSectionFields(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionFields(BuildContext context) {
    switch (widget.section) {
      case MacroSection.preRun:
        return _buildPreRunFields(context);
      case MacroSection.duringRun:
        return _buildDuringRunFields(context);
      case MacroSection.postRun:
        return _buildPostRunFields(context);
    }
  }

  Widget _buildPreRunFields(BuildContext context) {
    return Column(
      children: [
        _buildMacroField(
          context,
          'Carbs (g)',
          'g',
          widget.macroTargets.preRun.carbsG,
          MacroField.preRunCarbs,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Protein (g)',
          'g',
          widget.macroTargets.preRun.proteinG,
          MacroField.preRunProtein,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Fat Cap (g)',
          'g',
          widget.macroTargets.preRun.fatCapG,
          MacroField.preRunFatCap,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Fluids (fl oz)',
          'fl oz',
          widget.macroTargets.preRun.fluidsFlOz,
          MacroField.preRunFluids,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Sodium (mg)',
          'mg',
          widget.macroTargets.preRun.sodiumMg,
          MacroField.preRunSodium,
        ),
      ],
    );
  }

  Widget _buildDuringRunFields(BuildContext context) {
    return Column(
      children: [
        _buildMacroField(
          context,
          'Carbs Total (g)',
          'g',
          widget.macroTargets.duringRun.carbTotalG,
          MacroField.duringRunCarbTotal,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Fluids Total (fl oz)',
          'fl oz',
          widget.macroTargets.duringRun.fluidTotalFlOz,
          MacroField.duringRunFluidTotal,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Sodium Total (mg)',
          'mg',
          widget.macroTargets.duringRun.sodiumTotalMg,
          MacroField.duringRunSodiumTotal,
        ),
      ],
    );
  }

  Widget _buildPostRunFields(BuildContext context) {
    return Column(
      children: [
        _buildMacroField(
          context,
          'Carbs (g)',
          'g',
          widget.macroTargets.postRun.carbsG,
          MacroField.postRunCarbs,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Protein (g)',
          'g',
          widget.macroTargets.postRun.proteinG,
          MacroField.postRunProtein,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Fluids (fl oz)',
          'fl oz',
          widget.macroTargets.postRun.fluidsFlOz,
          MacroField.postRunFluids,
        ),
        SizedBox(height: 12.h),
        _buildMacroField(
          context,
          'Sodium (mg)',
          'mg',
          widget.macroTargets.postRun.sodiumMg,
          MacroField.postRunSodium,
        ),
      ],
    );
  }

  Widget _buildMacroField(
    BuildContext context,
    String label,
    String unit,
    double value,
    MacroField field,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final controller = TextEditingController(text: value.toStringAsFixed(1));
    
    // Get validation message for this field
    final validationMessage = _getValidationMessage(field, value);
    final hasWarning = validationMessage != null;
    
    // Update validation state
    setState(() {
      _validationMessages[field] = validationMessage;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 1,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                style: textTheme.bodyMedium,
                decoration: InputDecoration(
                  suffix: Text(
                    unit,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasWarning ? colorScheme.error : colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasWarning ? colorScheme.error : colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: hasWarning ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: colorScheme.error),
                  ) : null,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  isDense: true,
                ),
                onChanged: (text) {
                  final newValue = double.tryParse(text);
                  if (newValue != null) {
                    widget.onValueChanged(field, newValue);
                    // Update validation in real-time
                    setState(() {
                      _validationMessages[field] = _getValidationMessage(field, newValue);
                    });
                  }
                },
              ),
            ),
            // Warning icon
            if (hasWarning) ...[
              SizedBox(width: 8.w),
              Icon(
                Icons.warning_outlined,
                size: 18.sp,
                color: colorScheme.error,
              ),
            ],
          ],
        ),
        
        // Validation message
        if (hasWarning) ...[
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14.sp,
                  color: colorScheme.error,
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    validationMessage,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Build validation status indicator for the section header
  Widget _buildValidationIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Count warnings in this section
    final sectionFields = _getSectionFields();
    int warningCount = 0;
    
    for (final field in sectionFields) {
      final value = _getFieldValue(field);
      if (_getValidationMessage(field, value) != null) {
        warningCount++;
      }
    }
    
    if (warningCount == 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_outlined,
            size: 14.sp,
            color: colorScheme.error,
          ),
          SizedBox(width: 4.w),
          Text(
            '$warningCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Get all fields for the current section
  List<MacroField> _getSectionFields() {
    switch (widget.section) {
      case MacroSection.preRun:
        return [
          MacroField.preRunCarbs,
          MacroField.preRunProtein,
          MacroField.preRunFatCap,
          MacroField.preRunFluids,
          MacroField.preRunSodium,
        ];
      case MacroSection.duringRun:
        return [
          MacroField.duringRunCarbTotal,
          MacroField.duringRunFluidTotal,
          MacroField.duringRunSodiumTotal,
        ];
      case MacroSection.postRun:
        return [
          MacroField.postRunCarbs,
          MacroField.postRunProtein,
          MacroField.postRunFluids,
          MacroField.postRunSodium,
        ];
    }
  }

  /// Get current field value from macro targets
  double _getFieldValue(MacroField field) {
    switch (field) {
      // Pre-run fields
      case MacroField.preRunCarbs:
        return widget.macroTargets.preRun.carbsG;
      case MacroField.preRunProtein:
        return widget.macroTargets.preRun.proteinG;
      case MacroField.preRunFatCap:
        return widget.macroTargets.preRun.fatCapG;
      case MacroField.preRunFluids:
        return widget.macroTargets.preRun.fluidsFlOz;
      case MacroField.preRunSodium:
        return widget.macroTargets.preRun.sodiumMg;
      
      // During-run fields
      case MacroField.duringRunCarbTotal:
        return widget.macroTargets.duringRun.carbTotalG;
      case MacroField.duringRunFluidTotal:
        return widget.macroTargets.duringRun.fluidTotalFlOz;
      case MacroField.duringRunSodiumTotal:
        return widget.macroTargets.duringRun.sodiumTotalMg;
      
      // Post-run fields
      case MacroField.postRunCarbs:
        return widget.macroTargets.postRun.carbsG;
      case MacroField.postRunProtein:
        return widget.macroTargets.postRun.proteinG;
      case MacroField.postRunFluids:
        return widget.macroTargets.postRun.fluidsFlOz;
      case MacroField.postRunSodium:
        return widget.macroTargets.postRun.sodiumMg;
      
      // Unused fields for this implementation
      default:
        return 0.0;
    }
  }

  /// Get validation message for a specific macro field
  String? _getValidationMessage(MacroField field, double value) {
    // For validation, we need body weight and duration from the macro targets
    final metrics = widget.macroTargets.metrics;
    final bodyWeightKg = 70.0; // TODO: Get from user profile - using average for now
    final durationH = metrics.durationH;

    // Use validation ranges based on ISSN research
    switch (widget.section) {
      case MacroSection.preRun:
        return _validatePreRunMacro(field, value, bodyWeightKg);
      case MacroSection.duringRun:
        return _validateDuringRunMacro(field, value, bodyWeightKg, durationH);
      case MacroSection.postRun:
        return _validatePostRunMacro(field, value, bodyWeightKg);
    }
  }

  String? _validatePreRunMacro(MacroField field, double value, double bodyWeightKg) {
    switch (field) {
      case MacroField.preRunCarbs:
        if (value < 1.0 * bodyWeightKg) return 'Below recommended range (1-4 g/kg)';
        if (value > 4.0 * bodyWeightKg) return 'Above recommended range (1-4 g/kg)';
        break;
      case MacroField.preRunProtein:
        if (value > 0.25 * bodyWeightKg) return 'Higher than typically needed';
        break;
      case MacroField.preRunFatCap:
        if (value > 0.2 * bodyWeightKg) return 'May slow digestion';
        break;
      case MacroField.preRunFluids:
        // Convert fl oz to ml for validation (1 fl oz = 29.5735 ml)
        final valueML = value * 29.5735;
        if (valueML < 5.0 * bodyWeightKg) return 'May lead to dehydration';
        if (valueML > 7.0 * bodyWeightKg) return 'Risk of overhydration';
        break;
      case MacroField.preRunSodium:
        if (value < 200) return 'May be insufficient';
        if (value > 400) return 'Higher than typically needed';
        break;
      default:
        break;
    }
    return null;
  }

  String? _validateDuringRunMacro(MacroField field, double value, double bodyWeightKg, double durationH) {
    switch (field) {
      case MacroField.duringRunCarbTotal:
        final ratePerHour = durationH > 0 ? value / durationH : 0;
        if (ratePerHour < 20) return 'Below recommended minimum (30-60 g/h)';
        if (ratePerHour > 90) return 'Above typical absorption capacity';
        break;
      case MacroField.duringRunFluidTotal:
        // Convert fl oz to ml for validation
        final valueML = value * 29.5735;
        final ratePerHour = durationH > 0 ? valueML / durationH : 0;
        if (ratePerHour < 350) return 'May lead to dehydration';
        if (ratePerHour > 1200) return 'May cause GI distress';
        break;
      case MacroField.duringRunSodiumTotal:
        final ratePerHour = durationH > 0 ? value / durationH : 0;
        if (ratePerHour < 200) return 'Risk of cramping';
        if (ratePerHour > 800) return 'Excessive sodium';
        break;
      default:
        break;
    }
    return null;
  }

  String? _validatePostRunMacro(MacroField field, double value, double bodyWeightKg) {
    switch (field) {
      case MacroField.postRunCarbs:
        if (value < 1.0 * bodyWeightKg) return 'Below optimal recovery (1.0-1.2 g/kg)';
        if (value > 1.5 * bodyWeightKg) return 'More than typically needed';
        break;
      case MacroField.postRunProtein:
        if (value < 0.25 * bodyWeightKg) return 'Below optimal recovery (0.25-0.3 g/kg)';
        if (value > 0.5 * bodyWeightKg) return 'More than typically needed';
        break;
      case MacroField.postRunFluids:
        // Fluid validation would ideally be based on sweat loss
        final valueML = value * 29.5735;
        if (valueML < 500) return 'May be insufficient for rehydration';
        if (valueML > 1500) return 'Risk of overhydration';
        break;
      case MacroField.postRunSodium:
        if (value < 300) return 'May be insufficient';
        if (value > 1000) return 'Higher than typically needed';
        break;
      default:
        break;
    }
    return null;
  }
}