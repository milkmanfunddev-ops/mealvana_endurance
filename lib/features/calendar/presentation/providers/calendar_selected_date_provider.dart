import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/supabase_auth_service.dart' as supabase_auth;

final calendarSelectedDateProvider =
    NotifierProvider<CalendarSelectedDate, DateTime>(CalendarSelectedDate.new);

/// The day the home surface shows. App-wide, but scoped to the signed-in
/// user: a sign-out, a sign-in or a new account rebuilds it to today
/// (Finding 117-010: the day last viewed before a sign-out survived into
/// the next session and into a brand-new account).
class CalendarSelectedDate extends Notifier<DateTime> {
  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  DateTime build() {
    // Only the user's identity matters here: a token refresh for the same
    // user must not yank the athlete back to today mid-browse.
    ref.watch(
      supabase_auth.currentUserProvider.select((auth) => auth.value?.id),
    );
    return _normalize(DateTime.now());
  }

  void setDate(DateTime date) {
    state = _normalize(date);
  }
}
