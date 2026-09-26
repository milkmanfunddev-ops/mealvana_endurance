import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/shopping_list_controller.dart';
import '../../application/youre_set_controller.dart';
import '../../domain/vana_part.dart';
import 'confirmed_card.dart';
import 'week_card.dart';
import 'write_failure_snackbar.dart';

/// The "you're set" card at the top of Food > Shopping after a confirm
/// (mp-235, ticket 131), then the week once it is laid across.
///
/// Draws only over the list of the plan just confirmed
/// ([youreSetControllerProvider]); nothing otherwise. Closing it clears it
/// for good; the Food screen clears it when its segment leaves Shopping or
/// the shell leaves the Food tab.
class YoureSetOnShopping extends ConsumerStatefulWidget {
  const YoureSetOnShopping({
    super.key,
    required this.list,
    required this.onShowPlan,
  });

  /// The list on screen: the card sizes itself from it.
  final ShoppingListState list;

  /// Switch the Food screen to its Plan segment.
  final VoidCallback onShowPlan;

  @override
  ConsumerState<YoureSetOnShopping> createState() => _YoureSetOnShoppingState();
}

class _YoureSetOnShoppingState extends ConsumerState<YoureSetOnShopping> {
  void _dismiss() => ref.read(youreSetControllerProvider.notifier).dismiss();

  Future<void> _layAcross() async {
    try {
      await ref.read(youreSetControllerProvider.notifier).layAcrossWeek();
    } on Exception catch (e) {
      if (!mounted) return;
      showWriteFailure(context, ref.read(contentServiceProvider), e);
    }
  }

  /// Adjust: back to Vana about this plan, in the conversation that built
  /// it, or a planning conversation when it was confirmed off the chat.
  void _adjust() {
    final conversationId = ref
        .read(mealPlanControllerProvider)
        .value
        ?.conversationId;
    _dismiss();
    context.push(
      conversationId == null
          ? '/vana?c=new&mode=meal_planning'
          : '/vana?c=$conversationId&mode=meal_planning',
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(youreSetControllerProvider).value;
    if (card == null || card.planId != widget.list.planId) {
      return const SizedBox.shrink();
    }
    final week = card.week;

    return Column(
      key: const ValueKey('meal_planning.youre_set_on_shopping'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConfirmedCard(
          part: VanaShoppingListPart.fromItems(widget.list.items),
          onViewPlan: widget.onShowPlan,
          onDismiss: _dismiss,
          onLayAcross: _layAcross,
          laidAcross: week != null,
          onAdjust: _adjust,
        ),
        if (week != null) ...[
          const SizedBox(height: AppSpacing.sm),
          WeekCard(part: week, onOpenPlan: widget.onShowPlan),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
