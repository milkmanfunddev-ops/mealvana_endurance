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
import '../widgets/shopping_list.dart';
import '../../../kroger/application/kroger_availability.dart';

/// The Shopping tab (05 §4, and 2026-09-16: several lists with hand edits).
/// The most recent list sits on top with its name and date; a hand-written
/// line goes in through the add row; each row's menu edits or deletes it;
/// "New list" starts a fresh one; "Previous lists" opens an earlier list,
/// still checkable. Sharing lives in the Food screen's header via
/// [ShoppingShareButton]. Kroger's reviewed cart handoff is separately
/// release-gated; checkout stays in Kroger.
class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final state = ref.watch(shoppingListControllerProvider).value;
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.imperial;
    final controller = ref.read(shoppingListControllerProvider.notifier);

    if (state == null || (state.isEmpty && !state.hasAnyList)) {
      return _EmptyState(
        onNewList: state == null ? null : () => _newList(context, ref),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ListHeader(
          state: state,
          onNewList: () => _newList(context, ref),
          onBackToCurrent: () => _guard(context, ref, controller.openCurrent),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.planId != null && ref.watch(krogerEntryVisibleProvider)) ...[
          Align(
            alignment: Alignment.centerRight,
            child: KyleSecondaryButtonSmall(
              key: const ValueKey('meal_planning.kroger'),
              icon: Icons.shopping_cart_outlined,
              text: content.getValue(ContentKeys.krogerTitle),
              // Into the Food tree, not onto a bare Navigator route:
              // the screen keeps the app's chrome and the Pro gate.
              onPressed: () => context.push('/food/kroger/${state.planId}'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (state.listId != null) ...[
          ShoppingAddRow(
            onAdd: (name, qty) => _guard(
              context,
              ref,
              () => controller.addItem(name, qty: qty),
              done: ContentKeys.format(
                content.getValue(ContentKeys.mpShoppingAdded),
                {'name': name},
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ShoppingList(
          state: state,
          onToggleChecked: (item, value) =>
              controller.setChecked(item.name, value),
          onAddBack: (name) => controller.setHave(name, false),
          units: units,
          onOpenMeal: (meal) => context.push(
            '/food/meals/${meal.libraryMealId ?? meal.savedMealId ?? meal.id}',
          ),
          onEditItem: state.listId == null
              ? null
              : (item) => _editItem(context, ref, item),
          onDeleteItem: state.listId == null
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
        const SizedBox(height: AppSpacing.md),
        ShoppingPreviousLists(
          lists: state.previous,
          onOpen: (list) =>
              _guard(context, ref, () => controller.openList(list.id)),
        ),
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

/// No list anywhere yet: the plan builds one on confirm, or start one by
/// hand.
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

/// The list's name and date, "New list" beside it, and — on an earlier
/// list — the way back to the current one.
class _ListHeader extends ConsumerWidget {
  const _ListHeader({
    required this.state,
    required this.onNewList,
    required this.onBackToCurrent,
  });

  final ShoppingListState state;
  final VoidCallback onNewList;
  final VoidCallback onBackToCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    final name = state.listName.isEmpty
        ? content.getValue(ContentKeys.mpShoppingListUntitled)
        : state.listName;
    final date = state.listDate;
    final dateLine = date == null
        ? null
        : ContentKeys.format(
            content.getValue(
              state.isConfirmed
                  ? ContentKeys.mpShoppingConfirmedOn
                  : ContentKeys.mpShoppingCreatedOn,
            ),
            {'date': DateFormat.yMMMd().format(date.toLocal())},
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    key: const ValueKey('meal_planning.shopping_list_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (dateLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateLine,
                      style: AppTextStyles.bodySmall.copyWith(color: secondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            KyleSecondaryButtonSmall(
              key: const ValueKey('meal_planning.shopping_new_list'),
              icon: Icons.add,
              text: content.getValue(ContentKeys.mpShoppingNewList),
              onPressed: onNewList,
            ),
          ],
        ),
        if (!state.isCurrent) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                content.getValue(ContentKeys.mpShoppingViewingPrior),
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                key: const ValueKey('meal_planning.shopping_back_to_current'),
                onTap: onBackToCurrent,
                child: Text(
                  content.getValue(ContentKeys.mpShoppingBackToCurrent),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Name · qty · Add. Submitting either field adds; the fields clear on
/// success so the next line can go straight in.
class ShoppingAddRow extends ConsumerStatefulWidget {
  const ShoppingAddRow({super.key, required this.onAdd});

  final Future<void> Function(String name, String qty) onAdd;

  @override
  ConsumerState<ShoppingAddRow> createState() => _ShoppingAddRowState();
}

class _ShoppingAddRowState extends ConsumerState<ShoppingAddRow> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAdd(name, _qty.text.trim());
      _name.clear();
      _qty.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: KyleInputField(
            key: const ValueKey('meal_planning.shopping_add_name'),
            controller: _name,
            hintText: content.getValue(ContentKeys.mpShoppingAddNameHint),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          flex: 2,
          child: KyleInputField(
            key: const ValueKey('meal_planning.shopping_add_qty'),
            controller: _qty,
            hintText: content.getValue(ContentKeys.mpShoppingAddQtyHint),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        KyleSecondaryButtonSmall(
          key: const ValueKey('meal_planning.shopping_add_submit'),
          text: content.getValue(ContentKeys.mpShoppingAddAction),
          isLoading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}

/// Edit one line's name and amount. Pops `(name, qty)` on Save, null on
/// dismiss.
class ShoppingEditSheet extends ConsumerStatefulWidget {
  const ShoppingEditSheet({super.key, required this.item});

  final ShoppingItem item;

  @override
  ConsumerState<ShoppingEditSheet> createState() => _ShoppingEditSheetState();
}

class _ShoppingEditSheetState extends ConsumerState<ShoppingEditSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _qty = TextEditingController(text: widget.item.qty);

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
          key: const ValueKey('meal_planning.shopping_edit_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.getValue(ContentKeys.mpShoppingEditTitle),
              style: AppTextStyles.sectionTitle.copyWith(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            KyleInputField(
              key: const ValueKey('meal_planning.shopping_edit_name'),
              controller: _name,
              hintText: content.getValue(ContentKeys.mpShoppingAddNameHint),
              textInputAction: TextInputAction.next,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            KyleInputField(
              key: const ValueKey('meal_planning.shopping_edit_qty'),
              controller: _qty,
              hintText: content.getValue(ContentKeys.mpShoppingAddQtyHint),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            KylePrimaryButton(
              key: const ValueKey('meal_planning.shopping_edit_save'),
              text: content.getValue(ContentKeys.mpShoppingSaveAction),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Previous lists", collapsed; opens to one row per earlier list, newest
/// first, each naming the list, its date and its open-item count.
class ShoppingPreviousLists extends ConsumerStatefulWidget {
  const ShoppingPreviousLists({
    super.key,
    required this.lists,
    required this.onOpen,
  });

  final List<ShoppingListSummary> lists;
  final ValueChanged<ShoppingListSummary> onOpen;

  @override
  ConsumerState<ShoppingPreviousLists> createState() =>
      _ShoppingPreviousListsState();
}

class _ShoppingPreviousListsState extends ConsumerState<ShoppingPreviousLists> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final hairline = textColor.withValues(alpha: 0.1);
    final untitled = content.getValue(ContentKeys.mpShoppingListUntitled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('meal_planning.shopping_previous'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Text(
                content.getValue(ContentKeys.mpShoppingPrevious).toUpperCase(),
                style: AppTextStyles.overline.copyWith(color: secondary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: secondary,
              ),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: AppSpacing.xs),
          if (widget.lists.isEmpty)
            Text(
              content.getValue(ContentKeys.mpShoppingPreviousEmpty),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < widget.lists.length; i++)
                    InkWell(
                      key: ValueKey(
                        'meal_planning.shopping_previous_${widget.lists[i].id}',
                      ),
                      onTap: () => widget.onOpen(widget.lists[i]),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          border: i == widget.lists.length - 1
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
                                  Text(
                                    widget.lists[i].name.isEmpty
                                        ? untitled
                                        : widget.lists[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat.yMMMd().format(widget.lists[i].sortDate.toLocal())} · '
                                    '${ContentKeys.format(content.getValue(ContentKeys.mpShoppingItemCount), {'n': widget.lists[i].itemCount})}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
