import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../application/shopping_list_controller.dart';
import '../screens/shopping_tab.dart' show shoppingListNameInWords;

/// Shares the list on screen as plain text, titled with the list's name
/// (110-011, Lee: "Week of Sep 20", "Race week extras"). Lives in the Food
/// screen's header beside the settings gear (2026-09-03 — moved from the
/// bottom of the list), so it renders its own share origin.
class ShoppingShareButton extends ConsumerWidget {
  const ShoppingShareButton({super.key});

  /// The share text's title and subject: the list's name in words, or the
  /// untitled fallback for a list with none (the offline copy).
  static String titleFor(ContentService content, ShoppingListState state) =>
      state.listName.isEmpty
      ? content.getValue(ContentKeys.mpShoppingListUntitled)
      : shoppingListNameInWords(content, state.listName);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final shareAction = content.getValue(ContentKeys.mpShoppingShareAction);

    return IconButton(
      key: const ValueKey('meal_planning.shopping_share'),
      onPressed: () {
        final state = ref.read(shoppingListControllerProvider).value;
        if (state == null || state.isEmpty) {
          _nothingToShare(context, content, offline: state?.isOffline ?? false);
          return;
        }
        final shareTitle = titleFor(content, state);
        // Counts what is left to buy, not what is ticked (89-002).
        final summary = ContentKeys.format(
          content.getValue(
            state.toBuyCount == 1
                ? ContentKeys.mpShoppingShareSummaryOne
                : ContentKeys.mpShoppingShareSummaryMany,
          ),
          {'items': state.toBuyCount},
        );
        final body = ref
            .read(shoppingListControllerProvider.notifier)
            .shareText(title: shareTitle, summary: summary);
        if (body.isEmpty) {
          _nothingToShare(context, content, offline: state.isOffline);
          return;
        }

        final box = context.findRenderObject();
        final origin = box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        SharePlus.instance.share(
          ShareParams(
            text: body,
            title: shareTitle,
            subject: shareTitle,
            sharePositionOrigin: origin,
          ),
        );
      },
      tooltip: shareAction,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        switch (Theme.of(context).platform) {
          TargetPlatform.iOS ||
          TargetPlatform.macOS => Icons.ios_share_outlined,
          _ => Icons.share_outlined,
        },
        size: 22,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cream
            : AppColors.blackberry,
      ),
    );
  }

  /// A tap with nothing to share says why, never nothing (89-001).
  static void _nothingToShare(
    BuildContext context,
    ContentService content, {
    required bool offline,
  }) => MealvanaSnackbar.showWarning(
    context,
    content.getValue(
      offline
          ? ContentKeys.mpShoppingShareOffline
          : ContentKeys.mpShoppingShareEmpty,
    ),
  );
}
