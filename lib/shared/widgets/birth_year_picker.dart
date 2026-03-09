import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/kyle_design/kyle_design.dart';

/// Shows a bottom sheet with an iOS-style scroll wheel for selecting birth year.
///
/// Returns the selected year as an [int], or null if cancelled.
Future<int?> showBirthYearPicker({
  required BuildContext context,
  int? initialYear,
}) async {
  final currentYear = DateTime.now().year;
  final minYear = 1920;
  final maxYear = currentYear - 16;
  final defaultYear = initialYear ?? 1990;

  int selectedYear = defaultYear.clamp(minYear, maxYear);

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _BirthYearPickerSheet(
        minYear: minYear,
        maxYear: maxYear,
        initialYear: selectedYear,
      );
    },
  );
}

class _BirthYearPickerSheet extends StatefulWidget {
  const _BirthYearPickerSheet({
    required this.minYear,
    required this.maxYear,
    required this.initialYear,
  });

  final int minYear;
  final int maxYear;
  final int initialYear;

  @override
  State<_BirthYearPickerSheet> createState() => _BirthYearPickerSheetState();
}

class _BirthYearPickerSheetState extends State<_BirthYearPickerSheet> {
  late int _selectedYear;
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _scrollController = FixedExtentScrollController(
      initialItem: _selectedYear - widget.minYear,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberry : AppColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.cream : AppColors.blackberry)
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with cancel/done
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                    ),
                  ),
                ),
                Text(
                  'Birth Year',
                  style: AppTextStyles.subtitle.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedYear),
                  child: Text(
                    'Done',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Year wheel picker
          SizedBox(
            height: 200,
            child: CupertinoPicker(
              scrollController: _scrollController,
              itemExtent: 40,
              magnification: 1.2,
              squeeze: 1.0,
              useMagnifier: true,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: AppColors.orange.withValues(alpha: 0.1),
              ),
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedYear = widget.minYear + index;
                });
              },
              children: List.generate(
                widget.maxYear - widget.minYear + 1,
                (index) {
                  final year = widget.minYear + index;
                  return Center(
                    child: Text(
                      year.toString(),
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 22,
                        color: isDark ? AppColors.cream : AppColors.blackberry,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
