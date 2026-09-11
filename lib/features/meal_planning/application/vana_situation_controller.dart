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
/// The route on top ([routeOnTop], told by the Vana launcher's host on every
/// router change except onto a Vana route) decides which report counts: a
/// report counts while the route it was made under is on top. Any other
/// screen speaks as its route and nothing else, so the sheet opened over
/// settings is not told the athlete is still on the fuel log.
///
/// Kept alive: the screen that set it is underneath the sheet, not above it.
@Riverpod(keepAlive: true)
class VanaSituationController extends _$VanaSituationController {
  @override
  VanaSituation? build() => null;

  /// The router's top route pattern, when a host has said.
  String? _top;

  /// The newest report under each top route pattern, and when it was made.
  final Map<String?, (VanaSituation, DateTime)> _reports = {};

  /// Called by a screen as it comes into view.
  void report(VanaSituation situation) {
    _reports[_top] = (situation, DateTime.now());
    if (state != situation) state = situation;
  }

  /// Called on every router change with the top route's pattern (e.g.
  /// `/food/meals/:id`). Not for the Vana routes, which speak for no screen.
  void routeOnTop(String route) => _top = route;

  /// Forgets the current screen — for a sign-out, or a screen that must not be
  /// spoken about at all.
  void clear() {
    _top = null;
    _reports.clear();
    state = null;
  }

  /// What to send with a message: the report made under the route on top, or
  /// that route alone when it reported nothing; null when a report has gone
  /// stale and no route is known.
  VanaSituation? current({DateTime? now}) {
    final entry = _reports[_top];
    if (entry != null) {
      final (situation, at) = entry;
      final age = (now ?? DateTime.now()).difference(at);
      if (age.isNegative || age <= vanaSituationTtl) return situation;
    }
    final top = _top;
    return top == null ? null : VanaSituation.route(top);
  }
}
