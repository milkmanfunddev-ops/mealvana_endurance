import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Dialog for editing carb target - allows editing grams per kg bodyweight
/// or directly editing the total daily target in grams
/// Updated to follow Kyle's design system
class EditCarbTargetDialog extends StatefulWidget {
  final double currentCarbsPerKg;
  final int currentDailyTargetG;
  final double bodyWeightKg;
  final Function(double carbsPerKg, int dailyTargetG) onSave;

  const EditCarbTargetDialog({
    super.key,
    required this.currentCarbsPerKg,
    required this.currentDailyTargetG,
    required this.bodyWeightKg,
    required this.onSave,
  });

  @override
  State<EditCarbTargetDialog> createState() => _EditCarbTargetDialogState();
}

class _EditCarbTargetDialogState extends State<EditCarbTargetDialog> {
  late TextEditingController _carbsPerKgController;
  late TextEditingController _dailyTargetController;
  bool _isEditingPerKg = true; // Toggle between per kg and total grams

  @override
  void initState() {
    super.initState();
    _carbsPerKgController = TextEditingController(
      text: widget.currentCarbsPerKg.toStringAsFixed(1),
    );
    _dailyTargetController = TextEditingController(
      text: widget.currentDailyTargetG.toString(),
    );

    // Update opposite field when one changes
    _carbsPerKgController.addListener(_updateDailyFromPerKg);
    _dailyTargetController.addListener(_updatePerKgFromDaily);
  }

  @override
  void dispose() {
    _carbsPerKgController.removeListener(_updateDailyFromPerKg);
    _dailyTargetController.removeListener(_updatePerKgFromDaily);
    _carbsPerKgController.dispose();
    _dailyTargetController.dispose();
    super.dispose();
  }

  void _updateDailyFromPerKg() {
    if (_isEditingPerKg) {
      final carbsPerKg = double.tryParse(_carbsPerKgController.text) ?? 0;
      final dailyTarget = (carbsPerKg * widget.bodyWeightKg).round();
      _dailyTargetController.text = dailyTarget.toString();
    }
  }

  void _updatePerKgFromDaily() {
    if (!_isEditingPerKg) {
      final dailyTarget = int.tryParse(_dailyTargetController.text) ?? 0;
      final carbsPerKg = widget.bodyWeightKg > 0 ? dailyTarget / widget.bodyWeightKg : 0;
      _carbsPerKgController.text = carbsPerKg.toStringAsFixed(1);
    }
  }

  void _onSave() {
    final carbsPerKg = double.tryParse(_carbsPerKgController.text) ?? widget.currentCarbsPerKg;
    final dailyTarget = int.tryParse(_dailyTargetController.text) ?? widget.currentDailyTargetG;

    widget.onSave(carbsPerKg, dailyTarget);
    Navigator.of(context).pop();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.blackberryLight : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondaryTextColor = isDark
        ? AppColors.cream.withValues(alpha: 0.7)
        : AppColors.blackberry.withValues(alpha: 0.7);
    final borderColor = isDark
        ? AppColors.cream.withValues(alpha: 0.2)
        : AppColors.blackberry.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Dialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 400,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Edit Carb Target',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Body weight display
                  Text(
                    'Body Weight: ${widget.bodyWeightKg.toStringAsFixed(1)} kg',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Toggle buttons for editing mode
                  _buildToggleButtons(isDark, textColor, borderColor),
                  const SizedBox(height: AppSpacing.md),

                  // Primary input field (highlighted)
                  Text(
                    _isEditingPerKg ? 'Carbs per kg bodyweight' : 'Total daily carbs',
                    style: AppTextStyles.smallLabel.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildInputField(
                    controller: _isEditingPerKg ? _carbsPerKgController : _dailyTargetController,
                    hintText: _isEditingPerKg ? '8.0' : '560',
                    suffixText: _isEditingPerKg ? 'g/kg' : 'g',
                    textColor: textColor,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Secondary display field (calculated)
                  Text(
                    _isEditingPerKg ? 'Total daily carbs' : 'Carbs per kg bodyweight',
                    style: AppTextStyles.smallLabel.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _buildCalculatedDisplay(
                    text: _isEditingPerKg
                        ? '${_dailyTargetController.text}g'
                        : '${_carbsPerKgController.text}g/kg',
                    textColor: textColor,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Guidelines text
                  _buildGuidelinesBox(isDark),
                  const SizedBox(height: AppSpacing.lg),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: AppColors.blackberry,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Save',
                              style: AppTextStyles.buttonPrimary.copyWith(
                                color: AppColors.blackberry,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButtons(bool isDark, Color textColor, Color borderColor) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isEditingPerKg = true;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _isEditingPerKg ? AppColors.orange : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(19),
                    bottomLeft: Radius.circular(19),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Per Kg',
                  style: AppTextStyles.smallLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isEditingPerKg ? AppColors.blackberry : textColor,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isEditingPerKg = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: !_isEditingPerKg ? AppColors.orange : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(19),
                    bottomRight: Radius.circular(19),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Total Grams',
                  style: AppTextStyles.smallLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: !_isEditingPerKg ? AppColors.blackberry : textColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required String suffixText,
    required Color textColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        onChanged: (value) {
          setState(() {
            if (_isEditingPerKg) {
              _updateDailyFromPerKg();
            } else {
              _updatePerKgFromDaily();
            }
          });
        },
        style: AppTextStyles.dataNumberLarge.copyWith(
          color: textColor,
          fontSize: 20,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.bodyLarge.copyWith(
            color: textColor.withValues(alpha: 0.4),
          ),
          suffixText: suffixText,
          suffixStyle: AppTextStyles.bodyMedium.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
          filled: true,
          fillColor: isDark
              ? AppColors.blackberry.withValues(alpha: 0.5)
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.orange, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatedDisplay({
    required String text,
    required Color textColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.blackberry.withValues(alpha: 0.3)
            : AppColors.cream.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w500,
          color: textColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildGuidelinesBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.electrolyte,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '8-12g/kg per day during carb loading. Higher for longer races.',
              style: AppTextStyles.smallLabel.copyWith(
                color: isDark ? AppColors.electrolyte : AppColors.blackberry.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
