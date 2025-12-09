import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarSelectedDateProvider = NotifierProvider<CalendarSelectedDate, DateTime>(CalendarSelectedDate.new);

class CalendarSelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setDate(DateTime date) {
    state = date;
  }
}
