import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../providers/activity_detail_controller.dart';
import '../../providers/activity_detail_state.dart';
import '../../utils/activity_detail_helpers.dart';
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
    required this.onEditFuelLog,
    this.isFuelLogMode = false,
    this.onDoneFuelLog,
    this.onBackFromFuelLog,
  });

  final String activityId;
  final bool isNewActivity;
  final bool isCoachView;
  final VoidCallback onSaveTemplate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEditFuelLog;

  // Fuel log mode
  final bool isFuelLogMode;
  final VoidCallback? onDoneFuelLog;
  final VoidCallback? onBackFromFuelLog;

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
          isFuelLogMode
              ? Container(
                  margin: EdgeInsets.zero,
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.1),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 20,
                      ),
                      onPressed: onBackFromFuelLog ?? () => context.pop(),
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                )
              : CustomAppBarBackButton(
                  key: const ValueKey('plan_detail.back_button'),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/main');
                    }
                  },
                  margin: EdgeInsets.zero,
                  iconColor: Theme.of(context).colorScheme.onSurface,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buildTitle(context, ref)),
        ],
      ),
      actions: isFuelLogMode
          ? _buildFuelLogActions(context)
          : _buildNormalActions(context, ref),
    );
  }

  Widget _buildTitle(BuildContext context, WidgetRef ref) {
    if (isFuelLogMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Log Workout Fuel',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Adjust what you consumed',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final asyncState = isCoachView
            ? ref.watch(coachActivityDetailControllerProvider(activityId))
            : ref.watch(
                activityDetailControllerProvider(
                  activityId: activityId,
                  isNewActivity: isNewActivity,
                ),
              );
        final (String? eventName, String? activityTitle, int? leadMinutes) =
            asyncState.whenOrNull(
              data: (data) {
                if (data is ActivityDetailState) {
                  return (
                    data.eventName,
                    data.activity?.title,
                    data.activity?.timeBeforeMinutes,
                  );
                }
                return (null, null, null);
              },
            ) ??
            (null, null, null);
        final title =
            eventName ??
            activityTitle ??
            (isNewActivity ? 'New Activity' : 'Activity Details');
        final titleText = Text(
          key: const ValueKey('plan_detail.title'),
          title,
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        );
        // Frozen lead time — the minutes-before-workout captured at plan
        // generation, not the clock ("Planned 3 hours ahead", digest §5).
        if (leadMinutes == null || leadMinutes <= 0) return titleText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleText,
            Text(
              'Planned ${ActivityDetailHelpers.formatLeadTime(leadMinutes)} ahead',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildFuelLogActions(BuildContext context) {
    return [
      TextButton(
        onPressed: onDoneFuelLog,
        child: Text(
          'Done',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.orange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
    ];
  }

  List<Widget> _buildNormalActions(BuildContext context, WidgetRef ref) {
    final asyncState = isCoachView
        ? ref.watch(coachActivityDetailControllerProvider(activityId))
        : ref.watch(
            activityDetailControllerProvider(
              activityId: activityId,
              isNewActivity: isNewActivity,
            ),
          );

    final state = asyncState.whenOrNull(
      data: (data) => data is ActivityDetailState ? data : null,
    );

    final isCompleted = state?.isCompleted ?? false;

    return [
      // Save as Template button (only for existing activities with a nutrition plan)
      if (!isNewActivity && !isCoachView && !isCompleted)
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.bookmark,
            size: AppIconSizes.md,
            color: AppColors.electrolyte,
          ),
          onPressed: onSaveTemplate,
          tooltip: 'Save as Routine',
        ),
      // Edit button for existing activities (not new ones, not coach view)
      if (!isNewActivity && !isCoachView && !isCompleted)
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.penToSquare,
            size: AppIconSizes.md,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: onEdit,
          tooltip: 'Edit Activity',
        ),
      // Edit Fuel Log button for completed activities
      if (isCompleted && !isCoachView)
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.penToSquare,
            size: AppIconSizes.md,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: onEditFuelLog,
          tooltip: 'Edit Fuel Log',
        ),
      // Show delete button for existing activities (including coach view)
      if (!isNewActivity)
        IconButton(
          key: const ValueKey('plan_detail.delete_button'),
          icon: FaIcon(
            FontAwesomeIcons.trash,
            size: AppIconSizes.md,
            color: AppColors.dragonfruit,
          ),
          onPressed: onDelete,
          tooltip: 'Delete Activity',
        ),
      const SizedBox(width: AppSpacing.sm),
    ];
  }
}
