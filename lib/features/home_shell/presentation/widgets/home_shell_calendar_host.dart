/// The calendar sheet's summoning host — `home-shell@v1`.
///
/// One sheet, one state (date-header.md summon parity): both DateHeader
/// paths call [showHomeShellCalendarSheet]. The host owns the shown month
/// and feeds the pure [KyleCalendarSheet] from
/// [homeShellCalendarMonthProvider]; the scrim between the page and the
/// sheet is the ratified `blackberry` 60% ([AppMaterials.sheetScrim] —
/// load-bearing, not cosmetic).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/navigation/kyle_calendar_sheet.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../providers/home_shell_providers.dart';

/// Summon the calendar sheet (CS-1). Day tap navigates home to the date and
/// dismisses (CS-4); scrim tap dismisses (CS-3); grabber pull past the
/// pinned threshold dismisses, short pulls snap back (CS-2).
Future<void> showHomeShellCalendarSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false, // CS-2 is the grabber's own gesture, not the route's
    barrierColor: AppMaterials.sheetScrim,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SizedBox(
      height:
          MediaQuery.of(sheetContext).size.height -
          KyleCalendarSheet.topInset,
      child: const HomeShellCalendarHost(),
    ),
  );
}

class HomeShellCalendarHost extends ConsumerStatefulWidget {
  const HomeShellCalendarHost({super.key, this.now});

  /// Injectable wall clock for tests; defaults to [DateTime.now].
  final DateTime? now;

  @override
  ConsumerState<HomeShellCalendarHost> createState() =>
      _HomeShellCalendarHostState();
}

class _HomeShellCalendarHostState extends ConsumerState<HomeShellCalendarHost> {
  late DateTime _month;

  DateTime get _today {
    final now = widget.now ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final selected = ref.read(calendarSelectedDateProvider);
    _month = DateTime(selected.year, selected.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(calendarSelectedDateProvider);
    final daysAsync = ref.watch(homeShellCalendarMonthProvider(_month));
    // Never render silently empty channels: a failed derivation logs loudly
    // (no assert — seam rule: tolerate + log, the invariant lives in tests).
    if (daysAsync is AsyncError) {
      debugPrint(
        'home_shell: calendar month derivation failed for $_month: '
        '${(daysAsync as AsyncError).error}',
      );
    }
    return KyleCalendarSheet(
      month: _month,
      today: _today,
      selected: selected,
      days: daysAsync.asData?.value ?? const {},
      // CS-5: month navigation, sheet stays.
      onPreviousMonth: () => setState(() {
        _month = DateTime(_month.year, _month.month - 1, 1);
      }),
      onNextMonth: () => setState(() {
        _month = DateTime(_month.year, _month.month + 1, 1);
      }),
      // CS-4: home navigates to the date AND the sheet dismisses — one
      // combined contract.
      onDayTap: (date) {
        ref.read(calendarSelectedDateProvider.notifier).setDate(date);
        Navigator.of(context).pop();
      },
      // CS-6: select + navigate to the current day (the sheet stays, month
      // jumps into view).
      onTodayTap: () {
        final today = _today;
        ref.read(calendarSelectedDateProvider.notifier).setDate(today);
        setState(() => _month = DateTime(today.year, today.month, 1));
      },
      onDismiss: () => Navigator.of(context).pop(),
    );
  }
}
