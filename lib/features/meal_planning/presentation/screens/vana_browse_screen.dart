import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_plan_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/meal_ref.dart';
import '../../domain/ui_action.dart';
import '../widgets/meal_catalog_browser.dart';
import '../widgets/vana_round_button.dart';

/// `/vana/browse?c=<conversationId>` — "Browse meals" from the Vana chat
/// (Lee, 2026-09-03: "browse all of our recipes and assign them to the meal
/// plan"). The Meals tab's catalog browser with an Add affordance on every
/// card: a tap picks the meal into THIS conversation's draft (remote-ack
/// `pick_meals`, the picker's default servings), ticks the card and toasts;
/// the card body opens the detail with `?pick=` so "Add to plan" is there
/// too. "Done" pops back to the chat, which reloads its draft.
class VanaBrowseScreen extends ConsumerStatefulWidget {
  const VanaBrowseScreen({super.key, required this.conversationId});

  final String conversationId;

  /// Same default the picker carousel uses when the server sends none
  /// (`VanaMealPickerPart.defaultServings`).
  static const defaultServings = 4;

  @override
  ConsumerState<VanaBrowseScreen> createState() => _VanaBrowseScreenState();
}

class _VanaBrowseScreenState extends ConsumerState<VanaBrowseScreen> {
  final Set<String> _added = {};
  final Set<String> _inFlight = {};

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Scaffold(
      key: const ValueKey('meal_planning.vana_browse_screen'),
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  VanaRoundButton.back(
                    context: context,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      content.getValue(ContentKeys.mpBrowseTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: textColor,
                        fontSize: 20,
                        height: 1.1,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('meal_planning.browse_done'),
                    onPressed: () => context.pop(),
                    child: Text(
                      content.getValue(ContentKeys.mpBrowseDone),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MealCatalogBrowser(
                onOpenMeal: _openDetail,
                onAddMeal: _add,
                addedIds: _added,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The detail pops `true` when its "Add to plan" landed — tick the card.
  Future<void> _openDetail(MealRef meal) async {
    final added = await context.push<bool>(
      '/food/meals/${meal.id}?pick=${widget.conversationId}',
    );
    if (added == true && mounted) setState(() => _added.add(meal.id));
  }

  Future<void> _add(MealRef meal) async {
    if (_inFlight.contains(meal.id) || _added.contains(meal.id)) return;
    final content = ref.read(contentServiceProvider);
    _inFlight.add(meal.id);
    try {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .pickMeals(
            [MealPick(source: meal.source, id: meal.id)],
            servings: VanaBrowseScreen.defaultServings,
            conversationId: widget.conversationId,
          );
      if (!mounted) return;
      setState(() => _added.add(meal.id));
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpBrowseAddedToast),
        duration: MealvanaSnackbar.shortDuration,
      );
    } on NeedsConnectionException {
      if (mounted) {
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(ContentKeys.mpNeedsConnection),
        );
      }
    } on Exception {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpServerError),
        );
      }
    } finally {
      _inFlight.remove(meal.id);
    }
  }
}
