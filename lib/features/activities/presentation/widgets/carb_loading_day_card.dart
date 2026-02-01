import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../carb_loading/presentation/screens/carb_loading_day_detail_page.dart';

/// Reusable carb loading day card widget with swipe-to-delete functionality.
class CarbLoadingDayCard extends ConsumerWidget {
  const CarbLoadingDayCard({
    super.key,
    required this.carbDay,
  });

  final db.CarbLoadingDay carbDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayNumber = carbDay.dayNumber;
    final targetCarbs = carbDay.carbTargetGrams;
    final loggedCarbs = carbDay.loggedCarbsGrams;
    final progress = targetCarbs > 0 ? (loggedCarbs / targetCarbs).clamp(0.0, 1.0) : 0.0;
    final isCompleted = carbDay.completed;

    return Dismissible(
      key: Key(carbDay.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) => _confirmDelete(context, dayNumber),
      onDismissed: (direction) => _handleDelete(context, ref, dayNumber),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _handleTap(context),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFFF9800),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildIcon(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetails(context, dayNumber, targetCarbs, loggedCarbs, progress),
                  ),
                  _buildStatusIndicator(isCompleted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.restaurant_menu,
        color: Color(0xFFFF9800),
        size: 24,
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    int dayNumber,
    int targetCarbs,
    int loggedCarbs,
    double progress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'Carb Loading Day $dayNumber',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // const SizedBox(width: 8),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            //   decoration: BoxDecoration(
            //     color: const Color(0xFFFF9800),
            //     borderRadius: BorderRadius.circular(10),
            //   ),
            //   child: const Text(
            //     'RACE PREP',
            //     style: TextStyle(
            //       color: Colors.white,
            //       fontSize: 10,
            //       fontWeight: FontWeight.bold,
            //     ),
            //   ),
            // ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Target: ${targetCarbs}g carbs',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        if (loggedCarbs > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 0.9 ? Colors.green : const Color(0xFFFF9800),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${loggedCarbs}g',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIndicator(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCompleted ? Icons.check : Icons.schedule,
        color: isCompleted ? Colors.green : Colors.grey[600],
        size: 20,
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, int dayNumber) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Carb Loading Day'),
          content: Text('Are you sure you want to delete "Carb Loading Day $dayNumber"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _handleDelete(BuildContext context, WidgetRef ref, int dayNumber) {
    final carbDayId = carbDay.id;

    final carbLoadingController = ref.read(carbLoadingControllerProvider.notifier);
    carbLoadingController.deleteCarbLoadingDay(carbDayId);

    MealvanaSnackbar.showSuccess(context, 'Deleted "Carb Loading Day $dayNumber"');
  }

  void _handleTap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CarbLoadingDayDetailPage(
          carbLoadingDay: carbDay,
        ),
      ),
    );
  }
}
