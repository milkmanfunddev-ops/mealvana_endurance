import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/brick_input_controller.dart';
import '../../../providers/new_activity_coordinator.dart';
import 'brick_sport_checkbox.dart';
import '../../../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../../shared/widgets/kyle_design/typography/section_header_text.dart';

/// Brick Tab Content
///
/// Main content widget for the brick workout tab in the New Activity screen.
/// Displays:
/// - Sport checkbox selector (which sports to include)
/// - Ordered list of segment input sections (expandable accordions)
/// - Generate Macros button (disabled until valid)
///
/// Phase 4.2: Basic structure with sport selection and placeholder for segments
/// Phase 4.3: Will add full segment input sections
/// Phase 4.4: Will add drag-to-reorder functionality
class BrickTabContent extends ConsumerWidget {
  const BrickTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(brickInputControllerProvider);
    final controller = ref.read(brickInputControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isFormValid = controller.isValid();
    final totalDuration = controller.getTotalDuration();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sport checkbox selector
        BrickSportCheckbox(
          selectedSports: formState.selectedSports,
          onToggle: (sport, selected) {
            controller.toggleSport(sport);
          },
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Drag to reorder label
        if (formState.selectedSports.length >= 2) ...[
          const SectionHeaderText(
            text: 'Drag to reorder:',
            topPadding: 0,
            bottomPadding: 12,
          ),

          // Ordered list of segments
          _buildSegmentList(context, formState, controller, isDark),

          const SizedBox(height: AppSpacing.xxl),
        ],

        // Total duration display (if any segments have data)
        if (totalDuration > 0) ...[
          Text(
            'Total Duration: $totalDuration minutes',
            style: AppTextStyles.descriptor.copyWith(
              color: isDark ? AppColors.cream : AppColors.blackberry,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // Spacer to push button to bottom
        const Spacer(),

        // Generate Macros button
        KylePrimaryButton(
          text: 'Generate Macros',
          onPressed: isFormValid
              ? () => _handleGenerateMacros(context, ref)
              : null,
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// Handle generate macros button press
  Future<void> _handleGenerateMacros(BuildContext context, WidgetRef ref) async {
    try {
      // Validate form
      final controller = ref.read(brickInputControllerProvider.notifier);
      if (!controller.isValid()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete all segment details before generating macros'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating brick macro targets...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Call coordinator to generate macros
      final coordinator = ref.read(newActivityCoordinatorProvider.notifier);
      await coordinator.generateMacros();

      // Navigate to adjust macros screen
      if (context.mounted) {
        context.push('/adjust-macros');
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating macros: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildSegmentList(
    BuildContext context,
    BrickFormState formState,
    BrickInputController controller,
    bool isDark,
  ) {
    // Filter to only show selected sports in the current order
    final orderedSelectedSports = formState.sportOrder
        .where((sport) => formState.selectedSports.contains(sport))
        .toList();

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orderedSelectedSports.length,
      onReorder: controller.reorderSports,
      itemBuilder: (context, index) {
        final sport = orderedSelectedSports[index];
        final segmentInput = formState.segmentInputs[sport];

        return _SegmentCard(
          key: ValueKey(sport),
          sport: sport,
          order: index + 1,
          segmentInput: segmentInput,
          isDark: isDark,
        );
      },
    );
  }
}

/// Segment card widget (expandable in Phase 4.3)
///
/// Phase 4.2: Shows sport name and order number with drag handle
/// Phase 4.3: Will expand to show full sport-specific input fields
class _SegmentCard extends StatelessWidget {
  final String sport;
  final int order;
  final BrickSegmentInput? segmentInput;
  final bool isDark;

  const _SegmentCard({
    required super.key,
    required this.sport,
    required this.order,
    required this.segmentInput,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sportDisplayName = _getSportDisplayName(sport);
    final isValid = segmentInput?.isValid() ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.blackberry : AppColors.cream)
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.cream : AppColors.blackberry)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          Icon(
            Icons.drag_handle,
            color: (isDark ? AppColors.cream : AppColors.blackberry)
                .withValues(alpha: 0.6),
          ),

          const SizedBox(width: AppSpacing.md),

          // Order number and sport name
          Expanded(
            child: Text(
              '$order. $sportDisplayName',
              style: AppTextStyles.descriptor.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),

          // Expand/collapse icon (Phase 4.3)
          Icon(
            Icons.keyboard_arrow_down,
            color: (isDark ? AppColors.cream : AppColors.blackberry)
                .withValues(alpha: 0.6),
          ),

          // Validation indicator
          const SizedBox(width: AppSpacing.sm),
          if (isValid)
            Icon(
              Icons.check_circle,
              color: AppColors.electrolyte,
              size: 20,
            )
          else
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 20,
            ),
        ],
      ),
    );
  }

  String _getSportDisplayName(String sport) {
    switch (sport) {
      case 'swimming':
        return 'Swimming';
      case 'cycling':
        return 'Cycling';
      case 'running':
        return 'Running';
      default:
        return sport;
    }
  }
}
