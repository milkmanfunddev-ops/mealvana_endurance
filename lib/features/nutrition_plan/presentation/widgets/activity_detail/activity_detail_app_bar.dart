import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../providers/activity_detail_controller.dart';
import '../../providers/activity_detail_state.dart';
import '../../../../coach_mode/presentation/providers/coach_activity_detail_controller.dart';

/// AppBar for ActivityDetailScreen with back button, title, and action buttons
class ActivityDetailAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const ActivityDetailAppBar({
    super.key,
    required this.activityId,
    required this.isNewActivity,
    required this.isCoachView,
    required this.onSaveTemplate,
    required this.onEdit,
    required this.onDelete,
  });

  final String activityId;
  final bool isNewActivity;
  final bool isCoachView;
  final VoidCallback onSaveTemplate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor.withValues(alpha: 0.95),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          CustomAppBarBackButton(
            onPressed: () => context.pop(),
            margin: EdgeInsets.zero,
            iconColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final asyncState = isCoachView
                    ? ref.watch(
                        coachActivityDetailControllerProvider(activityId),
                      )
                    : ref.watch(
                        activityDetailControllerProvider(
                          activityId: activityId,
                          isNewActivity: isNewActivity,
                        ),
                      );
                final eventName = asyncState.whenOrNull(
                  data: (data) {
                    if (data is ActivityDetailState) return data.eventName;
                    return null;
                  },
                );
                final title =
                    eventName ??
                    (isNewActivity ? 'New Activity' : 'Activity Details');
                return Text(
                  title,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        // Save as Template button (only for existing activities with a nutrition plan)
        if (!isNewActivity && !isCoachView)
          IconButton(
            icon: Icon(
              FontAwesomeIcons.bookmark,
              size: AppIconSizes.md,
              color: AppColors.electrolyte,
            ),
            onPressed: onSaveTemplate,
            tooltip: 'Save as Template',
          ),
        // Edit button for existing activities (not new ones, not coach view)
        if (!isNewActivity && !isCoachView)
          IconButton(
            icon: Icon(
              FontAwesomeIcons.penToSquare,
              size: AppIconSizes.md,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: onEdit,
            tooltip: 'Edit Activity',
          ),
        // Only show delete button for existing activities (not new ones, not coach view)
        if (!isNewActivity && !isCoachView)
          IconButton(
            icon: Icon(
              FontAwesomeIcons.trash,
              size: AppIconSizes.md,
              color: AppColors.dragonfruit,
            ),
            onPressed: onDelete,
            tooltip: 'Delete Activity',
          ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}
