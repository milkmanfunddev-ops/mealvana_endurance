import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../shared/widgets/kyle_design/inputs/kyle_input_field.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/shopping_list_controller.dart';
import '../../domain/shopping_item.dart';
import '../../domain/shopping_list.dart';
import '../widgets/overflow_menu.dart';
import '../widgets/shopping_list.dart';
import '../../../kroger/application/kroger_availability.dart';

/// The Shop with Kroger button's height, also reserved while Coverage is
/// still being asked.
const _krogerButtonHeight = 44.0;

/// The Shopping tab (05 §4; 2026-09-16: several lists with hand edits, then
/// Lee's redesign). One list at a time: its name (tap to rename) and date on
/// the left, a `⋮` on the right with New list · Previous lists · Delete
/// list (and Back to current list on an earlier one). A plan's list
/// features the Kroger hand-off under the header. Lines end with one quiet
/// "Add an item" row that opens the same sheet as Edit. Sharing lives in the
/// Food screen's header via [ShoppingShareButton].
class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final listAsync = ref.watch(shoppingListControllerProvider);
    final state = listAsync.value;
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.imperial;
    final controller = ref.read(shoppingListControllerProvider.notifier);

    // The list lives server-side, so the first read is a round trip: say
    // loading, never "No shopping list" over a list that exists (16-003).
    if (state == null && listAsync.isLoading) return const _Loading();
    if (state == null || (state.isEmpty && !state.hasAnyList)) {
      return _EmptyState(
        onNewList: state == null ? null : () => _newList(context, ref),
      );
    }

    final listId = state.listId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ListHeader(
          state: state,
          onRename: listId == null
              ? null
              : () => _renameList(context, ref, listId, state.listName),
          onNewList: () => _newList(context, ref),
          onPrevious: () => _previousLists(context, ref, state),
          onBackToCurrent: () => _guard(context, ref, controller.openCurrent),
          onDelete: listId == null
              ? null
              : () => _deleteList(context, ref, listId),
        ),
        if (state.isOffline) ...[
          const SizedBox(height: AppSpacing.sm),
          const _OfflineNotice(),
        ],
        // Kroger needs the network; offline the hand-off is not offered.
        if (state.planId != null && !state.isOffline) ...[
          if (ref.watch(krogerEntryVisibleProvider)) ...[
            const SizedBox(height: AppSpacing.md),
            KylePrimaryButton(
              key: const ValueKey('meal_planning.kroger'),
              icon: Icons.shopping_cart_outlined,
              text: content.getValue(ContentKeys.krogerTitle),
              height: _krogerButtonHeight,
              // Into the Food tree, not onto a bare Navigator route:
              // the screen keeps the app's chrome and the Pro gate.
              onPressed: () => context.push('/food/kroger/${state.planId}'),
            ),
          ] else if (ref.watch(krogerEntryPendingProvider))
            // Coverage is still being asked: hold the button's room so the
            // rows do not move ~60 pt when it lands (20-003).
            const SizedBox(
              key: ValueKey('meal_planning.kroger_pending'),
              height: AppSpacing.md + _krogerButtonHeight,
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (state.isEmpty)
          Text(
            content.getValue(ContentKeys.mpShoppingListEmpty),
            key: const ValueKey('meal_planning.shopping_list_empty'),
            style: AppTextStyles.bodyMedium.copyWith(color: secondary),
          )
        else
          ShoppingList(
            state: state,
            // Awaited through _guard: a write the server refuses says so
            // (20-002). Offline the controller keeps the tick and never
            // throws, so no snackbar fires for a queued tick.
            onToggleChecked: (item, value) => _guard(
              context,
              ref,
              () => controller.setChecked(item.name, value),
            ),
            onAddBack: (name) =>
                _guard(context, ref, () => controller.setHave(name, false)),
            units: units,
            onOpenMeal: (meal) => context.push(
              '/food/meals/${meal.libraryMealId ?? meal.savedMealId ?? meal.id}',
            ),
            onEditItem: listId == null
                ? null
                : (item) => _editItem(context, ref, item),
            onDeleteItem: listId == null
                ? null
                : (item) => _guard(
                    context,
                    ref,
                    () => controller.deleteItem(item),
                    done: ContentKeys.format(
                      content.getValue(ContentKeys.mpShoppingRemoved),
                      {'name': item.name},
                    ),
                  ),
          ),
        if (listId != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _AddItemRow(onTap: () => _addItem(context, ref)),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Future<void> _newList(BuildContext context, WidgetRef ref) => _guard(
    context,
    ref,
    () => ref.read(shoppingListControllerProvider.notifier).newList(),
    done: ref
        .read(contentServiceProvider)
        .getValue(ContentKeys.mpShoppingNewListDone),
  );

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final result = await showAdaptiveModal<({String name, String qty})>(
      context: context,
      builder: (sheetContext) => const ShoppingEditSheet(),
    );
    if (result == null || !context.mounted) return;
    await _guard(
      context,
      ref,
      () => ref
          .read(shoppingListControllerProvider.notifier)
          .addItem(result.name, qty: result.qty),
      done: ContentKeys.format(
        ref.read(contentServiceProvider).getValue(ContentKeys.mpShoppingAdded),
        {'name': result.name},
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
  ) async {
    final result = await showAdaptiveModal<({String name, String qty})>(
      context: context,
      builder: (sheetContext) => ShoppingEditSheet(item: item),
    );
    if (result == null || !context.mounted) return;
    await _guard(
      context,
      ref,
      () => ref
          .read(shoppingListControllerProvider.notifier)
          .updateItem(item, name: result.name, qty: result.qty),
      done: ContentKeys.format(
        ref.read(contentServiceProvider).getValue(ContentKeys.mpShoppingSaved),
        {'name': result.name},
      ),
    );
  }

  Future<void> _renameList(
    BuildContext context,
    WidgetRef ref,
    String listId,
    String currentName,
  ) async {
    final name = await showAdaptiveModal<String>(
      context: context,
      builder: (sheetContext) => ShoppingRenameSheet(name: currentName),
    );
    if (name == null || !context.mounted) return;
    await _guard(
      context,
      ref,
      () => ref
          .read(shoppingListControllerProvider.notifier)
          .renameList(name, id: listId),
      done: ref
          .read(contentServiceProvider)
          .getValue(ContentKeys.mpShoppingListRenamed),
    );
  }

  /// Ask first, as the Plan tab does for a plan; nothing is sent on Keep it.
  Future<void> _deleteList(
    BuildContext context,
    WidgetRef ref,
    String listId,
  ) async {
    final content = ref.read(contentServiceProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('meal_planning.shopping_delete_confirm'),
        backgroundColor: Theme.of(dialogContext).scaffoldBackgroundColor,
        title: Text(content.getValue(ContentKeys.mpShoppingDeleteListTitle)),
        content: Text(content.getValue(ContentKeys.mpShoppingDeleteListBody)),
        actions: [
          TextButton(
            key: const ValueKey('meal_planning.shopping_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              content.getValue(ContentKeys.mpShoppingDeleteListCancel),
            ),
          ),
          TextButton(
            key: const ValueKey('meal_planning.shopping_delete_go'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              content.getValue(ContentKeys.mpShoppingDeleteListConfirm),
              style: const TextStyle(color: AppColors.dragonfruitLight),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _guard(
      context,
      ref,
      () =>
          ref.read(shoppingListControllerProvider.notifier).deleteList(listId),
      done: content.getValue(ContentKeys.mpShoppingListDeleted),
    );
  }

  Future<void> _previousLists(
    BuildContext context,
    WidgetRef ref,
    ShoppingListState state,
  ) async {
    final choice = await showAdaptiveModal<ShoppingListChoice>(
      context: context,
      builder: (sheetContext) => ShoppingPreviousListsSheet(
        lists: state.allLists,
        currentId: state.listId,
      ),
    );
    if (choice == null || !context.mounted) return;
    final list = choice.list;
    switch (choice.action) {
      case ShoppingListChoiceAction.open:
        if (list.id == state.listId) return;
        await _guard(
          context,
          ref,
          () => ref
              .read(shoppingListControllerProvider.notifier)
              .openList(list.id),
        );
      case ShoppingListChoiceAction.rename:
        await _renameList(context, ref, list.id, list.name);
      case ShoppingListChoiceAction.delete:
        await _deleteList(context, ref, list.id);
    }
  }

  /// Run one list write; say so when it lands, say so when it fails.
  static Future<void> _guard(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() work, {
    String? done,
  }) async {
    try {
      await work();
      if (done != null && context.mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          done,
          duration: MealvanaSnackbar.shortDuration,
        );
      }
    } catch (_) {
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          ref
              .read(contentServiceProvider)
              .getValue(ContentKeys.mpShoppingFailed),
        );
      }
    }
  }
}

extension on ShoppingListState {
  /// Every list the athlete has — the one on screen included — most recent
  /// first, for the previous-lists sheet.
  List<ShoppingListSummary> get allLists {
    final id = listId;
    final open = id == null
        ? null
        : ShoppingListSummary(
            id: id,
            planId: planId,
            name: listName,
            createdAt: listDate ?? DateTime.now(),
            updatedAt: listDate ?? DateTime.now(),
            confirmedAt: isConfirmed ? listDate : null,
            itemCount: itemCount,
          );
    return [...previous, if (open != null) open]
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
  }
}

/// No list anywhere yet: the plan builds one on confirm, or start one by
/// hand.
/// The first read is on the wire. A spinner, no words: the tab must not
/// read as empty until the server has answered.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('meal_planning.shopping_loading'),
    child: CircularProgressIndicator(color: AppColors.electrolyte),
  );
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onNewList});

  final VoidCallback? onNewList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            content.getValue(ContentKeys.mpShoppingEmptyTitle),
            key: const ValueKey('meal_planning.shopping_empty'),
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              content.getValue(ContentKeys.mpShoppingEmptyBody),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ),
          if (onNewList != null) ...[
            const SizedBox(height: AppSpacing.md),
            KyleSecondaryButtonSmall(
              key: const ValueKey('meal_planning.shopping_new_list'),
              icon: Icons.add,
              text: content.getValue(ContentKeys.mpShoppingNewList),
              onPressed: onNewList,
            ),
          ],
        ],
      ),
    );
  }
}

/// The list's name (tap to rename) and date on the left; the list menu on
/// the right. An earlier list says so on the date line.
class _ListHeader extends ConsumerWidget {
  const _ListHeader({
    required this.state,
    required this.onRename,
    required this.onNewList,
    required this.onPrevious,
    required this.onBackToCurrent,
    required this.onDelete,
  });

  final ShoppingListState state;
  final VoidCallback? onRename;
  final VoidCallback onNewList;
  final VoidCallback onPrevious;
  final VoidCallback onBackToCurrent;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);

    final name = state.listName.isEmpty
        ? content.getValue(ContentKeys.mpShoppingListUntitled)
        : state.listName;
    final date = state.listDate;
    final subLine = [
      if (date != null)
        ContentKeys.format(
          content.getValue(
            state.isConfirmed
                ? ContentKeys.mpShoppingConfirmedOn
                : ContentKeys.mpShoppingCreatedOn,
          ),
          {'date': DateFormat.yMMMd().format(date.toLocal())},
        ),
      if (!state.isCurrent)
        content.getValue(ContentKeys.mpShoppingViewingPrior),
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                key: const ValueKey('meal_planning.shopping_list_name'),
                behavior: HitTestBehavior.opaque,
                onTap: onRename,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subLine,
                  key: const ValueKey('meal_planning.shopping_list_date'),
                  style: AppTextStyles.bodySmall.copyWith(color: secondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OverflowMenu(
          key: const ValueKey('meal_planning.shopping_menu'),
          tooltip: content.getValue(ContentKeys.mpShoppingMenuMore),
          items: [
            OverflowMenuItem(
              key: const ValueKey('meal_planning.shopping_new_list'),
              label: content.getValue(ContentKeys.mpShoppingNewList),
              onSelected: onNewList,
            ),
            OverflowMenuItem(
              key: const ValueKey('meal_planning.shopping_previous'),
              label: content.getValue(ContentKeys.mpShoppingPrevious),
              onSelected: onPrevious,
            ),
            if (!state.isCurrent)
              OverflowMenuItem(
                key: const ValueKey('meal_planning.shopping_back_to_current'),
                label: content.getValue(ContentKeys.mpShoppingBackToCurrent),
                onSelected: onBackToCurrent,
              ),
            if (onDelete != null)
              OverflowMenuItem(
                key: const ValueKey('meal_planning.shopping_delete_list'),
                label: content.getValue(ContentKeys.mpShoppingDeleteList),
                destructive: true,
                onSelected: onDelete!,
              ),
          ],
        ),
      ],
    );
  }
}

/// The tab's offline notice (ticket 36): a quiet tinted strip under the
/// header saying ticks are kept on the phone and sent when the network is
/// back. Shown for the plan's offline copy and for the live list once a
/// tick could not be sent.
class _OfflineNotice extends ConsumerWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.7);
    return Container(
      key: const ValueKey('meal_planning.shopping_offline'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              content.getValue(ContentKeys.mpShoppingOffline),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ghost row at the end of the list: a plus and "Add an item" in
/// secondary text, the height of a list row, no card behind it.
class _AddItemRow extends ConsumerWidget {
  const _AddItemRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    return InkWell(
      key: const ValueKey('meal_planning.shopping_add_item'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.add, size: 20, color: secondary),
            const SizedBox(width: 12),
            Text(
              content.getValue(ContentKeys.mpShoppingAddTitle),
              style: AppTextStyles.bodyMedium.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name and amount for one line. With an [item], edits it; without one,
/// adds a new line. Pops `(name, qty)` on Save / Add, null on dismiss.
class ShoppingEditSheet extends ConsumerStatefulWidget {
  const ShoppingEditSheet({super.key, this.item});

  final ShoppingItem? item;

  bool get isAdd => item == null;

  @override
  ConsumerState<ShoppingEditSheet> createState() => _ShoppingEditSheetState();
}

class _ShoppingEditSheetState extends ConsumerState<ShoppingEditSheet> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _qty = TextEditingController(text: widget.item?.qty ?? '');

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, qty: _qty.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final mode = widget.isAdd ? 'add' : 'edit';
    return _Sheet(
      key: ValueKey('meal_planning.shopping_${mode}_sheet'),
      title: content.getValue(
        widget.isAdd
            ? ContentKeys.mpShoppingAddTitle
            : ContentKeys.mpShoppingEditTitle,
      ),
      children: [
        KyleInputField(
          key: ValueKey('meal_planning.shopping_${mode}_name'),
          controller: _name,
          hintText: content.getValue(ContentKeys.mpShoppingAddNameHint),
          textInputAction: TextInputAction.next,
          autofocus: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        KyleInputField(
          key: ValueKey('meal_planning.shopping_${mode}_qty'),
          controller: _qty,
          hintText: content.getValue(ContentKeys.mpShoppingAddQtyHint),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.md),
        KylePrimaryButton(
          key: ValueKey(
            widget.isAdd
                ? 'meal_planning.shopping_add_submit'
                : 'meal_planning.shopping_edit_save',
          ),
          text: content.getValue(
            widget.isAdd
                ? ContentKeys.mpShoppingAddAction
                : ContentKeys.mpShoppingSaveAction,
          ),
          onPressed: _save,
        ),
      ],
    );
  }
}

/// Rename a list. Pops the new name on Save, null on dismiss.
class ShoppingRenameSheet extends ConsumerStatefulWidget {
  const ShoppingRenameSheet({super.key, required this.name});

  final String name;

  @override
  ConsumerState<ShoppingRenameSheet> createState() =>
      _ShoppingRenameSheetState();
}

class _ShoppingRenameSheetState extends ConsumerState<ShoppingRenameSheet> {
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    return _Sheet(
      key: const ValueKey('meal_planning.shopping_rename_sheet'),
      title: content.getValue(ContentKeys.mpShoppingRenameTitle),
      children: [
        KyleInputField(
          key: const ValueKey('meal_planning.shopping_rename_name'),
          controller: _name,
          hintText: content.getValue(ContentKeys.mpShoppingRenameHint),
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.md),
        KylePrimaryButton(
          key: const ValueKey('meal_planning.shopping_rename_save'),
          text: content.getValue(ContentKeys.mpShoppingSaveAction),
          onPressed: _save,
        ),
      ],
    );
  }
}

/// What the previous-lists sheet pops: open, rename or delete one list.
enum ShoppingListChoiceAction { open, rename, delete }

typedef ShoppingListChoice = ({
  ShoppingListChoiceAction action,
  ShoppingListSummary list,
});

/// Every list, newest first: name, date and item count, a "From plan"
/// marker on a plan's list, a `⋮` with Rename and Delete. Tapping a row
/// opens it; the one on screen is marked and just closes the sheet.
class ShoppingPreviousListsSheet extends ConsumerWidget {
  const ShoppingPreviousListsSheet({
    super.key,
    required this.lists,
    required this.currentId,
  });

  final List<ShoppingListSummary> lists;
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final hairline = textColor.withValues(alpha: 0.1);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final untitled = content.getValue(ContentKeys.mpShoppingListUntitled);

    void pop(ShoppingListChoiceAction action, ShoppingListSummary list) =>
        Navigator.of(context).pop((action: action, list: list));

    return _Sheet(
      key: const ValueKey('meal_planning.shopping_previous_sheet'),
      title: content.getValue(ContentKeys.mpShoppingPrevious),
      children: [
        if (lists.isEmpty)
          Text(
            content.getValue(ContentKeys.mpShoppingPreviousEmpty),
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          )
        else
          Container(
            padding: const EdgeInsets.only(left: 16, right: 4),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                for (var i = 0; i < lists.length; i++)
                  InkWell(
                    key: ValueKey(
                      'meal_planning.shopping_previous_${lists[i].id}',
                    ),
                    onTap: () => pop(ShoppingListChoiceAction.open, lists[i]),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      decoration: BoxDecoration(
                        border: i == lists.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: hairline)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        lists[i].name.isEmpty
                                            ? untitled
                                            : lists[i].name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: lists[i].id == currentId
                                                  ? accent
                                                  : textColor,
                                              fontWeight:
                                                  lists[i].id == currentId
                                                  ? FontWeight.w600
                                                  : null,
                                            ),
                                      ),
                                    ),
                                    if (lists[i].planId != null) ...[
                                      const SizedBox(width: 8),
                                      _Marker(
                                        key: ValueKey(
                                          'meal_planning.shopping_from_plan_${lists[i].id}',
                                        ),
                                        text: content.getValue(
                                          ContentKeys.mpShoppingFromPlan,
                                        ),
                                        color: secondary,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    DateFormat.yMMMd().format(
                                      lists[i].sortDate.toLocal(),
                                    ),
                                    ContentKeys.format(
                                      content.getValue(
                                        ContentKeys.mpShoppingItemCount,
                                      ),
                                      {'n': lists[i].itemCount},
                                    ),
                                    if (lists[i].id == currentId)
                                      content.getValue(
                                        ContentKeys.mpShoppingPreviousCurrent,
                                      ),
                                  ].join(' · '),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OverflowMenu(
                            key: ValueKey(
                              'meal_planning.shopping_previous_menu_${lists[i].id}',
                            ),
                            tooltip: content.getValue(
                              ContentKeys.mpShoppingMenuMore,
                            ),
                            items: [
                              OverflowMenuItem(
                                key: ValueKey(
                                  'meal_planning.shopping_previous_rename_${lists[i].id}',
                                ),
                                label: content.getValue(
                                  ContentKeys.mpShoppingRenameAction,
                                ),
                                onSelected: () => pop(
                                  ShoppingListChoiceAction.rename,
                                  lists[i],
                                ),
                              ),
                              OverflowMenuItem(
                                key: ValueKey(
                                  'meal_planning.shopping_previous_delete_${lists[i].id}',
                                ),
                                label: content.getValue(
                                  ContentKeys.mpShoppingDeleteAction,
                                ),
                                destructive: true,
                                onSelected: () => pop(
                                  ShoppingListChoiceAction.delete,
                                  lists[i],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A quiet pill for "From plan": secondary text on a 12% tint, like the
/// count badge on a list row.
class _Marker extends StatelessWidget {
  const _Marker({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1,
          color: color,
        ),
      ),
    );
  }
}

/// The tab's sheets share one frame: a title, then the body, padded and
/// lifted above the keyboard.
class _Sheet extends StatelessWidget {
  const _Sheet({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
