/// Design SSOT component — **Date Header**.
///
/// Spec: `docs/ssot/spec/design/components/date-header.md` **v1** (RATIFIED
/// Xuan 2026-09-06, ruling-desk block; ships as `home-shell@v1`). Material:
/// `docs/ssot/spec/design/tokens.md` §Materials — the COMPACT row carries
/// NO material of its own; only its circular buttons take the `glass`
/// recipe (RULED Xuan 2026-09-06 #2, on-device review — reverses the
/// same-day row-takes-glass ruling; the export's blur-14 fade stays
/// superseded, and no band replaces it). Companion artifact: the archived
/// home-shell export — illustrates; the spec governs.
///
/// Contracts held here:
/// * **Q1 states** — `REST`: one Sansita page-title line, tappable, gear
///   right. Title copy: "Today, {Month D} ˅" on the current day,
///   "{Weekday}, {Month D} ˅" otherwise (weekday variant pinned
///   2026-09-06 — the weekday replaces "Today", nothing else changes).
///   `COMPACT`: sticky bandless row — floating glass calendar button left,
///   centred short date ("Aug 31, 2026"), floating glass gear right;
///   content scrolls under the buttons and the date directly. Scroll
///   thresholds are the composing screen's, pinned by
///   `home-shell.gestures.yaml` (dh3), never prose.
/// * **Summon parity (RULED)** — the REST title tap and the COMPACT
///   calendar button summon the SAME calendar sheet: both paths call the
///   one [onSummonCalendar].
/// * **Q2 chevrons** — slim ‹ › flank the REST title, one-tap
///   yesterday/tomorrow; a chevron tap never summons the sheet. Hard
///   constraint (held by the composing screen, dh5): NO screen-level
///   horizontal swipe over the timeline — horizontal gestures there belong
///   to the workout card's G1–G4 set.
/// * **Q3** — the ViewTabs + WeekStrip block leaves the surface; that
///   recomposition is the surface's (macro-dashboard.md §home-shell
///   recomposition).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../materials/glass.dart';

/// The home shell's date header. Compose it at the top of the screen; drive
/// [compact] from the scroll position.
class KyleDateHeader extends StatelessWidget {
  const KyleDateHeader({
    super.key,
    required this.date,
    required this.compact,
    required this.onSummonCalendar,
    required this.onSettingsTap,
    required this.onPreviousDay,
    required this.onNextDay,
    this.now,
  });

  /// The day the home surface is showing (midnight-normalized upstream).
  final DateTime date;

  /// Q1 COMPACT when the screen is scrolled past its pinned threshold.
  final bool compact;

  /// The ONE summon path (summon parity): REST title tap and COMPACT
  /// calendar button both call this.
  final VoidCallback onSummonCalendar;

  final VoidCallback onSettingsTap;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  /// Injectable wall clock for tests; defaults to [DateTime.now].
  final DateTime? now;

  static const double compactRowHeight = 64.0;

  /// REST title copy — dh6 register: exactly "Today, {Month D}" on the
  /// current day, "{Weekday}, {Month D}" otherwise (the ˅ renders as the
  /// summon glyph beside it).
  static String titleCopy(DateTime date, DateTime today) {
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final monthDay = DateFormat('MMMM d').format(date);
    return isToday
        ? 'Today, $monthDay'
        : '${DateFormat('EEEE').format(date)}, $monthDay';
  }

  /// COMPACT centred short date — "Aug 31, 2026".
  static String shortCopy(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: compact ? _compactRow(context) : _restRow(context),
    );
  }

  // ---- REST ----
  Widget _restRow(BuildContext context) {
    final today = now ?? DateTime.now();
    final title = titleCopy(date, DateTime(today.year, today.month, today.day));
    return Padding(
      key: const ValueKey('kyle_date_header.rest'),
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 2),
      child: Row(
        children: [
          // The title cluster owns all space up to the gear, so the title
          // only ever truncates when genuinely out of room.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chevron(
                  key: const ValueKey('kyle_date_header.prev_day'),
                  icon: Icons.chevron_left,
                  label: 'Previous day',
                  onTap: onPreviousDay,
                ),
                Flexible(
                  child: Semantics(
                    button: true,
                    label: '$title ˅',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('kyle_date_header.title'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onSummonCalendar,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: const TextStyle(
                                fontFamily: AppTextStyles.sansita,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                height: 1.15,
                                color: AppColors.cream,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.expand_more,
                              size: 16,
                              color: AppColors.cream.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _chevron(
                  key: const ValueKey('kyle_date_header.next_day'),
                  icon: Icons.chevron_right,
                  label: 'Next day',
                  onTap: onNextDay,
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Settings',
            child: GestureDetector(
              key: const ValueKey('kyle_date_header.settings'),
              behavior: HitTestBehavior.opaque,
              onTap: onSettingsTap,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: AppColors.cream.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chevron({
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
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 34,
          child: Icon(
            icon,
            size: 22,
            color: AppColors.cream.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  // ---- COMPACT ----
  Widget _compactRow(BuildContext context) {
    // RULED (Xuan, 2026-09-06 #2, on-device review — reverses the same-day
    // row-takes-glass ruling): the compact row carries NO material of its
    // own; only its circular buttons take the glass recipe. No band, no
    // fade — content scrolls under the floating buttons and the date.
    return SizedBox(
      key: const ValueKey('kyle_date_header.compact'),
      height: compactRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            _glassCircleButton(
              key: const ValueKey('kyle_date_header.calendar_button'),
              label: 'Pick a day',
              icon: Icons.calendar_today_outlined,
              onTap: onSummonCalendar,
            ),
            Expanded(
              child: Center(
                child: Text(
                  shortCopy(date),
                  style: const TextStyle(
                    fontFamily: AppTextStyles.sansita,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.cream,
                  ),
                ),
              ),
            ),
            _glassCircleButton(
              key: const ValueKey('kyle_date_header.compact_settings'),
              label: 'Settings',
              icon: Icons.settings_outlined,
              onTap: onSettingsTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCircleButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        // Floating chrome over the page (the compact row carries no material
        // of its own — RULED Xuan 2026-09-06 #2): full glass recipe + lift.
        child: GlassSurface(
          borderRadius: BorderRadius.circular(23),
          lift: true,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 19, color: AppColors.cream),
          ),
        ),
      ),
    );
  }
}
