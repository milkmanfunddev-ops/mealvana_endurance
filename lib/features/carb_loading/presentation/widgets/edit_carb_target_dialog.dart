import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Dialog for editing carb target - allows editing grams per kg bodyweight
/// or directly editing the total daily target in grams
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Carb Target',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Body Weight: ${widget.bodyWeightKg.toStringAsFixed(1)} kg',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Toggle buttons for editing mode
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditingPerKg = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isEditingPerKg ? AppTheme.primary900 : Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: _isEditingPerKg ? AppTheme.primary900 : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        'Per Kg',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _isEditingPerKg ? Colors.white : Colors.grey[700],
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isEditingPerKg ? AppTheme.primary900 : Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: !_isEditingPerKg ? AppTheme.primary900 : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        'Total Grams',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: !_isEditingPerKg ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Primary input field (highlighted)
            Text(
              _isEditingPerKg ? 'Carbs per kg bodyweight' : 'Total daily carbs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _isEditingPerKg ? _carbsPerKgController : _dailyTargetController,
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
              decoration: InputDecoration(
                hintText: _isEditingPerKg ? '8.0' : '560',
                suffixText: _isEditingPerKg ? 'g/kg' : 'g',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primary900),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primary900, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Secondary display field (calculated)
            Text(
              _isEditingPerKg ? 'Total daily carbs' : 'Carbs per kg bodyweight',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _isEditingPerKg
                    ? '${_dailyTargetController.text}g'
                    : '${_carbsPerKgController.text}g/kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Guidelines text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'Guidelines: 8-12g/kg bodyweight per day during carb loading phase. Higher amounts for longer races and higher training volumes.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    text: 'Save',
                    onPressed: _onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}