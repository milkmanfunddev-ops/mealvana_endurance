import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/macro_targets.dart';
import '../providers/macro_targets_controller.dart';

class EditMacroSectionDialog extends StatefulWidget {
  final MacroSection section;
  final String title;
  final Color iconColor;
  final Map<String, num> initialValues;
  final WidgetRef ref;

  const EditMacroSectionDialog({
    super.key,
    required this.section,
    required this.title,
    required this.iconColor,
    required this.initialValues,
    required this.ref,
  });

  @override
  State<EditMacroSectionDialog> createState() => _EditMacroSectionDialogState();
}

class _EditMacroSectionDialogState extends State<EditMacroSectionDialog> {
  late final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    widget.initialValues.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value.toString());
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  IconData _getSectionIcon(MacroSection section) {
    switch (section) {
      case MacroSection.preRun:
        return Icons.schedule;
      case MacroSection.duringRun:
        return Icons.directions_run;
      case MacroSection.postRun:
        return Icons.refresh;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      content: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - 80.h,
        ),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getSectionIcon(widget.section),
                    color: widget.iconColor,
                    size: 20.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Compact content with input fields  
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildInputFields(),
                ),
              ),
            ),
            
            // Compact action buttons
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.baseGrey,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.iconColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
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

  Color _getBackgroundColor() {
    switch (widget.section) {
      case MacroSection.duringRun:
        return AppTheme.primary50; // Cream color for during run
      case MacroSection.preRun:
      case MacroSection.postRun:
        return Colors.white;
    }
  }

  List<Widget> _buildInputFields() {
    final fields = <Widget>[];
    
    widget.initialValues.forEach((key, value) {
      if (fields.isNotEmpty) {
        fields.add(SizedBox(height: 12.h));
      }
      fields.add(_buildTextField(key, _getFieldLabel(key), _getFieldUnit(key)));
    });

    return fields;
  }

  Widget _buildTextField(String key, String label, String unit) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary900,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          flex: 1,
          child: TextField(
            controller: _controllers[key],
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary900,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              suffix: Text(
                unit,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.baseGrey,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(
                  color: AppTheme.baseGrey.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(
                  color: widget.iconColor,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
          ),
        ),
      ],
    );
  }

  String _getFieldLabel(String key) {
    switch (key) {
      case 'carbs': return 'Carbohydrates';
      case 'protein': return 'Protein';
      case 'fatCap': return 'Fat Cap';
      case 'fluids': return 'Fluids';
      case 'sodium': return 'Sodium';
      default: return key.toUpperCase();
    }
  }

  String _getFieldUnit(String key) {
    switch (key) {
      case 'carbs':
      case 'protein':
      case 'fatCap':
        return 'g';
      case 'fluids':
        return 'ml';
      case 'sodium':
        return 'mg';
      default:
        return '';
    }
  }

  void _saveChanges() async {
    final controller = widget.ref.read(macroTargetsControllerProvider.notifier);
    
    // Update each field value through the controller
    for (final entry in _controllers.entries) {
      final key = entry.key;
      final textController = entry.value;
      final value = double.tryParse(textController.text) ?? 0.0;
      
      // Map the field key to the appropriate MacroField enum
      final macroField = _getMacroField(widget.section, key);
      if (macroField != null) {
        await controller.updateMacroValue(
          section: widget.section,
          field: macroField,
          newValue: value,
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  MacroField? _getMacroField(MacroSection section, String key) {
    switch (section) {
      case MacroSection.preRun:
        switch (key) {
          case 'carbs': return MacroField.preRunCarbs;
          case 'protein': return MacroField.preRunProtein;
          case 'fluids': return MacroField.preRunFluids;
          case 'sodium': return MacroField.preRunSodium;
          default: return null;
        }
      case MacroSection.duringRun:
        switch (key) {
          case 'carbs': return MacroField.duringRunCarbTotal;
          case 'fluids': return MacroField.duringRunFluidTotal;
          case 'sodium': return MacroField.duringRunSodiumTotal;
          default: return null;
        }
      case MacroSection.postRun:
        switch (key) {
          case 'carbs': return MacroField.postRunCarbs;
          case 'protein': return MacroField.postRunProtein;
          case 'fluids': return MacroField.postRunFluids;
          case 'sodium': return MacroField.postRunSodium;
          default: return null;
        }
    }
  }
}