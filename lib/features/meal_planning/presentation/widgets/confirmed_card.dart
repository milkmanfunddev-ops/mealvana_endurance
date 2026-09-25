import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/plan_reminder_service.dart';
import '../../application/plan_share_service.dart';
import '../../domain/meal_plan.dart';
import '../../domain/vana_part.dart';
import 'choice_chip_button.dart';
import 'plan_summary.dart';
import 'session_chip.dart';

/// The "you're set" card (mp-235): the week and meal count, cooking
/// sessions, the list size (with what was skipped because the athlete has
/// it), *where everything lives* — a Plan-tab row and a Shopping-tab row —
/// then Share and the "remind me the night before cook day" chip.
///
/// Two hosts. In chat it answers a `shopping_list` part (plan Phase 4). On
/// Food > Shopping it sits at the top of the list a confirm just built
/// (ticket 131): there the Shopping row is where the athlete already is, so
/// it is inert ([onView] null), and the card adds the chips after a confirm,
/// Lay it across the week ([onLayAcross]) and Adjust ([onAdjust]), and a
/// close ([onDismiss]).
///
/// The part carries only the list; the plan comes from
/// [mealPlanControllerProvider] (or [plan], for hosts and tests that have
/// one in hand). Drawn locally — no model call.
class ConfirmedCard extends ConsumerStatefulWidget {
  const ConfirmedCard({
    super.key,
    required this.part,
    this.onView,
    this.onViewPlan,
    this.plan,
    this.onDismiss,
    this.onLayAcross,
    this.laidAcross = false,
    this.onAdjust,
  });

  final VanaShoppingListPart part;

  /// Open the Shopping tab. Null on the Shopping tab itself: the row names
  /// the list the athlete is on and does nothing.
  final VoidCallback? onView;

  /// Open the Plan tab; the row still renders (inert) without it.
  final VoidCallback? onViewPlan;

  /// Optional override; defaults to the plan controller's current plan.
  final MealPlan? plan;

  /// Close the card for good. No close without it.
  final VoidCallback? onDismiss;

  /// "Lay it across the week"; no chip without it. The host shows the days
  /// and passes [laidAcross] once they are there.
  final Future<void> Function()? onLayAcross;

  /// The week is laid across: the chip shows done.
  final bool laidAcross;

  /// "Adjust": back to Vana about this plan; no chip without it.
  final VoidCallback? onAdjust;

  @override
  ConsumerState<ConfirmedCard> createState() => _ConfirmedCardState();
}

class _ConfirmedCardState extends ConsumerState<ConfirmedCard> {
  bool _reminderSet = false;
  bool _layingAcross = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    final plan = widget.plan ?? ref.watch(mealPlanControllerProvider).value;
    final part = widget.part;

    final line = ContentKeys.format(
      content.getValue(ContentKeys.mpConfirmedLine),
      {'n': part.itemCount},
    );
    final skipped = part.skipped.isEmpty
        ? ''
        : ' ${ContentKeys.format(content.getValue(part.skipped.length == 1 ? ContentKeys.mpConfirmedSkippedOne : ContentKeys.mpConfirmedSkippedMany), {'items': part.skipped.take(2).join(', ')})}';

    return Container(
      key: const ValueKey('meal_planning.confirmed_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: textColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  content.getValue(ContentKeys.mpConfirmedTitle),
                  key: const ValueKey('meal_planning.confirmed_title'),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.onDismiss case final dismiss?)
                IconButton(
                  key: const ValueKey('meal_planning.confirmed_dismiss'),
                  tooltip: content.getValue(ContentKeys.mpConfirmedDismiss),
                  onPressed: dismiss,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(Icons.close, size: 20, color: secondary),
                ),
            ],
          ),
          if (plan != null) ...[
            const SizedBox(height: 2),
            _PlanLine(plan: plan, textColor: textColor, secondary: secondary),
          ],
          const SizedBox(height: 6),
          Text(
            '$line$skipped',
            style: AppTextStyles.bodyMedium.copyWith(
              color: textColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content.getValue(ContentKeys.mpConfirmedWhereTitle).toUpperCase(),
            style: AppTextStyles.overline.copyWith(color: secondary),
          ),
          const SizedBox(height: 4),
          _WhereRow(
            rowKey: const ValueKey('meal_planning.confirmed_plan_row'),
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.electrolyte,
            title: content.getValue(ContentKeys.mpConfirmedPlanRow),
            subtitle: content.getValue(ContentKeys.mpConfirmedPlanRowSub),
            textColor: textColor,
            onTap: widget.onViewPlan,
          ),
          // The shopping list is the payoff of confirming, so it keeps a
          // real row rather than a text link.
          _WhereRow(
            rowKey: const ValueKey('meal_planning.confirmed_shopping_row'),
            icon: Icons.shopping_cart_outlined,
            iconColor: AppColors.orange,
            title: content.getValue(
              widget.onView == null
                  ? ContentKeys.mpConfirmedShoppingRow
                  : ContentKeys.mpReviewShoppingLink,
            ),
            subtitle: content.getValue(ContentKeys.mpConfirmedShoppingRowSub),
            textColor: textColor,
            onTap: widget.onView,
          ),
          if (plan != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                KyleSecondaryButton(
                  key: const ValueKey('meal_planning.confirmed_share'),
                  text: content.getValue(ContentKeys.mpPlanShare),
                  height: 36,
                  onPressed: () => _share(content, plan),
                ),
                ChoiceChipButton(
                  key: const ValueKey('meal_planning.confirmed_remind'),
                  label: content.getValue(ContentKeys.mpRemindChip),
                  selected: _reminderSet,
                  enabled: !_reminderSet,
                  onTap: () => _remind(context, content, plan),
                ),
              ],
            ),
          ],
          // mp-235 detail 3: the chips after a confirm. "Open shopping list"
          // is left off: this host only draws them on the list itself.
          if (widget.onLayAcross != null || widget.onAdjust != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (widget.onLayAcross case final layAcross?)
                  ChoiceChipButton(
                    key: const ValueKey('meal_planning.confirmed_lay_across'),
                    label: content.getValue(ContentKeys.mpConfirmedLayAcross),
                    selected: widget.laidAcross,
                    enabled: !widget.laidAcross && !_layingAcross,
                    onTap: () => _layAcross(layAcross),
                  ),
                if (widget.onAdjust case final adjust?)
                  ChoiceChipButton(
                    key: const ValueKey('meal_planning.confirmed_adjust'),
                    label: content.getValue(ContentKeys.mpConfirmedAdjust),
                    onTap: adjust,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The chip greys out while the week is on the wire; the host says why
  /// when it fails and the chip comes back.
  Future<void> _layAcross(Future<void> Function() layAcross) async {
    setState(() => _layingAcross = true);
    try {
      await layAcross();
    } finally {
      if (mounted) setState(() => _layingAcross = false);
    }
  }

  void _share(ContentService content, MealPlan plan) {
    final body = PlanShareService.text(
      content,
      plan,
      weekLabel: PlanSummary.weekLabel(
        plan.weekStart,
        plan.coverage.periodDays,
      ),
      sessionLabel: (s) => SessionChip.labelInPlan(content, s, plan),
    );
    if (body.isEmpty) return;
    SharePlus.instance.share(ShareParams(text: body));
  }

  Future<void> _remind(
    BuildContext context,
    ContentService content,
    MealPlan plan,
  ) async {
    final result = await ref
        .read(planReminderServiceProvider)
        .scheduleCheckin(plan);
    if (!context.mounted) return;
    switch (result.outcome) {
      case PlanReminderOutcome.scheduled:
        setState(() => _reminderSet = true);
        MealvanaSnackbar.showInfo(
          context,
          ContentKeys.format(content.getValue(ContentKeys.mpRemindScheduled), {
            'when': DateFormat('EEE h:mm a').format(result.when!),
          }),
        );
      case PlanReminderOutcome.noPermission:
        MealvanaSnackbar.showInfo(
          context,
          content.getValue(ContentKeys.mpRemindUnavailable),
        );
      case PlanReminderOutcome.pastDue:
        MealvanaSnackbar.showInfo(
          context,
          content.getValue(ContentKeys.mpRemindPast),
        );
    }
  }
}

/// "Aug 30 – Sep 5 · 4 meals · 2 cooking sessions".
class _PlanLine extends ConsumerWidget {
  const _PlanLine({
    required this.plan,
    required this.textColor,
    required this.secondary,
  });

  final MealPlan plan;
  final Color textColor;
  final Color secondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final count = plan.meals.length;
    final meals = count == 1
        ? content.getValue(ContentKeys.mpPlanWeekMealOne)
        : ContentKeys.format(content.getValue(ContentKeys.mpPlanWeekMeals), {
            'n': count,
          });
    final sessionCount = PlanShareService.sessionsOf(plan).length;
    final sessions = sessionCount == 1
        ? content.getValue(ContentKeys.mpConfirmedSessionOne)
        : ContentKeys.format(
            content.getValue(ContentKeys.mpConfirmedSessions),
            {'n': sessionCount},
          );

    return Text(
      [
        PlanSummary.weekLabel(plan.weekStart, plan.coverage.periodDays),
        meals,
        if (sessionCount > 0) sessions,
      ].join(' · '),
      key: const ValueKey('meal_planning.confirmed_plan_line'),
      style: AppTextStyles.bodySmall.copyWith(color: secondary),
    );
  }
}

/// One "where it lives" row: a tinted disc icon, title over subtitle, and
/// a chevron when tappable.
class _WhereRow extends StatelessWidget {
  const _WhereRow({
    required this.rowKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor,
              ),
              child: Icon(icon, size: 16, color: AppColors.blackberry),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.foodTitle.copyWith(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: textColor.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: textColor.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}
