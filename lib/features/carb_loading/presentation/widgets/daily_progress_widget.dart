import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Daily carb progress widget showing total consumed vs target
/// Displays progress like "181g / 350g" with percentage and edit button
/// This widget is pure and takes the total consumed as a parameter for better state management
class DailyProgressWidget extends StatelessWidget {
  final int totalConsumed;
  final int targetAmount;
  final VoidCallback onEditTarget;
  final String? title;

  const DailyProgressWidget({
    super.key,
    required this.totalConsumed,
    required this.targetAmount,
    required this.onEditTarget,
    this.title = 'Total Daily Progress',
  });

  @override
  Widget build(BuildContext context) {
    final percentage = targetAmount > 0 ? (totalConsumed / targetAmount * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${totalConsumed}g',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary900,
                      ),
                    ),
                    Text(
                      ' / ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey[400],
                      ),
                    ),
                    Text(
                      '${targetAmount}g',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$percentage% complete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEditTarget,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Edit Target',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}