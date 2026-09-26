import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/providers/is_admin_provider.dart';
import '../../../../shared/services/analytics/internal_user_service.dart';
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
import '../../domain/vana_situation.dart';
import '../widgets/vana_situation_scope.dart';
import '../../domain/meal_source.dart';
import '../../domain/ui_action.dart';
import '../widgets/choice_chip_button.dart';
import '../widgets/directions_origin_label.dart';
import '../widgets/meal_photo_entry_points.dart';
import '../widgets/meal_photo_view.dart';
import '../widgets/servings_sheet.dart';
import '../widgets/vana_round_button.dart';
import '../widgets/dashed_box.dart';
import '../widgets/vana_tag.dart';
import 'vana_browse_screen.dart';
import '../../../../shared/core/pop_or_home.dart';
import '../widgets/write_failure_snackbar.dart';

/// `/food/meals/:id` (05 §4), minimal layout: hero, title + "see the
/// original recipe", thumbs · prep row, macro pills, ingredients,
/// directions labelled by origin (mp-146), saved-meal notes, swaps as
/// plain tips.
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

    return VanaSituationScope(
      situation: VanaSituation.screen(
        VanaScreen.mealDetail,
        entityId: widget.id,
      ),
      child: Scaffold(
        key: ValueKey('meal_planning.detail_${widget.id}'),
        backgroundColor: bg,
        body: SafeArea(
          child: detailAsync.when(
            // A screen still loading, or one that failed, is still a screen
            // the athlete can leave: the back button is drawn here too
            // (2026-09-26: a dead id left a spinner with no way back).
            loading: () => _WithBack(
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.electrolyte),
              ),
            ),
            error: (e, _) => _WithBack(
              child: _LoadError(
                onRetry: () =>
                    ref.invalidate(mealDetailControllerProvider(widget.id)),
              ),
            ),
            data: (detail) => _DetailBody(
              detail: detail,
              swapPlanMealId: widget.swapPlanMealId,
              pickConversationId: widget.pickConversationId,
              notesController: _notesController,
            ),
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

  Future<bool> _openOriginal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final meal = detail.meal;
    final isSaved = meal.source == MealSource.saved;
    // A Tester is anyone who turned on "Mark this device as internal" in
    // Settings (ADR 0003). Library meals only: a saved meal has no
    // meal_library row, so it has no photos page to open. The server re-checks
    // users.is_internal on every call — this only decides what to draw.
    final isTester = ref.watch(internalDeviceFlagProvider) && !isSaved;

    String cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

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
            VanaRoundButton.back(context: context, onTap: context.popOrHome),
            const Spacer(),
            if (!isSaved) _SaveToMineButton(mealId: meal.id),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // The Dish photo, or nothing: a Meal without one opens at its name,
        // with no empty space above it (ADR 0003).
        if (detail.photo case final photo?) ...[
          Stack(
            children: [
              MealPhotoHero(photo: photo),
              // A small camera icon on the photograph, for a Tester only: an
              // athlete's recipe screen stays about cooking (stories 14, 16).
              if (isTester)
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: MealPhotoChangeIcon(meal: meal),
                ),
            ],
          ),
          // One credit line, only when the photo carries one, opening the
          // photograph's page when it has one.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MealPhotoCreditLine(
              photo: photo,
              onOpen: (uri) =>
                  launchUrl(uri, mode: LaunchMode.externalApplication),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else if (isTester) ...[
          // Where the picture would be: the line that shows a Tester which
          // meals still need a photograph, while they are cooking one
          // (story 17). An athlete sees nothing here at all.
          MealAddPhotoLine(meal: meal),
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

        // ── Admin review box (mp-144 clause 3) — admins only ──────────────
        if (ref.watch(isAdminProvider).value == true) ...[
          const SizedBox(height: AppSpacing.sm),
          _AdminReviewBox(mealId: meal.id),
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
              // AI-written steps keep the sparkle badge on the label row.
              if (detail.directions.origin == DirectionsOrigin.aiGenerated) ...[
                const SizedBox(width: AppSpacing.sm),
                DirectionsOriginLabel(
                  directions: detail.directions,
                  onOpen: _openOriginal,
                ),
              ],
            ],
          ),
          // mp-146: every other origin gets its own line under the label —
          // "As published by X" (linked), "Steps from X", or "A simple
          // assembly". No recorded origin, no line.
          if (detail.directions.origin != null &&
              detail.directions.origin != DirectionsOrigin.aiGenerated) ...[
            const SizedBox(height: AppSpacing.xxs),
            DirectionsOriginLabel(
              directions: detail.directions,
              onOpen: _openOriginal,
            ),
          ],
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
          _SectionLabel(content.getValue(ContentKeys.mpDetailYourDirections)),
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
        else if (pickConversationId != null && _inDraft(meal.id))
          // Already in this conversation's draft: say so, as the Browse
          // card's tick does, and offer no Add that would add nothing
          // (testing-wave 88-007).
          _InPlanNote(label: content.getValue(ContentKeys.mpBrowseAdded))
        else if (pickConversationId != null)
          KylePrimaryButton(
            key: const ValueKey('meal_planning.detail_add_to_plan'),
            text: content.getValue(ContentKeys.mpDetailAddToPlan),
            icon: Icons.add,
            height: 48,
            isLoading: _adding,
            // A meal with missing numbers never goes in a plan (mp-678):
            // say so here instead of failing after the tap.
            onPressed: meal.hasNutritionNumbers
                ? () => _addToPlan(context, ref)
                : () => MealvanaSnackbar.showInfo(
                    context,
                    content.getValue(ContentKeys.mpBrowseNoNumbers),
                  ),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  /// [mealId] is already in the pick conversation's draft (library id, or
  /// the saved uuid), matched the way the Browse screen ticks its cards.
  bool _inDraft(String mealId) {
    final draft = ref
        .watch(conversationDraftProvider(pickConversationId!))
        .value;
    return draft?.meals.any(
          (m) => (m.libraryMealId ?? m.savedMealId) == mealId,
        ) ??
        false;
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
    } on Exception catch (e) {
      // Offline says so, whether refused before sending or cut off (88-013).
      if (context.mounted) showWriteFailure(context, content, e);
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
  /// What the last tap did, shown until My Foods (Drift) says the same.
  bool? _tapped;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    // Saved on an earlier visit reads as saved (testing-wave 89-009).
    final stored =
        ref.watch(savedCopyOfLibraryMealProvider(widget.mealId)).value != null;
    if (_tapped == stored) _tapped = null;
    final saved = _tapped ?? stored;

    return Tooltip(
      message: content.getValue(
        saved
            ? ContentKeys.mpDetailRemoveFromMine
            : ContentKeys.mpDetailSaveToMine,
      ),
      child: Material(
        color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey('meal_planning.detail_save_to_mine'),
          onTap: _busy ? null : (saved ? _remove : _save),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: FaIcon(
                saved ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                size: 18,
                color: saved ? AppColors.dragonfruit : textColor,
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
      setState(() => _tapped = true);
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

  /// A tap on the filled heart takes the meal out of My Foods.
  Future<void> _remove() async {
    final content = ref.read(contentServiceProvider);
    setState(() => _busy = true);
    try {
      final removed = await ref
          .read(mealDetailControllerProvider(widget.mealId).notifier)
          .removeFromMine();
      if (!mounted) return;
      setState(() => _tapped = false);
      if (removed) {
        MealvanaSnackbar.showSuccess(
          context,
          content.getValue(ContentKeys.mpDetailRemovedToast),
        );
      }
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

/// "In your plan" in place of Add to plan, for a meal already in the draft.
class _InPlanNote extends StatelessWidget {
  const _InPlanNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    return SizedBox(
      key: const ValueKey('meal_planning.detail_in_plan'),
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 20, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
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
    final muted = (isDark ? AppColors.cream : AppColors.blackberry).withValues(
      alpha: 0.6,
    );

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
        color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
          alpha: 0.6,
        ),
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

/// The admin-only review box under the thumbs (mp-144 clause 3): good
/// recipe or not, plus why, sent as one `meal_reviews` row (remote-ack).
/// Rendered only when `isAdminProvider` is true; athletes never see it.
class _AdminReviewBox extends ConsumerStatefulWidget {
  const _AdminReviewBox({required this.mealId});

  final String mealId;

  @override
  ConsumerState<_AdminReviewBox> createState() => _AdminReviewBoxState();
}

class _AdminReviewBoxState extends ConsumerState<_AdminReviewBox> {
  final _why = TextEditingController();

  /// null until the admin picks Good / Not good.
  bool? _isGood;
  bool _sending = false;

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final isGood = _isGood;
    if (isGood == null || _why.text.trim().isEmpty || _sending) return;
    final content = ref.read(contentServiceProvider);
    setState(() => _sending = true);
    try {
      await ref
          .read(mealDetailControllerProvider(widget.mealId).notifier)
          .review(isGood: isGood, why: _why.text);
      if (!mounted) return;
      _why.clear();
      setState(() => _isGood = null);
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.mpDetailReviewSent),
        duration: MealvanaSnackbar.shortDuration,
      );
    } on VanaOfflineException {
      if (!mounted) return;
      MealvanaSnackbar.showWarning(
        context,
        content.getValue(ContentKeys.mpNeedsConnection),
      );
    } catch (_) {
      if (!mounted) return;
      MealvanaSnackbar.showError(
        context,
        content.getValue(ContentKeys.mpServerError),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final canSend = _isGood != null && _why.text.trim().isNotEmpty && !_sending;

    return Container(
      key: const ValueKey('meal_planning.detail_admin_review'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(content.getValue(ContentKeys.mpDetailReviewTitle)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              ChoiceChipButton(
                key: const ValueKey('meal_planning.detail_review_good'),
                label: content.getValue(ContentKeys.mpDetailReviewGood),
                selected: _isGood == true,
                onTap: () => setState(() => _isGood = true),
              ),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChipButton(
                key: const ValueKey('meal_planning.detail_review_not_good'),
                label: content.getValue(ContentKeys.mpDetailReviewNotGood),
                selected: _isGood == false,
                onTap: () => setState(() => _isGood = false),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('meal_planning.detail_review_why'),
            controller: _why,
            maxLines: null,
            minLines: 3,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: content.getValue(ContentKeys.mpDetailReviewWhyHint),
              counterText: '',
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
          KylePrimaryButton(
            key: const ValueKey('meal_planning.detail_review_send'),
            text: content.getValue(ContentKeys.mpDetailReviewSend),
            height: 40,
            isLoading: _sending,
            onPressed: canSend ? _send : null,
          ),
        ],
      ),
    );
  }
}

/// The back button over a body that has no header of its own.
class _WithBack extends StatelessWidget {
  const _WithBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.md,
          child: VanaRoundButton.back(
            key: const ValueKey('meal_planning.detail_back'),
            context: context,
            onTap: () => context.canPop() ? context.pop() : context.go('/main'),
          ),
        ),
      ],
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
