import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
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
import '../widgets/servings_sheet.dart';
import '../widgets/slot_chip.dart';

/// `/food/meals/:id` (05 §4): hero, tags, why, thumbs, attribution,
/// ingredients, "How to cook" with origin badges, saved-meal notes, swaps,
/// macros disclosure. `?swap=<planMealId>` turns the primary action into
/// "Swap in" + servings stepper (remote-ack `swap_meal`).
class MealDetailScreen extends ConsumerStatefulWidget {
  const MealDetailScreen({super.key, required this.id, this.swapPlanMealId});

  final String id;

  /// `plan_meals.id` when opened from the swap flow.
  final String? swapPlanMealId;

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => _LoadError(
          onRetry: () => ref.invalidate(mealDetailControllerProvider(widget.id)),
        ),
        data: (detail) => _DetailBody(
          detail: detail,
          swapPlanMealId: widget.swapPlanMealId,
          notesController: _notesController,
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.detail,
    required this.swapPlanMealId,
    required this.notesController,
  });

  final MealDetail detail;
  final String? swapPlanMealId;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final meal = detail.meal;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (detail.image?.url != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: Image.network(
              detail.image!.url,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (detail.image?.credit != null &&
            detail.image!.credit!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            detail.image!.credit!,
            style: AppTextStyles.bodySmall.copyWith(
              color: secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          meal.name,
          style: AppTextStyles.pageTitle.copyWith(color: textColor),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          children: [
            SlotChip(type: meal.mealType),
            if (meal.prepMinutes != null)
              Chip(
                label: Text('${meal.prepMinutes} min'),
                visualDensity: VisualDensity.compact,
              ),
            for (final diet in meal.dietsOk.take(3))
              Chip(label: Text(diet), visualDensity: VisualDensity.compact),
          ],
        ),
        if (meal.why.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            meal.why,
            style: AppTextStyles.bodyMedium.copyWith(
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),

        // ── Thumbs ────────────────────────────────────────────────────────
        Row(
          children: [
            _ThumbButton(
              key: const ValueKey('meal_planning.detail_thumb_up'),
              icon: FontAwesomeIcons.thumbsUp,
              active: detail.vote == 1,
              color: accent,
              onTap: () => ref
                  .read(mealDetailControllerProvider(meal.id).notifier)
                  .vote(1),
            ),
            const SizedBox(width: AppSpacing.lg),
            _ThumbButton(
              key: const ValueKey('meal_planning.detail_thumb_down'),
              icon: FontAwesomeIcons.thumbsDown,
              active: detail.vote == -1,
              color: AppColors.dragonfruit,
              onTap: () {
                ref
                    .read(mealDetailControllerProvider(meal.id).notifier)
                    .vote(-1);
                MealvanaSnackbar.showInfo(
                  context,
                  content.getValue(ContentKeys.mpDetailThumbsDownNote),
                );
              },
            ),
          ],
        ),

        // ── Attribution ───────────────────────────────────────────────────
        if (meal.attribution.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _AttributionCard(
            attribution: meal.attribution,
            sourceUrl: detail.sourceUrl,
            linkLabel: content.getValue(ContentKeys.mpDetailSeeOriginal),
          ),
        ],

        // ── Ingredients ───────────────────────────────────────────────────
        if (detail.ingredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            content.getValue(ContentKeys.mpDetailIngredients),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 18,
            ),
          ),
          Text(
            detail.servings > 1
                ? ContentKeys.format(
                    content.getValue(ContentKeys.mpDetailMakes),
                    {'n': detail.servings},
                  )
                : content.getValue(ContentKeys.mpDetailOneServing),
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final ingredient in detail.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text(
                    ingredient.name,
                    style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                  ),
                  const Spacer(),
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

        // ── How to cook ───────────────────────────────────────────────────
        if (detail.methodSteps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            content.getValue(ContentKeys.mpDetailHowToCook),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 18,
            ),
          ),
          _OriginBadge(origin: detail.directions.origin, sourceName: detail.directions.sourceName),
          const SizedBox(height: AppSpacing.xs),
          for (final (i, step) in detail.methodSteps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      step,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const ValueKey('meal_planning.detail_start_cooking'),
              onPressed: () => context.push('/food/cook/${meal.id}'),
              style: TextButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.16),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              icon: FaIcon(FontAwesomeIcons.fire, size: 16),
              label: Text(
                content.getValue(ContentKeys.mpDetailStartCooking),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.blackberry,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        // ── Your directions (saved meals) ─────────────────────────────────
        if (meal.source == MealSource.saved) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            content.getValue(ContentKeys.mpDetailYourDirections),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const ValueKey('meal_planning.detail_notes'),
            controller: notesController,
            maxLines: 3,
            style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: content.getValue(ContentKeys.mpDetailYourDirectionsHint),
              filled: true,
              fillColor: isDark
                  ? AppColors.blackberryLight
                  : AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                borderSide: BorderSide.none,
              ),
            ),
            onEditingComplete: () async {
              await ref
                  .read(mealDetailControllerProvider(meal.id).notifier)
                  .setNotes(notesController.text);
              if (context.mounted) {
                MealvanaSnackbar.showSuccess(
                  context,
                  content.getValue(ContentKeys.mpDetailDirectionsSaved),
                );
              }
            },
          ),
        ],

        // ── Swap ideas ────────────────────────────────────────────────────
        if (detail.swaps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            content.getValue(ContentKeys.mpDetailSwapsTitle),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final swap in detail.swaps)
                Chip(label: Text(swap), visualDensity: VisualDensity.compact),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        Text(
          content.getValue(ContentKeys.mpDetailMacrosNote),
          style: AppTextStyles.bodySmall.copyWith(
            color: secondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Primary action: Swap in (from swap flow) or Save to mine ──────
        if (swapPlanMealId != null)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const ValueKey('meal_planning.detail_swap_in'),
              onPressed: () => _swapIn(context, ref),
              style: TextButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.16),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              child: Text(
                content.getValue(ContentKeys.mpBtnSwapIn),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.blackberry,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else if (meal.source == MealSource.library)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const ValueKey('meal_planning.detail_save_to_mine'),
              onPressed: () async {
                try {
                  await ref
                      .read(mealDetailControllerProvider(meal.id).notifier)
                      .saveToMine();
                  if (context.mounted) {
                    MealvanaSnackbar.showSuccess(
                      context,
                      content.getValue(ContentKeys.mpDetailSavedToast),
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
              },
              style: TextButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.16),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              child: Text(
                content.getValue(ContentKeys.mpDetailSaveToMine),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.blackberry,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
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
        // The new plan_meal id comes back in the plan watch; the swap RPC
        // keeps the old servings, so the caller adjusts via setServings on
        // the refreshed plan's newest row for this meal.
        final plan = ref.read(mealPlanControllerProvider).value;
        final row = plan?.meals
            .where((m) => m.name == detail.meal.name)
            .firstOrNull;
        if (row != null) {
          await controller.setServings(row.id, servings);
        }
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

class _ThumbButton extends StatelessWidget {
  const _ThumbButton({
    super.key,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final FaIconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: FaIcon(icon, size: 20),
      color: active ? color : color.withValues(alpha: 0.4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AttributionCard extends StatelessWidget {
  const _AttributionCard({
    required this.attribution,
    required this.sourceUrl,
    required this.linkLabel,
  });

  final String attribution;
  final String? sourceUrl;
  final String linkLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attribution,
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          ),
          if (sourceUrl != null && sourceUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(sourceUrl!)),
              child: Text(
                linkLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OriginBadge extends ConsumerWidget {
  const _OriginBadge({required this.origin, required this.sourceName});

  final DirectionsOrigin? origin;
  final String? sourceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.65);

    final (label, tooltip) = switch (origin) {
      DirectionsOrigin.aiGenerated => (
        content.getValue(ContentKeys.mpBadgeAiGenerated),
        content.getValue(ContentKeys.mpCookAiDisclaimer),
      ),
      DirectionsOrigin.assemblySimple => (
        content.getValue(ContentKeys.mpBadgeAssemblySimple),
        '',
      ),
      DirectionsOrigin.altSource => (
        content.getValue(ContentKeys.mpBadgeAltSource),
        '',
      ),
      DirectionsOrigin.source => (
        ContentKeys.format(content.getValue(ContentKeys.mpBadgeVerbatim), {
          'source': sourceName ?? '',
        }),
        '',
      ),
      null => ('', ''),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (origin == DirectionsOrigin.aiGenerated)
            FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 12, color: secondary),
          if (origin == DirectionsOrigin.aiGenerated) const SizedBox(width: 4),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: secondary)),
        ],
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
