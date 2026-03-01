import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarSelectedDateProvider =
    NotifierProvider<CalendarSelectedDate, DateTime>(CalendarSelectedDate.new);

class CalendarSelectedDate extends Notifier<DateTime> {
  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  DateTime build() {
    return _normalize(DateTime.now());
  }

  void setDate(DateTime date) {
    state = _normalize(date);
  }
}
