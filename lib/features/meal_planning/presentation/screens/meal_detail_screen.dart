import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_detail_controller.dart';
import '../../application/meal_plan_controller.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/directions_origin.dart';
import '../../domain/meal_detail.dart';
import '../../domain/meal_source.dart';
import '../../domain/ui_action.dart';
import '../widgets/choice_chip_button.dart';
import '../widgets/servings_sheet.dart';
import '../widgets/dashed_box.dart';
import '../widgets/vana_round_button.dart';
import '../widgets/vana_tag.dart';
import 'vana_browse_screen.dart';

/// `/food/meals/:id` (05 §4), minimal layout: hero, title + "see the
/// original recipe", thumbs · prep row, macro pills, ingredients,
/// directions (AI badge only), saved-meal notes, swaps as plain tips.
/// `?swap=<planMealId>` turns the primary action into "Swap in" + servings
/// stepper (remote-ack `swap_meal`); `?pick=<conversationId>` (from the
/// Vana browse screen) adds "Add to plan" into that conversation's draft
/// (remote-ack `pick_meals`) and pops `true` when it lands.
class MealDetailScreen extends ConsumerStatefulWidget {
  const MealDetailScreen({
    super.key,
    required this.id,
    this.swapPlanMealId,
    this.pickConversationId,
  });

  final String id;

  /// `plan_meals.id` when opened from the swap flow.
  final String? swapPlanMealId;

  /// The conversation whose draft "Add to plan" writes into, when opened
  /// from `/vana/browse`.
  final String? pickConversationId;

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final detail = ref.read(mealDetailControllerProvider(widget.id)).value;
    _notesController = TextEditingController(text: detail?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(mealDetailControllerProvider(widget.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;

    return Scaffold(
      key: ValueKey('meal_planning.detail_${widget.id}'),
      backgroundColor: bg,
      body: SafeArea(
        child: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => _LoadError(
          onRetry: () =>
              ref.invalidate(mealDetailControllerProvider(widget.id)),
        ),
        data: (detail) => _DetailBody(
          detail: detail,
          swapPlanMealId: widget.swapPlanMealId,
          pickConversationId: widget.pickConversationId,
          notesController: _notesController,
        ),
      ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({
    required this.detail,
    required this.swapPlanMealId,
    required this.pickConversationId,
    required this.notesController,
  });

  final MealDetail detail;
  final String? swapPlanMealId;
  final String? pickConversationId;
  final TextEditingController notesController;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  /// Swaps revealed under the ingredients (the ⇄ on the section label).
  bool _swapsOpen = false;

  /// Editing the saved meal's own directions.
  bool _editingNotes = false;

  MealDetail get detail => widget.detail;
  String? get swapPlanMealId => widget.swapPlanMealId;
  String? get pickConversationId => widget.pickConversationId;
  TextEditingController get notesController => widget.notesController;

  /// "Add to plan" is in flight — the button spins, no double-tap.
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final meal = detail.meal;
    final isSaved = meal.source == MealSource.saved;

    String cap(String v) =>
        v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

    // Prep falls back to prepMinutes — the library's `prep` string is
    // nullable and many rows only carry the number.
    final prep = detail.prep?.isNotEmpty == true
        ? detail.prep!
        : meal.prepMinutes != null
              ? '${meal.prepMinutes} min'
              : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        // ── Header: back · Save to mine ───────────────────────────────────
        Row(
          children: [
            VanaRoundButton.back(context: context, onTap: () => context.pop()),
            const Spacer(),
            if (!isSaved) _SaveToMineButton(mealId: meal.id),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (detail.image?.url != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                detail.image!.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          if (detail.image!.credit != null &&
              detail.image!.credit!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Photo: ${detail.image!.credit}',
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],

        Text(
          meal.name,
          style: AppTextStyles.sectionTitle.copyWith(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // ── Attribution: see the original recipe · host ───────────────────
        if (detail.directions.sourceUrl != null ||
            (detail.sourceUrl?.isNotEmpty ?? false)) ...[
          _OriginalRecipeLink(
            url: detail.directions.sourceUrl ?? detail.sourceUrl!,
            label: content.getValue(ContentKeys.mpDetailSeeOriginal),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Thumbs · prep ─────────────────────────────────────────────────
        Row(
          children: [
            _ThumbButton(
              key: const ValueKey('meal_planning.detail_thumb_up'),
              icon: FontAwesomeIcons.thumbsUp,
              active: detail.vote == 1,
              onTap: () => ref
                  .read(mealDetailControllerProvider(meal.id).notifier)
                  .vote(1),
            ),
            const SizedBox(width: AppSpacing.xs),
            _ThumbButton(
              key: const ValueKey('meal_planning.detail_thumb_down'),
              icon: FontAwesomeIcons.thumbsDown,
              active: detail.vote == -1,
              onTap: () => ref
                  .read(mealDetailControllerProvider(meal.id).notifier)
                  .vote(-1),
            ),
            const Spacer(),
            if (prep != null) VanaTag(label: prep),
          ],
        ),
        if (detail.vote == -1) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            content.getValue(ContentKeys.mpDetailThumbsDownNote),
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          ),
        ],

        // ── Macro pills (kcal · C · P · F as the server sent them) ────────
        Builder(
          builder: (context) {
            final macros = MacroPillRow(
              kcal: meal.kcal,
              carbsG: meal.carbsG,
              proteinG: meal.proteinG,
              fatG: meal.fatG,
            );
            if (macros.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: macros,
            );
          },
        ),

        // ── Ingredients (swaps hidden behind the ⇄ icon on the label) ──────
        if (detail.ingredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SectionLabel(
                  content.getValue(ContentKeys.mpDetailIngredients),
                ),
              ),
              if (detail.swaps.isNotEmpty)
                _SwapsToggle(
                  open: _swapsOpen,
                  tooltip: content.getValue(ContentKeys.mpDetailSwapsTitle),
                  onTap: () => setState(() => _swapsOpen = !_swapsOpen),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _ListCard(
            rows: [
              for (final ingredient in detail.ingredients)
                _ListRow(
                  height: 40,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cap(ingredient.name),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: textColor,
                          ),
                        ),
                      ),
                      if (ingredient.qty.isNotEmpty)
                        Text(
                          ingredient.qty,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: secondary,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (_swapsOpen) ...[
            const SizedBox(height: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final swap in detail.swaps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: Text(
                      swap,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: secondary,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],

        // ── Directions ────────────────────────────────────────────────────
        if (detail.methodSteps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _SectionLabel(
                  content.getValue(ContentKeys.mpDetailDirections),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _OriginBadge(origin: detail.directions.origin),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _ListCard(
            rows: [
              for (final (i, step) in detail.methodSteps.indexed)
                _ListRow(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 16,
                        child: Text(
                          '${i + 1}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: textColor,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          KylePrimaryButton(
            key: const ValueKey('meal_planning.detail_start_cooking'),
            text: content.getValue(ContentKeys.mpDetailStartCooking),
            icon: Icons.local_fire_department_outlined,
            height: 48,
            onPressed: () => context.push('/food/cook/${meal.id}'),
          ),
        ],

        // ── Your directions (saved meals) ─────────────────────────────────
        if (isSaved) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(
            content.getValue(ContentKeys.mpDetailYourDirections),
          ),
          const SizedBox(height: AppSpacing.xs),
          _YourDirections(
            editing: _editingNotes,
            notes: detail.notes,
            controller: notesController,
            onStartEditing: () {
              notesController.text = detail.notes ?? '';
              setState(() => _editingNotes = true);
            },
            onCancel: () => setState(() => _editingNotes = false),
            onSave: () async {
              await ref
                  .read(mealDetailControllerProvider(meal.id).notifier)
                  .setNotes(notesController.text);
              if (!context.mounted) return;
              setState(() => _editingNotes = false);
              MealvanaSnackbar.showSuccess(
                context,
                content.getValue(ContentKeys.mpDetailDirectionsSaved),
              );
            },
          ),
        ],

        // ── Primary action ────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.md),
        if (swapPlanMealId != null)
          KylePrimaryButton(
            key: const ValueKey('meal_planning.detail_swap_in'),
            text: content.getValue(ContentKeys.mpBtnSwapIn),
            height: 48,
            onPressed: () => _swapIn(context, ref),
          )
        else if (pickConversationId != null)
          KylePrimaryButton(
            key: const ValueKey('meal_planning.detail_add_to_plan'),
            text: content.getValue(ContentKeys.mpDetailAddToPlan),
            icon: Icons.add,
            height: 48,
            isLoading: _adding,
            onPressed: () => _addToPlan(context, ref),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  /// "Add to plan" from the browse flow: pick into the conversation's draft
  /// at the picker's default servings, toast, and pop `true` so the browse
  /// screen ticks the card.
  Future<void> _addToPlan(BuildContext context, WidgetRef ref) async {
    if (_adding) return;
    final content = ref.read(contentServiceProvider);
    setState(() => _adding = true);
    try {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .pickMeals(
            [MealPick(source: detail.meal.source, id: detail.meal.id)],
            servings: VanaBrowseScreen.defaultServings,
            conversationId: pickConversationId,
          );
      if (!context.mounted) return;
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpBrowseAddedToast),
        duration: MealvanaSnackbar.shortDuration,
      );
      context.pop(true);
    } on NeedsConnectionException {
      if (context.mounted) {
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(ContentKeys.mpNeedsConnection),
        );
      }
    } on Exception {
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpServerError),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _swapIn(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    final controller = ref.read(mealPlanControllerProvider.notifier);
    final servings = await showServingsSheet(
      context: context,
      ref: ref,
      meal: detail.meal,
    );
    if (servings == null || !context.mounted) return;
    try {
      await controller.swapMeal(
        swapPlanMealId!,
        source: detail.meal.source,
        id: detail.meal.id,
      );
      if (servings != detail.servings) {
        // The server's swap_meal UPDATES the plan_meals row IN PLACE
        // (_shared/vana/plan.ts swapMeal), so the swapped meal keeps this
        // exact id — adjust it directly. (The 4c cut name-matched the
        // refreshed plan here on the wrong assumption that swapping created
        // a new row; two same-named meals in a plan made that ambiguous.)
        await controller.setServings(swapPlanMealId!, servings);
      }
      if (context.mounted) context.pop();
    } on NeedsConnectionException {
      if (context.mounted) {
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(ContentKeys.mpNeedsConnection),
        );
      }
    } on Exception {
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpServerError),
        );
      }
    }
  }
}

/// One of the like / not-for-me pair — a circular icon button that fills
/// solid once it is the standing vote.
class _ThumbButton extends StatelessWidget {
  const _ThumbButton({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final FaIconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final foreground = active ? AppColors.blackberry : accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active
              ? accent
              : accent.withValues(alpha: isDark ? 0.1 : 0.07),
          border: Border.all(color: accent.withValues(alpha: active ? 1 : 0.6)),
          shape: BoxShape.circle,
        ),
        child: Center(child: FaIcon(icon, size: 18, color: foreground)),
      ),
    );
  }
}

/// The header heart — a circular icon button that fills (dragonfruit) once
/// the meal is saved to mine. Same surface/shape as [VanaRoundButton].
class _SaveToMineButton extends ConsumerStatefulWidget {
  const _SaveToMineButton({required this.mealId});

  final String mealId;

  @override
  ConsumerState<_SaveToMineButton> createState() => _SaveToMineButtonState();
}

class _SaveToMineButtonState extends ConsumerState<_SaveToMineButton> {
  bool _saved = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Tooltip(
      message: content.getValue(ContentKeys.mpDetailSaveToMine),
      child: Material(
        color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey('meal_planning.detail_save_to_mine'),
          onTap: _saved || _busy ? null : _save,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: FaIcon(
                _saved ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                size: 18,
                color: _saved ? AppColors.dragonfruit : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final content = ref.read(contentServiceProvider);
    setState(() => _busy = true);
    try {
      await ref
          .read(mealDetailControllerProvider(widget.mealId).notifier)
          .saveToMine();
      if (!mounted) return;
      setState(() => _saved = true);
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpDetailSavedToast),
      );
    } on Exception {
      if (!mounted) return;
      MealvanaSnackbar.showError(
        context,
        content.getValue(ContentKeys.mpServerError),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// "↗ See the original recipe · greenletes.com".
class _OriginalRecipeLink extends StatelessWidget {
  const _OriginalRecipeLink({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.6);
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';

    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.arrowUpRightFromSquare,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ⇄ on the Ingredients label — reveals the server-suggested swaps
/// under the list. Accent while open, muted while closed.
class _SwapsToggle extends StatelessWidget {
  const _SwapsToggle({
    required this.open,
    required this.tooltip,
    required this.onTap,
  });

  final bool open;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final muted = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.6);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: const ValueKey('meal_planning.detail_swaps_toggle'),
        onTap: onTap,
        child: AnimatedRotation(
          turns: open ? 0.5 : 0,
          duration: const Duration(milliseconds: 150),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FaIcon(
              FontAwesomeIcons.rightLeft,
              size: 14,
              color: open ? accent : muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// An uppercase, letter-spaced section label (prototype `.v-section`).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.overline.copyWith(
        color: (isDark ? AppColors.cream : AppColors.blackberry)
            .withValues(alpha: 0.6),
      ),
    );
  }
}

/// A rounded card whose children are hairline-separated rows
/// (prototype `.k-card` + `.v-listrow`).
class _ListCard extends StatelessWidget {
  const _ListCard({required this.rows});

  final List<_ListRow> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: textColor.withValues(alpha: 0.1),
                        ),
                      ),
              ),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

/// One row inside a [_ListCard]: a fixed [height], or vertical padding when
/// the content wraps.
class _ListRow extends StatelessWidget {
  const _ListRow({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (height != null) {
      return SizedBox(
        height: height,
        child: Align(alignment: Alignment.centerLeft, child: child),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: child,
    );
  }
}

/// The saved meal's own directions: a dashed prompt when empty, the text with
/// a pencil when written, an editor while editing.
class _YourDirections extends ConsumerWidget {
  const _YourDirections({
    required this.editing,
    required this.notes,
    required this.controller,
    required this.onStartEditing,
    required this.onCancel,
    required this.onSave,
  });

  final bool editing;
  final String? notes;
  final TextEditingController controller;
  final VoidCallback onStartEditing;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    if (editing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            TextField(
              key: const ValueKey('meal_planning.detail_notes'),
              controller: controller,
              maxLines: null,
              minLines: 4,
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: content.getValue(
                  ContentKeys.mpDetailYourDirectionsHint,
                ),
                filled: true,
                fillColor: isDark ? AppColors.blackberry : AppColors.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: textColor.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: KylePrimaryButton(
                    text: content.getValue(ContentKeys.mpDetailEditSave),
                    height: 40,
                    onPressed: onSave,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChipButton(
                    label: content.getValue(ContentKeys.mpDetailEditCancel),
                    onTap: onCancel,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (notes != null && notes!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                notes!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor,
                  height: 1.5,
                ),
              ),
            ),
            IconButton(
              onPressed: onStartEditing,
              icon: FaIcon(
                FontAwesomeIcons.penToSquare,
                size: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onStartEditing,
      child: DashedBox(
        child: Text(
          content.getValue(ContentKeys.mpDetailAddDirections),
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// "AI-written steps" — the only origin badge kept on the minimal layout;
/// assembly-simple / verbatim-source badges were removed with the cleanup.
class _OriginBadge extends ConsumerWidget {
  const _OriginBadge({required this.origin});

  final DirectionsOrigin? origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (origin != DirectionsOrigin.aiGenerated) {
      return const SizedBox.shrink();
    }
    final content = ref.read(contentServiceProvider);

    return Tooltip(
      message: content.getValue(ContentKeys.mpCookAiDisclaimer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.orange.withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.wandMagicSparkles,
              size: 11,
              color: AppColors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              content.getValue(ContentKeys.mpBadgeAiGenerated),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: Text(content.getValue(ContentKeys.mpRetry)),
          ),
        ],
      ),
    );
  }
}
