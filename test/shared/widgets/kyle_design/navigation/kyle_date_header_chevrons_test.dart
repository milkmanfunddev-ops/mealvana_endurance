// Finding 117-004: the day chevrons sit in fixed slots. The "Next day" arrow
// used to trail the title, so its x moved with the day name's width and a
// tap at yesterday's position hit the title (and summoned the month picker).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_date_header.dart';

void main() {
  final now = DateTime(2026, 9, 26, 10);

  Future<Rect> nextChevronRect(WidgetTester tester, DateTime date) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: KyleDateHeader(
              date: date,
              compact: false,
              now: now,
              onSummonCalendar: () {},
              onSettingsTap: () {},
              onPreviousDay: () {},
              onNextDay: () {},
            ),
          ),
        ),
      ),
    );
    return tester.getRect(
      find.byKey(const ValueKey('kyle_date_header.next_day')),
    );
  }

  testWidgets('the Next day chevron stays put while the title changes', (
    tester,
  ) async {
    final onToday = await nextChevronRect(tester, DateTime(2026, 9, 26));
    final onSunday = await nextChevronRect(tester, DateTime(2026, 9, 20));
    final onWednesday = await nextChevronRect(tester, DateTime(2026, 9, 2));

    expect(onSunday.left, onToday.left);
    expect(onWednesday.left, onToday.left);
  });

  testWidgets('the Previous day chevron stays put too', (tester) async {
    Future<Rect> prev(DateTime date) async {
      await nextChevronRect(tester, date);
      return tester.getRect(
        find.byKey(const ValueKey('kyle_date_header.prev_day')),
      );
    }

    expect(
      (await prev(DateTime(2026, 9, 20))).left,
      (await prev(DateTime(2026, 9, 26))).left,
    );
  });
}
