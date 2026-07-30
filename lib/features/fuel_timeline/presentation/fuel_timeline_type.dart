import 'package:flutter/widgets.dart';

/// Typography for the Fuel Timeline, matching the mockup with the app's own
/// brand fonts (Sansita / Compadre / Compadre Wide / Apercu — all bundled).
///
/// Colours are applied per use-site via `.copyWith(color:)` so the same style
/// can render a cream label or an orange number. Sizes/weights mirror
/// `docs/features/new_activity/FUEL_TIMELINE_SPEC.md`.
abstract final class FtType {
  static const _sansita = 'Sansita';
  static const _compadre = 'Compadre';
  static const _compadreWide = 'Compadre Wide';
  static const _apercu = 'Apercu';

  // ── Header ──────────────────────────────────────────────────────────────
  static const byWeek = TextStyle(
    fontFamily: _compadreWide,
    fontSize: 14,
    letterSpacing: 1.8,
    height: 1.0,
  );
  static const monthTitle = TextStyle(
    fontFamily: _sansita,
    fontWeight: FontWeight.w700,
    fontSize: 19,
    height: 1.0,
  );
  static const dayLetter = TextStyle(fontFamily: _apercu, fontSize: 12);
  static const dayNumber = TextStyle(
    fontFamily: _compadre,
    fontSize: 18,
    height: 1.0,
  );

  // ── Energy dashboard / sheets ───────────────────────────────────────────
  /// Small uppercase eyebrow label (INTAKE / BURNED / ENERGY BALANCE …).
  static const eyebrow = TextStyle(
    fontFamily: _apercu,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    letterSpacing: 0.8,
    height: 1.3,
  );
  static const bigNumber = TextStyle(
    fontFamily: _sansita,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.0,
  );
  static const kcalSuffix = TextStyle(fontFamily: _apercu, fontSize: 11);
  static const targetSuffix = TextStyle(fontFamily: _apercu, fontSize: 12);
  static const miniLabel = TextStyle(fontFamily: _apercu, fontSize: 10.5);
  static const miniValue = TextStyle(fontFamily: _apercu, fontSize: 13);
  static const breakdownBtn = TextStyle(
    fontFamily: _apercu,
    fontWeight: FontWeight.w500,
    fontSize: 11,
  );

  // ── Filters / add buttons ───────────────────────────────────────────────
  static const pill = TextStyle(
    fontFamily: _apercu,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
  );
  static const addButton = TextStyle(
    fontFamily: _apercu,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
  );

  // ── Timeline ────────────────────────────────────────────────────────────
  static const timeLabel = TextStyle(fontFamily: _apercu, fontSize: 10.5);
  // Food + activity titles use Compadre Wide in caps (per Kyle's style guide).
  static const itemName = TextStyle(
    fontFamily: _compadreWide,
    fontSize: 13.5,
    letterSpacing: 0.3,
    height: 1.15,
  );
  static const workoutName = TextStyle(
    fontFamily: _compadreWide,
    fontSize: 15,
    letterSpacing: 0.3,
    height: 1.1,
  );
  // Macro/kcal numbers read bold per the mockup.
  static const macroLine = TextStyle(
    fontFamily: _apercu,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
  static const cardAction = TextStyle(fontFamily: _apercu, fontSize: 12);

  // ── Sheets ──────────────────────────────────────────────────────────────
  static const sheetTitle = TextStyle(
    fontFamily: _sansita,
    fontWeight: FontWeight.w700,
    fontSize: 17,
  );
  static const sheetBig = TextStyle(
    fontFamily: _sansita,
    fontWeight: FontWeight.w700,
    fontSize: 42,
    height: 1.0,
  );
  static const sheetTargetLabel = TextStyle(
    fontFamily: _sansita,
    fontWeight: FontWeight.w700,
    fontSize: 20,
  );
  static const macroChip = TextStyle(
    fontFamily: _sansita,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.0,
  );
  static const body = TextStyle(fontFamily: _apercu, fontSize: 13, height: 1.5);
  static const tab = TextStyle(
    fontFamily: _apercu,
    fontWeight: FontWeight.w500,
    fontSize: 13,
  );
}
