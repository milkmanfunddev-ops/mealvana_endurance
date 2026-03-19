import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

void main() {
  testWidgets('does not crash when navigator cannot pop', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CustomAppBarBackButton())),
      ),
    );

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(CustomAppBarBackButton), findsOneWidget);
  });

  testWidgets('pops when navigator can pop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: Center(child: CustomAppBarBackButton()),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open child'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomAppBarBackButton), findsOneWidget);

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Open child'), findsOneWidget);
  });
}
