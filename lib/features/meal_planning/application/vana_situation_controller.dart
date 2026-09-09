import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/vana_situation.dart';

part 'vana_situation_controller.g.dart';

/// How long a reported screen still counts as "what they are looking at". Long
/// enough to cover reading a page and then opening Vana; short enough that a
/// screen from an hour ago never speaks for the athlete.
const vanaSituationTtl = Duration(minutes: 30);

/// Where Vana looks to find out what the athlete is looking at.
///
/// Screens in the table report as they come into view; the value rides the next
/// message and is never stored. Leaving a screen does NOT clear it: opening
/// Vana means leaving the screen you were asking about, and the Vana routes
/// report nothing, so the last reported screen is the right answer. A report
/// older than [vanaSituationTtl] reads as no Situation at all.
///
/// Kept alive: the screen that set it is underneath the sheet, not above it.
@Riverpod(keepAlive: true)
class VanaSituationController extends _$VanaSituationController {
  @override
  VanaSituation? build() => null;

  DateTime? _reportedAt;

  /// Called by a screen as it comes into view.
  void report(VanaSituation situation) {
    _reportedAt = DateTime.now();
    if (state != situation) state = situation;
  }

  /// Forgets the current screen — for a sign-out, or a screen that must not be
  /// spoken about at all.
  void clear() {
    _reportedAt = null;
    state = null;
  }

  /// What to send with a message: the reported screen, or null when the report
  /// has gone stale.
  VanaSituation? current({DateTime? now}) {
    final at = _reportedAt;
    if (at == null || state == null) return null;
    final age = (now ?? DateTime.now()).difference(at);
    return age.isNegative || age <= vanaSituationTtl ? state : null;
  }
}
