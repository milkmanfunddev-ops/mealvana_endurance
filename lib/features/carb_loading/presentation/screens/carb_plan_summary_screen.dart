import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart'
    show MealvanaSnackbar;
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../auth/application/auth_service.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../domain/carb_loading_entryway_engine.dart';
import '../../domain/carb_loading_pace_engine.dart';
import '../providers/carb_loading_controller.dart';
import '../widgets/carb_repick_dialogs.dart';
import '../widgets/edit_carb_target_dialog.dart';
import 'carb_loading_protocol_selection_screen.dart';

/// The plan summary surface — a full PAGE (desk G12; the sheet fork is
/// retired). Spec: `spec/design/surfaces/carb-loading-entryway.md` (RATIFIED
/// 2026-09-25) + `spec/fueling/carb-loading-entryway.md` CE-4/CE-5/CE-8/CE-9.
///
/// Re-picking a protocol is an action ON the plan, one level in, where its
/// consequences can be shown: quiet regenerate when nothing was edited; the
/// exactly-two-choice Keep/Reset dialog when edits survive (F3: relabeled
/// per the TARGET window, with the date); the single-button notice when
/// every edit falls outside the new window (F4). A backdrop tap ABORTS both
/// dialogs (CE-9) — plan untouched, chooser still open beneath. Delete is
/// dragonfruit with the Path-A-honest copy.
class CarbPlanSummaryScreen extends ConsumerWidget {
  const CarbPlanSummaryScreen({super.key, required this.eventId});

  final String eventId;

  static void open(BuildContext context, String eventId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarbPlanSummaryScreen(eventId: eventId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(carbLoadingPlanProvider(eventId));
    final plan = planAsync.value;
    final days = plan == null
        ? null
        : ref.watch(carbLoadingDaysForPlanProvider(plan.id)).value;
    final event = ref.watch(eventDetailProvider(eventId)).value?.event;
    final cream = AppColors.cream;

    final raceDate = _raceDate(event);
    final daysUntilRace = raceDate == null ? null : _daysUntil(raceDate);
    final raceDay = daysUntilRace != null && daysUntilRace <= 0;

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: SafeArea(
        child: plan == null || days == null || days.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        _backButton(context),
                        const SizedBox(width: 10),
                        Text(
                          'Carb Loading Plan',
                          style: TextStyle(
                            fontFamily: 'Compadre',
                            fontSize: 18,
                            color: cream,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 6),
                          child: Text(
                            '${_protocolName(plan.totalDays)} · '
                                    '${_windowStr(days)}'
                                .toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Apercu',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: cream.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        for (final d in [
                          ...days,
                        ]..sort((a, b) => a.planDate.compareTo(b.planDate)))
                          _dayRow(ref, d, plan.totalDays),
                        const SizedBox(height: 14),
                        _repickRow(context, ref, raceDay, raceDate),
                        const SizedBox(height: 8),
                        _deleteRow(context, ref),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _dayRow(WidgetRef ref, dynamic day, int totalDays) {
    // CE-10 (G17, RULED 2026-09-26): today's and future rows open the Edit
    // Target dialog; PAST rows are inert — that day is history. The dialog
    // keeps its own Cancel (CE-9 does not bind it).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime planDate = day.planDate as DateTime;
    final rowDate = DateTime(planDate.year, planDate.month, planDate.day);
    final editable = !rowDate.isBefore(today);
    final cream = AppColors.cream;
    final weightLb = _weightLb(ref);
    // "Edited" = stored != its protocol derivation at the current weight.
    final derived = weightLb == null
        ? null
        : CarbLoadingPaceEngine.dayTargetG(
            bodyWeightLb: weightLb,
            protocolDays: totalDays,
            daysBeforeRace: totalDays - (day.dayNumber - 1) as int,
          );
    final int grams = day.carbTargetGrams as int;
    final edited = derived != null && derived != grams;
    final gkg = weightLb == null
        ? null
        : (grams / (weightLb * CarbLoadingPaceEngine.kgPerLb));

    return GestureDetector(
      key: ValueKey('carb_summary.day_row_${day.dayNumber}'),
      behavior: HitTestBehavior.opaque,
      onTap: editable && weightLb != null
          ? () => _editDayTarget(ref, day, weightLb)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cream.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'DAY ${day.dayNumber}',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: cream.withValues(alpha: 0.75),
                  ),
                  children: [
                    TextSpan(
                      text: '  ${_dateStr(day.planDate as DateTime)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                        color: cream.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text.rich(
              TextSpan(
                text: '$grams g',
                style: const TextStyle(
                  fontFamily: 'Apercu Mono',
                  fontSize: 12.5,
                  color: AppColors.orange,
                ),
                children: [
                  if (gkg != null)
                    TextSpan(
                      // Q-CL10: copy shows the STORED per-day rate — the
                      // engine's number, not the protocol constant.
                      text: ' · ${gkg.toStringAsFixed(1)} g/kg',
                      style: TextStyle(
                        color: AppColors.cream.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
            ),
            if (edited) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'EDITED',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ],
            if (editable) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: cream.withValues(alpha: 0.35),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// CE-10: the EXISTING Edit Target dialog, reused — no new editor surface.
  Future<void> _editDayTarget(
    WidgetRef ref,
    dynamic day,
    double weightLb,
  ) async {
    final context = ref.context;
    final bodyWeightKg = weightLb * CarbLoadingPaceEngine.kgPerLb;
    final int grams = day.carbTargetGrams as int;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => EditCarbTargetDialog(
        currentCarbsPerKg: bodyWeightKg > 0 ? grams / bodyWeightKg : 0,
        currentDailyTargetG: grams,
        bodyWeightKg: bodyWeightKg,
        onSave: (carbsPerKg, dailyTargetG) {
          ref
              .read(carbLoadingControllerProvider.notifier)
              .updateDayTarget(
                carbLoadingDayId: day.id as String,
                carbsPerKg: carbsPerKg,
                dailyTargetG: dailyTargetG,
              );
        },
      ),
    );
  }

  Widget _repickRow(
    BuildContext context,
    WidgetRef ref,
    bool raceDay,
    DateTime? raceDate,
  ) {
    final cream = AppColors.cream;
    return Semantics(
      button: true,
      label: 'Change protocol',
      child: GestureDetector(
        key: const ValueKey('carb_summary.change_protocol'),
        // CE-8: race day offers nothing choosable — disabled with reason.
        onTap: raceDay || raceDate == null
            ? null
            : () => _repick(context, ref, raceDate),
        child: Opacity(
          opacity: raceDay ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cream.withValues(alpha: raceDay ? 0.08 : 0.18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change protocol',
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: cream,
                        ),
                      ),
                      if (raceDay)
                        Text(
                          'Nothing fits before race day',
                          style: TextStyle(
                            fontFamily: 'Apercu',
                            fontSize: 10.5,
                            color: cream.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: cream.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _repick(
    BuildContext context,
    WidgetRef ref,
    DateTime raceDate,
  ) async {
    final plan = ref.read(carbLoadingPlanProvider(eventId)).value;
    final weightLb = _weightLb(ref);
    if (plan == null || weightLb == null) return;

    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CarbLoadingProtocolSelectionScreen.forRepick(
          raceDate: raceDate,
          currentProtocolDays: plan.totalDays,
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    // F5: feasibility re-checked at selection time (midnight-rollover guard).
    if (!CarbLoadingEntrywayEngine.isChoosable(
      daysUntilRace: _daysUntil(raceDate),
      protocolDays: selected,
    )) {
      return;
    }
    if (selected == plan.totalDays) return; // same protocol: no-op.

    final controller = ref.read(carbLoadingControllerProvider.notifier);
    final decision = await controller.previewRepickProtocol(
      eventId: eventId,
      targetProtocolDays: selected,
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
    );
    if (!context.mounted) return;

    bool? keepEdits;
    switch (decision.dialogType) {
      case RepickDialogType.none:
        keepEdits = false; // quiet regenerate — outcome is the derivation.
      case RepickDialogType.keepReset:
        keepEdits = await showCarbRepickKeepResetDialog(
          context,
          decision: decision,
        );
      case RepickDialogType.notice:
        final proceed = await showCarbRepickNoticeDialog(
          context,
          decision: decision,
          targetProtocolName: _protocolName(selected),
        );
        keepEdits = proceed == true ? false : null;
    }
    if (keepEdits == null || !context.mounted) return; // CE-9 abort.

    await controller.applyRepickProtocol(
      eventId: eventId,
      targetProtocolDays: selected,
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
      keepEdits: keepEdits,
    );
    if (context.mounted) {
      MealvanaSnackbar.showSuccess(
        context,
        'Switched to the ${_protocolName(selected)} protocol',
      );
    }
  }

  Widget _deleteRow(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Remove carb loading plan',
      child: GestureDetector(
        key: const ValueKey('carb_summary.remove_plan'),
        onTap: () => _confirmDelete(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.dragonfruit.withValues(alpha: 0.45),
            ),
          ),
          child: const Text(
            'Remove carb loading plan',
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.dragonfruit,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _dialogShell(
        title: 'Remove carb loading plan?',
        // Path-A-honest copy: slot logs are ordinary food-log rows.
        body:
            'Targets and schedule are deleted. Food you’ve already '
            'logged stays in your log.',
        actions: [
          _destructiveAction(ctx, 'Remove', true),
          _secondaryAction(ctx, 'Cancel', false),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(carbLoadingControllerProvider.notifier)
        .deleteCarbLoadingPlan(eventId);
    if (context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'Carb loading plan removed');
      Navigator.of(context).maybePop();
    }
  }

  // ---- shared dialog chrome -------------------------------------------

  Widget _dialogShell({
    required String title,
    required String body,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: const Color(0xFF2E112A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.cream.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Compadre',
                fontSize: 17,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 12,
                height: 1.45,
                color: AppColors.cream.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 14),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _destructiveAction(BuildContext ctx, String label, bool result) =>
      _actionButton(
        ctx,
        label,
        result,
        background: AppColors.dragonfruit,
        foreground: AppColors.cream,
      );

  Widget _secondaryAction(BuildContext ctx, String label, bool result) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(result),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.cream.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Apercu',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.cream,
              ),
            ),
          ),
        ),
      );

  Widget _actionButton(
    BuildContext ctx,
    String label,
    bool result, {
    required Color background,
    required Color foreground,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => Navigator.of(ctx).pop(result),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Apercu',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ---- helpers --------------------------------------------------------

  double? _weightLb(WidgetRef ref) {
    final profile = ref.watch(currentUserProvider).value;
    final lb = profile?.weightPounds;
    return lb != null && lb > 0 ? lb : null;
  }

  Widget _backButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          child: const Icon(
            Icons.chevron_left,
            size: 20,
            color: AppColors.cream,
          ),
        ),
      ),
    );
  }
}

String _protocolName(int days) => switch (days) {
  3 => '3-Day Classic',
  2 => '2-Day Quick',
  _ => '1-Day',
};

DateTime? _raceDate(dynamic event) {
  if (event == null) return null;
  final DateTime? d = event.eventDate as DateTime?;
  if (d != null) return DateTime(d.year, d.month, d.day);
  final s = event.startTime as String?;
  if (s == null) return null;
  final parsed = DateTime.tryParse(s);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

int _daysUntil(DateTime raceDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return raceDate.difference(today).inDays;
}

String _dateStr(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

String _windowStr(List<dynamic> days) {
  final sorted = [
    ...days,
  ]..sort((a, b) => (a.planDate as DateTime).compareTo(b.planDate as DateTime));
  final first = sorted.first.planDate as DateTime;
  final last = sorted.last.planDate as DateTime;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (first == last) return '${months[first.month - 1]} ${first.day}';
  if (first.month == last.month) {
    return '${months[first.month - 1]} ${first.day}–${last.day}';
  }
  return '${months[first.month - 1]} ${first.day}–'
      '${months[last.month - 1]} ${last.day}';
}
