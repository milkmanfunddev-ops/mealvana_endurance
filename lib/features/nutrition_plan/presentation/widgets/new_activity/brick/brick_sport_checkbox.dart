import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/kyle_design/text/section_header_text.dart';
import '../../../../../../core/theme/app_theme.dart';

/// Brick Sport Checkbox Selector
///
/// Displays checkboxes for selecting which sports to include in a brick workout.
/// Enforces minimum 2 sports requirement.
class BrickSportCheckbox extends StatelessWidget {
  final Set<String> selectedSports;
  final Function(String sport, bool selected) onToggle;

  const BrickSportCheckbox({
    super.key,
    required this.selectedSports,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final showValidation = selectedSports.length < 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderText(
          'Select sports for your brick:',
          fontSize: 16,
          topPadding: 0,
          bottomPadding: 8,
        ),
        const SizedBox(height: 8),
        _buildCheckbox('swimming', 'Swimming', context),
        _buildCheckbox('cycling', 'Cycling', context),
        _buildCheckbox('running', 'Running', context),
        if (showValidation) ...[
          const SizedBox(height: 8),
          Text(
            'Select at least 2 sports',
            style: TextStyle(
              color: AppTheme.errorColor,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCheckbox(String sport, String label, BuildContext context) {
    final isSelected = selectedSports.contains(sport);
    final canDeselect = selectedSports.length > 2 || !isSelected;

    return CheckboxListTile(
      value: isSelected,
      onChanged: canDeselect
          ? (bool? value) {
              if (value != null) {
                onToggle(sport, value);
              }
            }
          : null, // Disable if at minimum and this is selected
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: 'Apercu',
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppTheme.electrolyte,
      contentPadding: EdgeInsets.zero,
    );
  }
}
