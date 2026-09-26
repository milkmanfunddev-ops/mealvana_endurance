import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_catalog_controller.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/vana_chat_controller.dart';
import '../../domain/meal_plan.dart';
import '../../domain/meal_ref.dart';
import '../../domain/ui_action.dart';
import '../../domain/vana_conversation_kind.dart';
import '../widgets/meal_catalog_browser.dart';
import '../widgets/vana_round_button.dart';
import '../../../../shared/core/pop_or_home.dart';
import '../widgets/write_failure_snackbar.dart';

/// `/vana/browse?c=<conversationId>&mode=<kind>` — "Browse meals" from the
/// Vana chat (Lee, 2026-09-03: "browse all of our recipes and assign them to
/// the meal plan"). The Meals tab's catalog browser with an Add affordance
/// on every card: a tap picks the meal (remote-ack `pick_meals`, the
/// picker's default servings), ticks the card and toasts; a second tap on a
/// ticked card takes it out again (`unpick_meal`); the card body opens the
/// detail with `?pick=` so "Add to plan" is there too. "Done" pops back to
/// the chat.
///
/// Where a pick lands follows the chat's [kind] (testing-wave 134, Lee
/// 2026-09-26, 118-004): a meal-planning conversation keeps its picks in its
/// own draft; a general conversation has no draft, so its picks go into the
/// plan the Plan tab shows, or start one, and the chat's plan bar shows that
/// plan.
class VanaBrowseScreen extends ConsumerStatefulWidget {
  const VanaBrowseScreen({
    super.key,
    required this.conversationId,
    this.kind = VanaConversationKind.mealPlanning,
  });

  final String conversationId;
  final VanaConversationKind kind;

  bool get isPlanning => kind == VanaConversationKind.mealPlanning;

  /// Same default the picker carousel uses when the server sends none
  /// (`VanaMealPickerPart.defaultServings`).
  static const defaultServings = 4;

  @override
  ConsumerState<VanaBrowseScreen> createState() => _VanaBrowseScreenState();
}

class _VanaBrowseScreenState extends ConsumerState<VanaBrowseScreen> {
  /// Picks that landed this visit — ticked at once, before the plan watch
  /// re-emits. What is already in the plan comes from the plan itself
  /// ([conversationDraftProvider] for a planning chat,
  /// [mealPlanControllerProvider] for a general one), so a reopened Browse
  /// shows it ticked and never adds it again (testing-wave 18-003).
  final Set<String> _added = {};
  final Set<String> _inFlight = {};

  /// The conversation scope a pick carries: the planning chat's own draft,
  /// nothing for a general chat (the week's active plan, or a new draft).
  String? get _scope => widget.isPlanning ? widget.conversationId : null;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final plan = widget.isPlanning
        ? ref.watch(conversationDraftProvider(widget.conversationId)).value
        : ref.watch(mealPlanControllerProvider).value;
    final inPlan = plan?.meals
        .map((m) => m.libraryMealId ?? m.savedMealId)
        .nonNulls
        .toSet();
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
                    onTap: context.popOrHome,
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
                onRemoveMeal: _remove,
                addedIds: {..._added, ...?inPlan},
                surface: CatalogSurface.browse,
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
      '/food/meals/${meal.id}?pick=${widget.conversationId}'
      '&mode=${widget.kind.wire}',
    );
    if (added == true && mounted) setState(() => _added.add(meal.id));
  }

  Future<void> _add(MealRef meal) async {
    if (_inFlight.contains(meal.id) || _added.contains(meal.id)) return;
    final content = ref.read(contentServiceProvider);
    _inFlight.add(meal.id);
    try {
      final plan = await ref
          .read(mealPlanControllerProvider.notifier)
          .pickMeals(
            [MealPick(source: meal.source, id: meal.id)],
            servings: VanaBrowseScreen.defaultServings,
            conversationId: _scope,
          );
      _mirrorIntoChat(plan);
      if (!mounted) return;
      setState(() => _added.add(meal.id));
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpBrowseAddedToast),
        duration: MealvanaSnackbar.shortDuration,
      );
    } on Exception catch (e) {
      // Offline says so, whether refused before sending or cut off (88-013).
      if (mounted) showWriteFailure(context, content, e);
    } finally {
      _inFlight.remove(meal.id);
    }
  }

  /// A second tap on a ticked card: take the meal out again (`unpick_meal`,
  /// the same scope the pick used). The card un-ticks on the ack.
  Future<void> _remove(MealRef meal) async {
    if (_inFlight.contains(meal.id)) return;
    final content = ref.read(contentServiceProvider);
    _inFlight.add(meal.id);
    try {
      final plan = await ref
          .read(mealPlanControllerProvider.notifier)
          .unpickMeal(meal.source, meal.id, conversationId: _scope);
      _mirrorIntoChat(plan);
      if (!mounted) return;
      setState(() => _added.remove(meal.id));
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpBrowseRemovedToast),
        duration: MealvanaSnackbar.shortDuration,
      );
    } on Exception catch (e) {
      if (mounted) showWriteFailure(context, content, e);
    } finally {
      _inFlight.remove(meal.id);
    }
  }

  /// A planning chat's plan bar reads the draft off the chat state, which
  /// only the chat's own `refreshDraft` after Browse used to refill; a Browse
  /// opened another way (a link) left the bar at "0 meals" over a draft that
  /// held the pick (110-009). The plan the server answered goes straight
  /// into the chat controller when one is open for this conversation. A
  /// general chat's bar reads the plan controller, which the pick updated.
  void _mirrorIntoChat(MealPlan? plan) {
    if (plan == null || !widget.isPlanning) return;
    final chat = vanaChatControllerProvider(
      kind: widget.kind,
      conversationId: widget.conversationId,
    );
    if (ref.exists(chat)) ref.read(chat.notifier).applyDraftPlan(plan);
  }
}
