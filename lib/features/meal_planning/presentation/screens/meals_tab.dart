import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/meal_catalog_browser.dart';

export '../widgets/meal_catalog_browser.dart' show SlotLabels;

/// The Meals tab (05 §4): the shared [MealCatalogBrowser] — search / filter
/// tool buttons over the Recents / My Foods / Assemblies / Recipes rails —
/// with plain cards. Tapping any meal opens `/food/meals/:id`; the Vana
/// chat's "Browse meals" screen composes the same browser with an Add
/// affordance instead.
class MealsTab extends StatelessWidget {
  const MealsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return MealCatalogBrowser(
      onOpenMeal: (meal) => context.push('/food/meals/${meal.id}'),
      onSeeAllRecents: () => context.push('/food/meals/recents'),
    );
  }
}
