import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/activity.dart';
import '../../../../shared/domain/activity_type.dart';
import '../providers/activities_controller.dart';

/// Reusable activity card widget with swipe-to-delete functionality.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({
    super.key,
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = const Color(0xFF2196F3);

    return Dismissible(
      key: Key(activity.id),
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
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (direction) => _handleDelete(context, ref),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildActivityIcon(accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActivityDetails(context),
                ),
                _buildStatusIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityIcon(Color accentColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getActivityIcon(activity.activityType),
        color: accentColor,
        size: 24,
      ),
    );
  }

  Widget _buildActivityDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatActivityDetails(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    switch (activity.status) {
      case ActivityStatus.completed:
        return const Icon(
          Icons.check_circle,
          color: Color(0xFF4CAF50),
          size: 24,
        );
      case ActivityStatus.skipped:
        return const Icon(
          Icons.remove_circle_outline,
          color: Colors.grey,
          size: 24,
        );
      case ActivityStatus.inProgress:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFFF9800)),
          ),
        );
      case ActivityStatus.planned:
        return Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF2196F3),
            shape: BoxShape.circle,
          ),
        );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Activity'),
          content: Text('Are you sure you want to delete "${activity.title}"?'),
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

  void _handleDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final activityTitle = activity.title;
    final activityId = activity.id;

    // Delete activity after dismissal is complete
    final activitiesController = ref.read(activitiesControllerProvider.notifier);
    await activitiesController.deleteActivity(activityId);

    // Show SnackBar after deletion (widget is already dismissed)
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "$activityTitle"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // TODO: Implement undo functionality if needed
          },
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    context.push('/plan', extra: {
      'mode': 'edit',
      'activityId': activity.id,
    });
  }

  String _formatActivityDetails() {
    final parts = <String>[];

    switch (activity.activityType) {
      case ActivityType.running:
        if (activity.distanceMiles != null) {
          parts.add('${activity.distanceMiles} mi');
        }
        if (activity.formattedPace != null) {
          parts.add(activity.formattedPace!);
        }
        break;

      case ActivityType.cycling:
        if (activity.distanceMiles != null) {
          parts.add('${activity.distanceMiles} mi');
        }
        if (activity.cyclingSpeedMph != null) {
          parts.add('${activity.cyclingSpeedMph!.toStringAsFixed(1)} mph');
        }
        break;

      case ActivityType.swimming:
        if (activity.distanceMiles != null) {
          final meters = (activity.distanceMiles! * 1609.34).round();
          parts.add('${meters}m');
        }
        if (activity.swimmingPacePer100mSeconds != null) {
          final totalSeconds = activity.swimmingPacePer100mSeconds!;
          final minutes = totalSeconds ~/ 60;
          final seconds = totalSeconds % 60;
          parts.add('$minutes:${seconds.toString().padLeft(2, '0')}/100m');
        }
        break;
    }

    return parts.join(' • ');
  }

  IconData _getActivityIcon(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.swimming:
        return Icons.pool;
    }
  }
}
