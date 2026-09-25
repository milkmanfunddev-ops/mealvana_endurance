// Carb-loading entryway engine — the published entry point for the
// carb-loading-entryway@v1 conformance vectors (qa tag f809f54, G7–G16).
//
// Implements spec/fueling/carb-loading-entryway.md RATIFIED v1 (CE-4/CE-4a
// feasibility-independent re-pick migration, CE-8 chooser feasibility gate,
// F3 target-protocol relabel DATA, F4 single-notice collapse), mirrored under
// docs/ssot/. Pure Dart: dates in, decisions out — the surfaces render what
// this returns; the copy register owns the strings (L2, not here).
//
// Oracle conventions (vectors/fueling/carb-loading-entryway.json): "edited"
// means stored carbTargetGrams != its protocol derivation at the current
// weight; daysUntilRace is a whole-day count with race morning == 0; plans
// list day targets first loading day first.

import 'carb_loading_pace_engine.dart';

/// What the re-pick flow must show before anything is written (CE-4 + F3/F4).
enum RepickDialogType {
  /// No effective edits — regenerate quietly, no dialog.
  none('none'),

  /// Edits survive into the new window — the exactly-two-choice dialog.
  keepReset('keep-reset'),

  /// Every edit falls outside the new window — the single-button notice.
  notice('notice');

  const RepickDialogType(this.wire);
  final String wire;
}

/// One edited day as the F3 dialog lists it: relabeled per the TARGET
/// protocol's window, with the date and the stored grams. DATA only — the
/// rendered string belongs to the copy register.
class RepickListedEdit {
  const RepickListedEdit({
    required this.date,
    required this.targetDayNumber,
    required this.storedG,
  });

  final DateTime date;

  /// 1-based day number of [date] within the TARGET protocol's window.
  final int targetDayNumber;

  final int storedG;
}

/// The full re-pick decision (CE-4): what dialog to show, what each choice
/// writes, and which edited dates the new window drops.
class RepickDecision {
  const RepickDecision({
    required this.dialogType,
    required this.listedEdits,
    required this.droppedDates,
    required this.keepPlanG,
    required this.resetPlanG,
  });

  final RepickDialogType dialogType;

  /// In-window edits, first loading day first (empty unless [dialogType] is
  /// [RepickDialogType.keepReset]).
  final List<RepickListedEdit> listedEdits;

  /// Edited dates that fall outside the target window — the dialog/notice
  /// must disclose these (Q-CL10: never a silent drop).
  final List<DateTime> droppedDates;

  /// Day targets written by "Keep my targets" (or by the quiet path / the
  /// notice's single button, where keep and reset coincide).
  final List<int> keepPlanG;

  /// Day targets written by "Reset to protocol" — the pure derivation.
  final List<int> resetPlanG;
}

/// CE-8 + CE-4 decision logic for the plan create/edit entryway.
class CarbLoadingEntrywayEngine {
  CarbLoadingEntrywayEngine._();

  static const List<int> allProtocols = <int>[3, 2, 1];

  /// CE-8: a protocol is choosable iff daysUntilRace >= protocolDays.
  /// Race morning (0) offers nothing — the entry row states the window has
  /// passed. Returned ascending (1-day first) per the vector convention.
  static List<int> choosableProtocols(int daysUntilRace) {
    final out = allProtocols
        .where((p) => daysUntilRace >= p)
        .toList(growable: false);
    return out.reversed.toList(growable: false);
  }

  /// CE-8: infeasible cards render disabled WITH the reason ("Needs N days
  /// before race day") — N is the protocol's day count.
  static bool isChoosable({
    required int daysUntilRace,
    required int protocolDays,
  }) => daysUntilRace >= protocolDays;

  /// CE-8: the no-plan entry row's state. On race morning nothing is
  /// choosable and the row states the loading window has passed; otherwise
  /// it offers setup. Wire values match the vector oracle.
  static String entryRowStateWire(int daysUntilRace) =>
      choosableProtocols(daysUntilRace).isEmpty ? 'window-passed' : 'set-up';

  /// The loading window: the [protocolDays] consecutive days ending the day
  /// before [raceDate], first loading day first.
  static List<DateTime> windowDates({
    required int protocolDays,
    required DateTime raceDate,
  }) {
    final race = DateTime(raceDate.year, raceDate.month, raceDate.day);
    return List<DateTime>.generate(
      protocolDays,
      (i) => race.subtract(Duration(days: protocolDays - i)),
      growable: false,
    );
  }

  /// Pure protocol derivation for every day of a protocol, first loading day
  /// first (CL-1..CL-3 via the pace engine).
  static List<int> derivedTargetsG({
    required int protocolDays,
    required double bodyWeightLb,
  }) => List<int>.generate(
    protocolDays,
    (i) => CarbLoadingPaceEngine.dayTargetG(
      bodyWeightLb: bodyWeightLb,
      protocolDays: protocolDays,
      daysBeforeRace: protocolDays - i,
    ),
    growable: false,
  );

  /// CE-4: diff the plan on a protocol selection.
  ///
  /// [storedTargetsByDate] holds the CURRENT plan's stored `carbTargetGrams`
  /// per day date. A stored value equal to its current-protocol derivation is
  /// NOT an edit. Migration is by DATE: edited dates inside the target window
  /// keep their stored grams under "Keep my targets"; dates outside are
  /// dropped with disclosure. When every edit falls outside, the dialog
  /// collapses to the single-button notice (F4) and both outcomes coincide
  /// with the derivation.
  static RepickDecision repick({
    required int currentProtocol,
    required Map<DateTime, int> storedTargetsByDate,
    required int targetProtocol,
    required double bodyWeightLb,
    required DateTime raceDate,
  }) {
    final currentWindow = windowDates(
      protocolDays: currentProtocol,
      raceDate: raceDate,
    );
    final currentDerived = derivedTargetsG(
      protocolDays: currentProtocol,
      bodyWeightLb: bodyWeightLb,
    );
    final targetWindow = windowDates(
      protocolDays: targetProtocol,
      raceDate: raceDate,
    );
    final resetPlan = derivedTargetsG(
      protocolDays: targetProtocol,
      bodyWeightLb: bodyWeightLb,
    );

    // Effective edits: stored != derivation, on a current-window date.
    final edits = <DateTime, int>{};
    for (var i = 0; i < currentWindow.length; i++) {
      final date = currentWindow[i];
      final stored = storedTargetsByDate[date];
      if (stored != null && stored != currentDerived[i]) {
        edits[date] = stored;
      }
    }

    if (targetProtocol == currentProtocol || edits.isEmpty) {
      return RepickDecision(
        dialogType: RepickDialogType.none,
        listedEdits: const <RepickListedEdit>[],
        droppedDates: const <DateTime>[],
        keepPlanG: resetPlan,
        resetPlanG: resetPlan,
      );
    }

    final listed = <RepickListedEdit>[];
    final dropped = <DateTime>[];
    final keepPlan = List<int>.of(resetPlan);
    for (final entry in edits.entries) {
      final idx = targetWindow.indexOf(entry.key);
      if (idx >= 0) {
        listed.add(
          RepickListedEdit(
            date: entry.key,
            targetDayNumber: idx + 1,
            storedG: entry.value,
          ),
        );
        keepPlan[idx] = entry.value;
      } else {
        dropped.add(entry.key);
      }
    }
    listed.sort((a, b) => a.targetDayNumber.compareTo(b.targetDayNumber));
    dropped.sort();

    if (listed.isEmpty) {
      // F4: nothing carries over — single-button notice; the only outcome is
      // the derivation.
      return RepickDecision(
        dialogType: RepickDialogType.notice,
        listedEdits: const <RepickListedEdit>[],
        droppedDates: dropped,
        keepPlanG: resetPlan,
        resetPlanG: resetPlan,
      );
    }
    return RepickDecision(
      dialogType: RepickDialogType.keepReset,
      listedEdits: listed,
      droppedDates: dropped,
      keepPlanG: List<int>.unmodifiable(keepPlan),
      resetPlanG: resetPlan,
    );
  }
}
