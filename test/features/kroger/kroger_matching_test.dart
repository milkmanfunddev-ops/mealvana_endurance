import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_matching.dart';
import 'package:mealvana_endurance/features/kroger/domain/kroger_models.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';

const plan = '11111111-1111-4111-8111-111111111111';
const milk = KrogerProduct(
  upc: '0001111040101',
  name: 'Milk',
  size: '1 l',
  available: true,
  price: 3,
);
ShoppingItem source({String qty = '2 l', bool have = false}) =>
    ShoppingItem(aisle: 'Dairy', name: 'Milk', qty: qty, have: have);
void main() {
  group('package conversion', () {
    for (final vector in <(String, String, int?)>[
      ('600 g', '1 lb', 2),
      ('1 kg', '500 g', 2),
      ('16 oz', '1 lb', 1),
      ('2 l', '500 ml', 4),
      ('32 fl oz', '1 l', 1),
      ('6 each', '12 ct', 1),
      ('1½ l', '500 ml', 3),
      ('1/2 kg', '250 g', 2),
      ('500 g + 1 kg', '500 g', 3),
      ('1 cup', '500 g', null),
      ('2 l', '1 kg', null),
      ('1', '6 x 8 oz', null),
      ('1/0 kg', '1 kg', null),
      ('0 g', '1 g', null),
      ('100 kg', '1 kg', null),
      ('1 banana', '1 lb', null),
      ('1 kg + 1 l', '1 kg', null),
    ]) {
      test(
        '${vector.$1} / ${vector.$2}',
        () => expect(KrogerMatching.packages(vector.$1, vector.$2), vector.$3),
      );
    }
  });
  test('stable IDs survive reorder and preserve reviewed choices', () {
    var draft = KrogerMatching.reconcile(const KrogerDraft(planId: plan), [
      source(),
    ]);
    draft = draft.copyWith(
      lines: [draft.lines.single.copyWith(product: milk, approved: true)],
    );
    final next = KrogerMatching.reconcile(draft, [source()]);
    expect(next.lines.single.id, draft.lines.single.id);
    expect(next.lines.single.approved, true);
  });
  test(
    'source quantity changes revoke approval but preserve manually edited counts',
    () {
      final line = KrogerLine(
        id: KrogerLine.sourceId(plan, 'Milk'),
        name: 'Milk',
        requiredQty: '2 l',
        product: milk,
        approved: true,
        quantity: 5,
        quantityEdited: true,
      );
      final next = KrogerMatching.reconcile(
        KrogerDraft(planId: plan, lines: [line]),
        [source(qty: '3 l')],
      );
      expect(next.lines.single.quantity, 5);
      expect(next.lines.single.approved, false);
      expect(next.lines.single.requiredQty, '3 l');
    },
  );
  test(
    'have and add-back propagate, manual skip survives unchanged source',
    () {
      var draft = KrogerMatching.reconcile(const KrogerDraft(planId: plan), [
        source(have: true),
      ]);
      expect(draft.lines.single.excluded, true);
      draft = KrogerMatching.reconcile(draft, [source()]);
      expect(draft.lines.single.excluded, false);
      draft = draft.copyWith(
        lines: [draft.lines.single.copyWith(excluded: true)],
      );
      expect(
        KrogerMatching.reconcile(draft, [source()]).lines.single.excluded,
        true,
      );
    },
  );
  test('removed source rows disappear, manually added rows survive', () {
    final draft = KrogerMatching.reconcile(
      const KrogerDraft(
        planId: plan,
        lines: [
          KrogerLine(
            id: 'manual',
            name: 'Coffee',
            requiredQty: '',
            manual: true,
          ),
        ],
      ),
      [source()],
    );
    expect(KrogerMatching.reconcile(draft, []).lines.single.name, 'Coffee');
  });
  test('export receipts freeze the historical snapshot', () {
    final draft = KrogerMatching.reconcile(const KrogerDraft(planId: plan), [
      source(),
    ]).copyWith(receiptStatus: 'unknown');
    expect(KrogerMatching.reconcile(draft, []).toJson(), draft.toJson());
    expect(draft.ready, false);
  });
  test(
    'ready requires explicit approval, availability, store and included rows',
    () {
      final draft = KrogerDraft(
        planId: plan,
        store: const KrogerStore(id: '1', name: 'Store', address: ''),
        lines: [
          KrogerLine(id: '1', name: 'Milk', requiredQty: '2 l', product: milk),
        ],
      );
      expect(draft.ready, false);
      final approved = draft.copyWith(
        lines: [draft.lines.single.copyWith(approved: true, quantity: 2)],
      );
      expect(approved.ready, true);
      expect(approved.estimate, 6);
      expect(
        approved
            .copyWith(lines: [approved.lines.single.copyWith(excluded: true)])
            .ready,
        false,
      );
      expect(
        KrogerDraft.fromJson(approved.toJson()).toJson(),
        approved.toJson(),
      );
    },
  );
}
