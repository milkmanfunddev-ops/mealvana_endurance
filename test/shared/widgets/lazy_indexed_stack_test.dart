// LazyIndexedStack: a tab shell that builds a tab's child the first time it is
// selected and keeps it alive afterwards (ai-cost ticket 03, mp-468).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/lazy_indexed_stack.dart';

/// Counts how many times its build ran, and holds a scroll view whose
/// position we can read back.
class _Probe extends StatefulWidget {
  const _Probe({required this.label, required this.builds});

  final String label;
  final Map<String, int> builds;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.builds[widget.label] = (widget.builds[widget.label] ?? 0) + 1;
    return ListView.builder(
      key: ValueKey('list.${widget.label}'),
      controller: controller,
      itemCount: 100,
      itemBuilder: (_, i) =>
          SizedBox(height: 50, child: Text('${widget.label}$i')),
    );
  }
}

Widget _host(int index, Map<String, int> builds, List<String> labels) =>
    MaterialApp(
      home: Scaffold(
        body: LazyIndexedStack(
          index: index,
          itemCount: labels.length,
          itemBuilder: (_, i) => _Probe(label: labels[i], builds: builds),
        ),
      ),
    );

void main() {
  const labels = ['a', 'b', 'c'];

  testWidgets('builds only the selected child on first render', (tester) async {
    final builds = <String, int>{};
    await tester.pumpWidget(_host(0, builds, labels));
    await tester.pumpAndSettle();

    expect(builds['a'], isNotNull);
    expect(builds['b'], isNull);
    expect(builds['c'], isNull);
  });

  testWidgets('builds a child the first time it is selected', (tester) async {
    final builds = <String, int>{};
    await tester.pumpWidget(_host(0, builds, labels));
    await tester.pumpAndSettle();
    expect(builds['c'], isNull);

    await tester.pumpWidget(_host(2, builds, labels));
    await tester.pumpAndSettle();
    expect(builds['c'], isNotNull);
    // Still never built the one never selected.
    expect(builds['b'], isNull);
  });

  testWidgets('a visited child keeps its scroll position and state', (
    tester,
  ) async {
    final builds = <String, int>{};
    await tester.pumpWidget(_host(0, builds, labels));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('list.a')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    final scrolled = tester
        .state<_ProbeState>(find.byType(_Probe))
        .controller
        .offset;
    expect(scrolled, greaterThan(0));

    // Leave and come back.
    await tester.pumpWidget(_host(1, builds, labels));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(0, builds, labels));
    await tester.pumpAndSettle();

    final after = tester
        .state<_ProbeState>(
          find.byWidgetPredicate((w) => w is _Probe && w.label == 'a'),
        )
        .controller
        .offset;
    expect(after, scrolled);
  });
}
