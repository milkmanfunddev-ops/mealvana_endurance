// PRODUCER-SHAPED fixtures for the G25 seam — extracted VERBATIM from the
// dev sim's synced local DB (2026-09-25 snapshot): the 27 curated
// carb_loading_foods rows and the 31 foods-mirror rows, exactly as the
// shipping sync paths wrote them. Regenerate from a fresh sim snapshot if
// the server seed changes; never hand-tune values.

class CuratedRowFixture {
  const CuratedRowFixture(
      this.id, this.name, this.displayName, this.carbs, this.mealTypes);
  final String id;
  final String name;
  final String displayName;
  final double carbs;
  final String? mealTypes;
}

class FoodRowFixture {
  const FoodRowFixture(this.id, this.name, this.displayName,
      this.servingSize, this.calories, this.carbs, this.protein, this.fat);
  final String id;
  final String? name;
  final String? displayName;
  final String? servingSize;
  final int? calories;
  final double? carbs;
  final double? protein;
  final double? fat;
}

const curatedRowFixtures = <CuratedRowFixture>[
  CuratedRowFixture('55caac1c-af8e-4d81-b588-5f5f4a52f319', 'apple', 'Apple (1 medium)', 25.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('a3aec83f-7792-402a-99ad-b0d38a3a5565', 'bagel', 'Bagel (1 large)', 72.0, '{breakfast}'),
  CuratedRowFixture('81aeb1f0-5607-48cc-8e17-e9c133649cd8', 'baked_potato', 'Baked potato (1 large)', 63.0, '{dinner,lunch}'),
  CuratedRowFixture('e421a6d5-bd25-4049-aabf-84ed85919a93', 'banana', 'Banana (1 medium)', 27.0, '{afternoon_snack,breakfast,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('1fd97d99-3005-498f-9e7a-d7a9806e3197', 'beet_juice', 'Beet juice (1 cup)', 18.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('2e027ba9-c6d3-4889-a719-9cbb9d02d64d', 'beets', 'Beets (1 medium)', 8.0, '{dinner,lunch}'),
  CuratedRowFixture('b28f9929-9b71-4158-8a4c-d5929d4ddf8f', 'berries', 'Berries (1 cup)', 22.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('90e9cbfe-dc60-440d-b09b-e3ef530a9fd4', 'cereal', 'Cereal (1/2 cup dry)', 14.0, '{breakfast}'),
  CuratedRowFixture('02712706-77c9-4929-8ba7-5b6aa552c71f', 'dates', 'Dates (1 pair)', 11.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('50e013ba-90e8-42bf-8558-974af7f4a744', 'energy_gel', 'Energy gel (1 packet)', 25.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('65ee4f54-28ed-42bf-9bb7-2a01345649dd', 'fig_bar', 'Fig bar (twin-pack)', 26.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('9dcc9a52-32ea-4bc7-9e06-416da5109147', 'graham_crackers', 'Graham crackers (2 sheets)', 23.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('89bf106c-7c65-420f-8ca9-f03c1731e703', 'oats', 'Oats (1/2 cup)', 14.0, '{breakfast}'),
  CuratedRowFixture('c4f6cf4e-cac6-4e4d-9e43-5ae5a1933e7e', 'orange_juice', 'Orange juice (1 cup)', 27.0, '{breakfast}'),
  CuratedRowFixture('a195992e-32fd-4ec0-aacc-c88d126dbdae', 'pancake', 'Pancake (1 medium)', 18.0, '{breakfast}'),
  CuratedRowFixture('e2c57e8b-77b8-40f9-a5fa-46a6c2ead01b', 'pasta_marinara', 'Pasta with marinara (1 cup)', 62.0, '{dinner,lunch}'),
  CuratedRowFixture('97d8294a-840f-4fa1-b754-d97a0c154edd', 'pizza', 'Pizza (1 slice)', 33.0, '{dinner,lunch}'),
  CuratedRowFixture('206e9ca8-1124-47d1-8609-376a8c1032a1', 'pretzels', 'Pretzels (1 oz)', 23.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('ead9e0a6-bd58-42e6-b8b1-dffa43152f01', 'rice', 'Rice (1 cup cooked)', 45.0, '{dinner,lunch}'),
  CuratedRowFixture('dee10dca-e2c6-4979-a43e-0f5f14abcd31', 'rice_pudding', 'Rice pudding (1/2 cup)', 30.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('da52109a-da1b-4703-93a7-daa87a513d4d', 'saltines', 'Saltines (10 crackers)', 22.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('fb8661c3-eba0-42f9-9968-0d65fffb3d04', 'sandwich', 'Sandwich (1 medium)', 30.0, '{dinner,lunch}'),
  CuratedRowFixture('c5342926-88df-4be5-8f25-b77522bd5cfc', 'smoothie', 'Smoothie (1 cup)', 26.0, '{breakfast}'),
  CuratedRowFixture('a147b02a-8c2e-4303-bbed-3199756a7f49', 'sports_drink', 'Sports drink (1 cup)', 16.0, '{afternoon_snack,evening_snack,morning_snack,snacks}'),
  CuratedRowFixture('1b03a617-8f2c-4432-97f2-36f79c2906d5', 'sweet_potato', 'Sweet potato (1 medium)', 25.0, '{dinner,lunch}'),
  CuratedRowFixture('364dd05f-1918-4686-83e8-493e6a52527c', 'toast', 'Toast (1 slice)', 13.0, '{breakfast}'),
  CuratedRowFixture('65b8e926-69e7-4744-9b79-8f6cade45111', 'waffle', 'Waffle (1 medium)', 32.0, '{breakfast}'),
];

const foodRowFixtures = <FoodRowFixture>[
  FoodRowFixture('429418b7-6580-4a7a-a542-c27fd8130a5c', 'Apple', 'apple', null, 95, 25.0, 0.5, 0.3),
  FoodRowFixture('312f4fca-ca55-47a2-aa2f-afa24cd64ef4', 'Applesauce / fruit purée pouch', 'applesauce / fruit purée pouch', null, 60, 14.0, 0.0, 0.0),
  FoodRowFixture('f7f21b39-c153-4c44-b6e5-a7497178d9fb', 'Bagel (plain)', 'plain bagel', null, 250, 48.0, 9.0, 1.5),
  FoodRowFixture('6b18db01-4073-466a-87fd-89018f02e9f4', 'Bananas', 'banana', null, 105, 27.0, 1.0, 0.0),
  FoodRowFixture('2b25abeb-1227-43e7-9df5-48e6634e668f', 'Berries', 'cup of berries', null, 70, 17.0, 1.0, 0.5),
  FoodRowFixture('f916b29f-cfe3-4cf5-9362-6b1967e3bdca', 'Chocolate milk', 'cup chocolate milk', null, 208, 26.0, 8.0, 8.0),
  FoodRowFixture('d18f3c8a-1dfd-494b-a3bd-6a817fe6cace', 'Coconut water', 'cup coconut water', null, 44, 9.0, 2.0, 0.0),
  FoodRowFixture('3221593d-cac7-4571-937f-3b2329ee3e0b', 'Coffee', 'cup of coffee', null, 0, 0.0, 0.0, 0.0),
  FoodRowFixture('ae2611c5-63d8-434c-9a11-274ec8439c1e', 'Dates', 'pair of dates', null, 72, 18.0, 0.0, 0.0),
  FoodRowFixture('1046a183-9f3a-40e9-add6-4baf092826cc', 'Electrolyte drink mix (electrolyte-only)', 'serving electrolyte drink mix (electrolyte-only)', null, 0, 0.0, 0.0, 0.0),
  FoodRowFixture('9fd63557-c41b-4fc6-a7f5-884582c282ed', 'Electrolyte tablet (electrolyte-only)', 'electrolyte tablet', null, 0, 0.0, 0.0, 0.0),
  FoodRowFixture('43f39d86-8a2c-4139-887e-b2af95ddca78', 'Energy bar', 'energy bar', null, 180, 28.0, 8.0, 6.0),
  FoodRowFixture('e5a24d1a-51f0-4e66-8786-51e2a127d01a', 'Energy chews', 'package energy chews', null, 108, 24.0, 0.0, 0.0),
  FoodRowFixture('be5256da-7cd3-40c5-802b-8e2ac6ead338', 'Energy waffle (stroopwafel-style)', 'energy waffle (stroopwafel-style)', null, 150, 21.0, 1.0, 7.0),
  FoodRowFixture('92a116e8-61f4-4a4f-b8b6-5954757a3f18', 'Fig bar', 'twin-pack fig bar', null, 200, 38.0, 3.0, 6.0),
  FoodRowFixture('17459c26-52b9-424a-aba2-da761aa12eee', 'Gels', 'Gel', null, 90, 22.0, 0.0, 0.0),
  FoodRowFixture('2ed43f0f-98dc-4534-81b1-a54265b30a3d', 'Oatmeal', 'cup oatmeal', null, 166, 30.0, 5.0, 3.0),
  FoodRowFixture('e7d229dd-adb0-4862-b913-c23ddd345e91', 'Orange juice', 'cup orange juice', null, 112, 26.0, 2.0, 0.0),
  FoodRowFixture('058cdc7c-d41f-4276-a9fd-b725d7ab8137', 'Peanut butter', 'tablespoon of peanut butter ', null, 95, 3.5, 4.0, 8.0),
  FoodRowFixture('41109851-ea1b-40a3-bca0-41534b6c4181', 'Pickle juice shot', 'pickle juice shot', null, 0, 0.0, 0.0, 0.0),
  FoodRowFixture('2d0a8b80-4c4e-45fb-83fa-85f074c98055', 'Pretzels (salted minis)', 'serving pretzels (salted minis)', null, 110, 23.0, 2.0, 1.0),
  FoodRowFixture('c02c4b94-ef83-4fb5-998f-ab46299e3b12', 'Protein bar', 'protein bar', null, 252, 25.0, 20.0, 8.0),
  FoodRowFixture('71b7a463-382d-41b3-8dea-1d7f9c563856', 'Protein powder (whey)', 'serving protein powder (whey)', null, 110, 3.0, 25.0, 1.0),
  FoodRowFixture('87345851-086f-4e1f-9148-52771ea230d4', 'Protein shake (ready-to-drink)', 'bottle protein shake', null, 150, 5.0, 25.0, 3.0),
  FoodRowFixture('76fbae6a-ca0b-4404-ba93-48be328aae3b', 'Salt Packet', 'salt packet', null, 0, 0.0, 0.0, 0.0),
  FoodRowFixture('8421a851-3d81-48c8-8334-0fb99b6aa447', 'Sports drink (carb + electrolytes)', 'cup sports drink (carb + electrolytes)', null, 56, 14.0, 0.0, 0.0),
  FoodRowFixture('b1d860f0-0afb-45d5-bcec-9eb8b02827bc', 'Sports drink mix (carb + electrolytes)', 'serving sports drink mix (carb + electrolytes)', null, 80, 16.0, 0.0, 0.0),
  FoodRowFixture('c5e0fb33-50e8-426c-98aa-1a2fc24ae388', 'Toast', 'slice of toast', null, 90, 17.0, 3.0, 1.0),
  FoodRowFixture('c5eabfaf-0e2b-42a5-8351-f12a9b36edef', 'Trail mix', 'serving of trail mix', null, 150, 16.0, 6.0, 9.0),
  FoodRowFixture('408c9d6e-83aa-4875-8100-e6bc09ebe324', 'Water', 'cup of water', null, 0, 0.0, 0.0, 0.0),
  FoodRowFixture('24f998ab-0714-4b7b-bdd1-8da1b9b42a5a', 'Yogurt', 'serving-cup yogurt', null, 90, 6.0, 16.0, 0.0),
];
