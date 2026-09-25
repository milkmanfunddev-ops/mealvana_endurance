import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A back button that always leads somewhere.
extension PopOrHome on BuildContext {
  /// Pops the page, or, when it is the only page (opened by a deep link, a
  /// `go`, or a web refresh), goes to the tab shell instead of doing nothing.
  void popOrHome() => canPop() ? pop() : go('/main');
}
