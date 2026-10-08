import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A request to show a `/main` shell destination, raised from a screen
/// pushed ABOVE the shell.
///
/// The shell ([TabsScreen]) owns its selected index locally: `/main?tab=`
/// only seeds it on first build and `popUntil(isFirst)` leaves whichever
/// tab was last shown. Neither can switch a shell that is already mounted,
/// which is what a cross-feature CTA needs (carb-loading-entryway.md CE-3:
/// "Go to today's fuel" → the dashboard timeline). The shell listens here
/// and switches.
///
/// State is the last requested index, null before any request. Every
/// [select] notifies, even a repeat of the same index, so a request lands
/// regardless of what the shell happens to be showing.
final homeShellTabRequestProvider = NotifierProvider<HomeShellTabRequest, int?>(
  HomeShellTabRequest.new,
);

class HomeShellTabRequest extends Notifier<int?> {
  /// The Fuel Timeline destination (tab 0 on every platform).
  static const int timeline = 0;

  @override
  int? build() => null;

  void select(int index) => state = index;

  @override
  bool updateShouldNotify(int? previous, int? next) => true;
}
