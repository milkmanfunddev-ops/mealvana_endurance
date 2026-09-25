/// The CE-4 re-pick dialogs (spec/fueling/carb-loading-entryway.md +
/// spec/design/surfaces/carb-loading-entryway.md, desk 2026-09-25):
///
/// * Keep/Reset — exactly two choices, no third option (Q-CE3). F3: edits
///   are listed relabeled per the TARGET protocol's window, WITH the date.
/// * F4 single-button notice — when every edit falls outside the new
///   window, the outcome is stated and one button proceeds.
/// * CE-9 — a backdrop tap ABORTS either dialog (returns null): the abort
///   is a gesture, not a third button. Callers treat null as "nothing
///   happened" — plan untouched, chooser still open beneath.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/carb_loading_entryway_engine.dart';

/// true = keep, false = reset, null = aborted (CE-9).
Future<bool?> showCarbRepickKeepResetDialog(
  BuildContext context, {
  required RepickDecision decision,
}) {
  final listed = decision.listedEdits
      .map(
        (e) =>
            'Day ${e.targetDayNumber} (${carbRepickDateStr(e.date)}) — '
            'you set ${e.storedG} g',
      )
      .join('; ');
  final dropped = decision.droppedDates.isEmpty
      ? ''
      : '\n${decision.droppedDates.map(carbRepickDateStr).join(', ')} '
            'falls outside the new window — that target goes away.';
  return showDialog<bool>(
    context: context,
    barrierDismissible: true, // CE-9
    builder: (ctx) => _CarbRepickDialogShell(
      title: 'Keep your edited targets?',
      body: 'You edited: $listed.$dropped',
      actions: [
        _action(
          ctx,
          'Keep my targets',
          true,
          key: const ValueKey('carb_repick.keep'),
          background: AppColors.orange,
          foreground: AppColors.blackberry,
        ),
        _outlined(
          ctx,
          'Reset to protocol',
          false,
          key: const ValueKey('carb_repick.reset'),
        ),
      ],
    ),
  );
}

/// true = proceed (targets reset to derivation), null = aborted (CE-9).
Future<bool?> showCarbRepickNoticeDialog(
  BuildContext context, {
  required RepickDecision decision,
  required String targetProtocolName,
}) {
  final dates = decision.droppedDates.map(carbRepickDateStr).join(', ');
  return showDialog<bool>(
    context: context,
    barrierDismissible: true, // CE-9
    builder: (ctx) => _CarbRepickDialogShell(
      title: 'Edited target won’t carry over',
      body:
          'On the $targetProtocolName protocol, $dates falls outside the '
          'window — your edited target goes away. Day targets reset to '
          'protocol.',
      actions: [
        _action(
          ctx,
          'Switch to $targetProtocolName',
          true,
          key: const ValueKey('carb_repick.notice_proceed'),
          background: AppColors.orange,
          foreground: AppColors.blackberry,
        ),
      ],
    ),
  );
}

String carbRepickDateStr(DateTime d) {
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

class _CarbRepickDialogShell extends StatelessWidget {
  const _CarbRepickDialogShell({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
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
}

Widget _action(
  BuildContext ctx,
  String label,
  bool result, {
  required Key key,
  required Color background,
  required Color foreground,
}) {
  return SizedBox(
    width: double.infinity,
    child: FilledButton(
      key: key,
      onPressed: () => Navigator.of(ctx).pop(result),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
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

Widget _outlined(
  BuildContext ctx,
  String label,
  bool result, {
  required Key key,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: key,
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
}
