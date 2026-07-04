import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../events/application/nutrition_plan_navigation.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../providers/checklist_controller.dart';

/// Race Day Checklist Screen
///
/// Displays a dynamically generated gear checklist based on:
/// - Event type (running, cycling, swimming, triathlon, etc.)
/// - Event distance (5K, marathon, Ironman, etc.)
/// - User gender (for gender-specific items like sports bra)
///
/// Items are persisted to the database and synced with Supabase.
class RaceChecklistScreen extends ConsumerWidget {
  final String eventId;

  const RaceChecklistScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistAsync = ref.watch(checklistControllerProvider(eventId));
    final progress = ref.watch(checklistProgressProvider(eventId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(
          key: ValueKey('checklist.back_button'),
        ),
        title: Text(
          key: const ValueKey('checklist.title'),
          'Race Day Checklist',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: ContentArea.wide(
        child: checklistAsync.when(
          data: (items) =>
              _buildChecklistContent(context, ref, items, progress),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.electrolyte),
          ),
          error: (error, stack) => _buildErrorState(context, error.toString()),
        ),
      ),
    );
  }

  Widget _buildChecklistContent(
    BuildContext context,
    WidgetRef ref,
    List items,
    ChecklistProgress progress,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Header Card
          BaseCard(
            key: const ValueKey('checklist.intro_card'),
            margin: AppSpacing.screenPaddingHorizontal,
            child: Column(
              children: [
                FaIcon(
                  FontAwesomeIcons.listCheck,
                  size: 48,
                  color: AppColors.electrolyte,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Race Day Gear Checklist',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tap items to check them off as you pack!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Separate items by category
          ...() {
            final gearItems = items
                .where((item) => item.category == 'gear')
                .toList();
            final nutritionItems = items
                .where((item) => item.category == 'nutrition')
                .toList();

            return [
              // Gear Section
              if (gearItems.isNotEmpty)
                _buildCategoryCard(
                  context,
                  ref,
                  cardKey: const ValueKey('checklist.gear_section'),
                  title: 'Race Day Gear',
                  icon: FontAwesomeIcons.shirt.data,
                  items: gearItems,
                  category: 'gear',
                ),

              if (gearItems.isNotEmpty &&
                  (nutritionItems.isNotEmpty || items.isNotEmpty))
                const SizedBox(height: AppSpacing.lg),

              // Nutrition Section
              if (nutritionItems.isNotEmpty)
                _buildCategoryCard(
                  context,
                  ref,
                  cardKey: const ValueKey('checklist.nutrition_section'),
                  title: 'Nutrition',
                  icon: FontAwesomeIcons.appleWhole.data,
                  items: nutritionItems,
                  category: 'nutrition',
                )
              else if (gearItems.isNotEmpty)
                _buildNutritionEmptyState(context, ref),

              const SizedBox(height: AppSpacing.lg),

              // Overall Progress
              if (items.isNotEmpty)
                BaseCard(
                  margin: AppSpacing.screenPaddingHorizontal,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress.progress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.electrolyte,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${progress.checked}/${progress.total}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Completion message
                      if (progress.isComplete) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.electrolyte.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.circleCheck,
                                size: AppIconSizes.sm,
                                color: AppColors.electrolyte,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'All packed! You\'re ready for race day! 🎉',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.electrolyte,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ];
          }(),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(
    BuildContext context,
    WidgetRef ref,
    String title,
    bool isChecked,
    VoidCallback onTap, {
    Key? itemKey,
  }) {
    return InkWell(
      key: itemKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              isChecked
                  ? FontAwesomeIcons.solidSquareCheck.data
                  : FontAwesomeIcons.square.data,
              size: AppIconSizes.sm,
              color: isChecked
                  ? AppColors.electrolyte
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isChecked
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  decorationThickness: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return BaseCard(
      margin: AppSpacing.screenPaddingHorizontal,
      child: Column(
        children: [
          FaIcon(
            FontAwesomeIcons.boxOpen,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No items yet',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your checklist is being generated...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: BaseCard(
        margin: AppSpacing.screenPaddingHorizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error loading checklist',
              style: AppTextStyles.subtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleItem(WidgetRef ref, String itemId, bool isChecked) {
    ref
        .read(checklistControllerProvider(eventId).notifier)
        .toggleItem(itemId, isChecked);
  }

  void _showAddItemDialog(
    BuildContext context,
    WidgetRef ref,
    String category,
  ) {
    final controller = TextEditingController();
    final categoryName = category == 'nutrition' ? 'nutrition' : 'gear';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Custom Item',
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to $categoryName section',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Item name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  ref
                      .read(checklistControllerProvider(eventId).notifier)
                      .addCustomItem(value.trim(), category);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          KylePrimaryButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                ref
                    .read(checklistControllerProvider(eventId).notifier)
                    .addCustomItem(controller.text.trim(), category);
              }
            },
            text: 'Add',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    WidgetRef ref, {
    Key? cardKey,
    required String title,
    required IconData icon,
    required List items,
    String? category,
  }) {
    return BaseCard(
      key: cardKey,
      margin: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppIconSizes.sm, color: AppColors.electrolyte),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Checklist items
          ...items.map((item) {
            // Only custom items (not template items) can be deleted
            if (!item.isTemplateItem) {
              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.trash,
                    color: Colors.white,
                    size: AppIconSizes.sm,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'Delete Item?',
                        style: AppTextStyles.subtitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to delete "${item.itemName}"?',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Delete',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  ref
                      .read(checklistControllerProvider(eventId).notifier)
                      .deleteItem(item.id);
                },
                child: _buildChecklistItem(
                  context,
                  ref,
                  item.itemName,
                  item.isChecked,
                  () => _toggleItem(ref, item.id, !item.isChecked),
                  itemKey: ValueKey('checklist.gear_item_${item.id}'),
                ),
              );
            }

            // Template items are not deletable
            return _buildChecklistItem(
              context,
              ref,
              item.itemName,
              item.isChecked,
              () => _toggleItem(ref, item.id, !item.isChecked),
              itemKey: ValueKey('checklist.gear_item_${item.id}'),
            );
          }),

          const SizedBox(height: AppSpacing.sm),

          // Add custom item button
          InkWell(
            key: ValueKey('checklist.add_custom_button_${category ?? 'gear'}'),
            onTap: () => _showAddItemDialog(context, ref, category ?? 'gear'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.plus,
                    size: AppIconSizes.xs,
                    color: AppColors.electrolyte,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Add custom item',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.electrolyte,
                      fontWeight: FontWeight.w600,
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

  Widget _buildNutritionEmptyState(BuildContext context, WidgetRef ref) {
    return BaseCard(
      margin: AppSpacing.screenPaddingHorizontal,
      child: Column(
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.appleWhole,
                size: AppIconSizes.sm,
                color: AppColors.electrolyte,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Nutrition',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FaIcon(
            FontAwesomeIcons.bottleWater,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No nutrition plan yet',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Create a nutrition plan to add items here',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          KyleSecondaryButton(
            onPressed: () => _createNutritionPlan(context, ref),
            text: 'Create Nutrition Plan',
            icon: FontAwesomeIcons.plus.data,
          ),
        ],
      ),
    );
  }

  /// Navigate directly to the create-nutrition-plan flow for this event.
  ///
  /// Mirrors the "Create Nutrition Plan" button on the event detail screen
  /// (see [EventActionButtonsCard]) via the shared [buildNutritionPlanExtras]
  /// helper so both entry points stay in sync.
  Future<void> _createNutritionPlan(BuildContext context, WidgetRef ref) async {
    try {
      final detail = await ref.read(eventDetailProvider(eventId).future);

      final extras = buildNutritionPlanExtras(
        event: detail.event,
        activity: detail.activity,
      );

      if (context.mounted) {
        context.push('/distance-pace-gut-entry', extra: extras);
      }
    } catch (e) {
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          'Could not load event details: $e',
        );
      }
    }
  }
}
