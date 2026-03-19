import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/app_date_picker.dart';

void main() {
  test('dialog size uses min width floor for narrow screens', () {
    final size = appDatePickerDialogSizeForWidth(320);

    expect(size.width, 325);
    expect(size.height, 400);
  });

  test('dialog size scales on medium screens', () {
    final size = appDatePickerDialogSizeForWidth(390);

    expect(size.width, 366);
    expect(size.height, 400);
  });

  test('dialog size caps width on large screens', () {
    final size = appDatePickerDialogSizeForWidth(500);

    expect(size.width, 420);
    expect(size.height, 400);
  });
}
