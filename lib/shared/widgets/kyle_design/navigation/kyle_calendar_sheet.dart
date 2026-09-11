/// Design SSOT component — **Calendar Sheet** (two-channel cells).
///
/// Spec: `docs/ssot/spec/design/components/calendar-sheet.md` **v1**
/// (RATIFIED Xuan 2026-09-06, ruling-desk block; ships as `home-shell@v1`).
/// Material: `docs/ssot/spec/design/tokens.md` §Materials — the sheet takes
/// `glass-sheet` INCLUDING its scrim (`blackberry` 60%, load-bearing, not
/// cosmetic); the Today pill and month chevrons take `glass`. Raw values
/// live in the tokens registry ([AppMaterials]) only. Companion artifact:
/// the archived home-shell export — illustrates; the spec governs; where
/// the intake and export disagreed (today/selected), the ruling names the
/// winner.
///
/// Contracts held here:
/// * **Cell anatomy is THREE FIXED SLOTS** — day number, dot slot, tint
///   slot — and the extension contract is that future features only ever
///   repaint the tint slot (ruled verbatim 2026-09-06).
/// * **Q1 dot ← workout state** (workout-card.md v3, cross-referenced):
///   PLANNED → hollow `orange` ring, 2 px stroke, visibly dark centre;
///   DONE_CONFIRMED/DONE_VERIFIED → the SAME filled `electrolyte` dot (no
///   per-source distinction at cell size); SKIPPED (active or passive) →
///   NO dot; rest day → no dot. Multi-workout/brick day: ONE dot, best
///   state wins. The state derivation itself is the caller's
///   (`resolveWorkoutCardState`) — this widget renders [CalendarDotState].
/// * **Q2 tint ← logged fueling, BINARY v1**: presence only, no intensity
///   scaling, no negative state, and NO `dragonfruit` anywhere on this
///   surface.
/// * **Today/selected (RULED — export governs, intake corrected):** today =
///   cream-FILLED cell; selected (non-today) = 2 px cream ring; selected ==
///   today = filled.
/// * **Gestures CS-1…CS-6:** one sheet from both DateHeader paths; grabber
///   pull past the threshold dismisses, a short pull SNAPS BACK (threshold
///   pinned by the gesture manifest, cs2 — never prose); scrim tap
///   dismisses; day tap navigates home to that date AND dismisses; month
///   chevrons/title navigate months with the sheet staying; Today pill
///   selects + navigates to the current day.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../materials/glass.dart';

/// The dot slot's render state — derived upstream from workout-card.md v3
/// states; SKIPPED and rest days both arrive here as [none].
enum CalendarDotState { none, planned, done }

/// One day cell's channel data.
class KyleCalendarDayData {
  const KyleCalendarDayData({
    this.dot = CalendarDotState.none,
    this.tinted = false,
  });

  final CalendarDotState dot;

  /// Binary v1: ≥ 1 athlete food log on the day (any source counts).
  final bool tinted;
}

/// The full-height summoned calendar sheet. Pure and data-driven — feature
/// code supplies the month's cell data and owns navigation side effects.
class KyleCalendarSheet extends StatefulWidget {
  const KyleCalendarSheet({
    super.key,
    required this.month,
    required this.today,
    required this.days,
    this.selected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
    required this.onTodayTap,
    required this.onDismiss,
  });

  /// First day of the shown month.
  final DateTime month;

  /// The current day (midnight-normalized).
  final DateTime today;

  /// Day-of-month → channel data; absent days render empty channels.
  final Map<int, KyleCalendarDayData> days;

  /// The selected day (midnight-normalized), if in view.
  final DateTime? selected;

  /// CS-5: month navigation; the sheet stays open.
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  /// CS-4: the caller navigates home to the date AND dismisses.
  final ValueChanged<DateTime> onDayTap;

  /// CS-6: the caller selects + navigates to the current day.
  final VoidCallback onTodayTap;

  /// CS-2 commit: the caller pops the route.
  final VoidCallback onDismiss;

  /// CS-2 grabber-pull commit threshold (px) — pinned in
  /// `home-shell.gestures.yaml` (cs2); a shorter pull snaps back.
  static const double dismissThresholdPx = 90.0;

  /// The sheet's top edge sits this far below the screen top.
  static const double topInset = 56.0;

  @override
  State<KyleCalendarSheet> createState() => _KyleCalendarSheetState();
}

class _KyleCalendarSheetState extends State<KyleCalendarSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapBack;
  double _dragY = 0;
  double _snapFrom = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _snapBack =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() {
          setState(() {
            _dragY =
                _snapFrom * (1 - Curves.easeOut.transform(_snapBack.value));
          });
        });
  }

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onGrabberDown(DragStartDetails d) {
    _snapBack.stop();
    setState(() => _dragging = true);
  }

  void _onGrabberMove(DragUpdateDetails d) {
    setState(() {
      final next = _dragY + d.delta.dy;
      // Upward pulls resist (export-exact 0.2 factor).
      _dragY = next >= 0 ? next : next * 0.2;
    });
  }

  void _onGrabberUp(DragEndDetails d) {
    setState(() => _dragging = false);
    if (_dragY > KyleCalendarSheet.dismissThresholdPx) {
      widget.onDismiss();
    } else {
      // CS-2 negative half: a short pull snaps back — the sheet stays open.
      _snapFrom = _dragY;
      _snapBack.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, _dragY),
      child: GlassSheetSurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabber(),
              _chrome(),
              const SizedBox(height: 22),
              _dowRow(),
              const SizedBox(height: 8),
              _grid(),
              const Spacer(),
              _todayPill(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grabber() {
    return GestureDetector(
      key: const ValueKey('kyle_calendar_sheet.grabber'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onGrabberDown,
      onVerticalDragUpdate: _onGrabberMove,
      onVerticalDragEnd: _onGrabberUp,
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _dragging ? 48 : 36,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: AppColors.cream.withValues(alpha: _dragging ? 0.6 : 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chrome() {
    final title = DateFormat('MMMM yyyy').format(widget.month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    key: const ValueKey('kyle_calendar_sheet.month_title'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.sansita,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      height: 1.15,
                      color: AppColors.cream,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.expand_more,
                    size: 15,
                    color: AppColors.cream.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          _monthChevron(
            key: const ValueKey('kyle_calendar_sheet.prev_month'),
            icon: Icons.chevron_left,
            label: 'Previous month',
            onTap: widget.onPreviousMonth,
          ),
          const SizedBox(width: 8),
          _monthChevron(
            key: const ValueKey('kyle_calendar_sheet.next_month'),
            icon: Icons.chevron_right,
            label: 'Next month',
            onTap: widget.onNextMonth,
          ),
        ],
      ),
    );
  }

  Widget _monthChevron({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cream.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 16, color: AppColors.cream),
        ),
      ),
    );
  }

  Widget _dowRow() {
    const labels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: TextStyle(
                  fontFamily: AppTextStyles.apercu,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.84,
                  color: AppColors.cream.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid() {
    final first = widget.month;
    final leading = first.weekday % 7; // Sunday-start
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox(),
      for (var d = 1; d <= daysInMonth; d++) _cell(d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }
    return Column(
      children: [
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: col == 0 ? 0 : 4),
                      child: cells[row * 7 + col],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int day) {
    final date = DateTime(widget.month.year, widget.month.month, day);
    final data = widget.days[day] ?? const KyleCalendarDayData();
    final isToday = _sameDay(date, widget.today);
    final isSelected =
        widget.selected != null && _sameDay(date, widget.selected!);
    return Semantics(
      button: true,
      label: 'Day $day',
      child: GestureDetector(
        key: ValueKey('kyle_calendar_sheet.day_$day'),
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onDayTap(date),
        child: KyleCalendarDayCell(
          day: day,
          data: data,
          isToday: isToday,
          isSelected: isSelected,
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _todayPill() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Semantics(
        button: true,
        label: 'Today',
        child: GestureDetector(
          key: const ValueKey('kyle_calendar_sheet.today_pill'),
          onTap: widget.onTodayTap,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(100),
            lift: true,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.cream, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'Today',
                      style: TextStyle(
                        fontFamily: AppTextStyles.sansita,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.cream,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day cell — the THREE FIXED SLOTS (number · dot · tint). Public so the
/// enlarged cell-spec card golden renders every treatment from the same
/// widget the sheet composes.
class KyleCalendarDayCell extends StatelessWidget {
  const KyleCalendarDayCell({
    super.key,
    required this.day,
    required this.data,
    this.isToday = false,
    this.isSelected = false,
    this.scale = 1.0,
  });

  final int day;
  final KyleCalendarDayData data;
  final bool isToday;
  final bool isSelected;

  /// Enlargement factor for the cell-spec card golden.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    // Today wins over selected (selected == today renders filled).
    final filled = isToday;
    final ringed = isSelected && !isToday;
    return Container(
      height: 60 * k,
      decoration: BoxDecoration(
        // Tint slot: BINARY v1 — presence paints the ratified warm glow,
        // absence keeps the plain ground. No dragonfruit on this surface.
        borderRadius: BorderRadius.circular(12 * k),
        color: data.tinted ? AppMaterials.calendarTintFill : null,
        border: data.tinted
            ? Border.all(color: AppMaterials.calendarTintRing)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Slot 1 — day number.
          Container(
            width: 30 * k,
            height: 30 * k,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(filled ? 9 * k : 15 * k),
              color: filled ? AppColors.cream : null,
              border: ringed
                  ? Border.all(
                      color: AppColors.cream,
                      width: AppMaterials.calendarSelectedRingStroke * k,
                    )
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontFamily: AppTextStyles.apercu,
                fontSize: 16 * k,
                fontWeight: (filled || ringed)
                    ? FontWeight.w500
                    : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: filled ? AppColors.blackberry : AppColors.cream,
              ),
            ),
          ),
          SizedBox(height: 4 * k),
          // Slot 2 — dot.
          SizedBox(
            height: AppMaterials.calendarDotPlannedDiameter * k,
            child: Center(child: _dot(k)),
          ),
        ],
      ),
    );
  }

  Widget _dot(double k) {
    switch (data.dot) {
      case CalendarDotState.none:
        return const SizedBox.shrink();
      case CalendarDotState.planned:
        // Hollow orange ring, 2 px stroke, visibly dark centre (Q1 round-2
        // fix — 1 px reads solid at cell size).
        return Container(
          width: AppMaterials.calendarDotPlannedDiameter * k,
          height: AppMaterials.calendarDotPlannedDiameter * k,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.blackberry,
            border: Border.all(
              color: AppColors.orange,
              width: AppMaterials.calendarDotPlannedStroke * k,
            ),
          ),
        );
      case CalendarDotState.done:
        return Container(
          width: AppMaterials.calendarDotDoneDiameter * k,
          height: AppMaterials.calendarDotDoneDiameter * k,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.electrolyte,
          ),
        );
    }
  }
}
