// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
// import 'package:mealvana_endurance/theme/app_theme.dart';
// import '../../application/carb_loading_controller_simple.dart';
// import '../../domain/carb_loading_plan_simple.dart';
// import '../widgets/carb_loading_header_card.dart';
// import '../widgets/carb_loading_day_tabs.dart';
// import '../widgets/carb_loading_meal_section.dart';
// import '../widgets/race_info_modal.dart';
// import '../widgets/daily_progress_widget.dart';
// import '../widgets/edit_carb_target_dialog.dart';

// /// Simplified carb loading screen matching screenshot design exactly
// /// Focuses exclusively on carbohydrate tracking with 50g increments
// class CarbLoadingScreenSimple extends ConsumerWidget {
//   const CarbLoadingScreenSimple({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final controllerState = ref.watch(carbLoadingControllerSimpleProvider);

//     return Scaffold(
//       backgroundColor: AppTheme.baseCream,
//       appBar: AppBar(
//         title: const Text('Carb Loading'),
//         backgroundColor: AppTheme.baseCream,
//         elevation: 0,
//         actions: [
//           PopupMenuButton<String>(
//             icon: const Icon(Icons.more_vert),
//             onSelected: (value) => _handleMenuAction(context, ref, value),
//             itemBuilder: (context) => [
//               const PopupMenuItem(
//                 value: 'edit_plan',
//                 child: ListTile(
//                   leading: Icon(Icons.edit, size: 20),
//                   title: Text('Edit Plan'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: 'reset_progress',
//                 child: ListTile(
//                   leading: Icon(Icons.refresh, size: 20),
//                   title: Text('Reset Progress'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: 'delete_plan',
//                 child: ListTile(
//                   leading: Icon(Icons.delete, size: 20, color: Colors.red),
//                   title: Text('Delete Plan', style: TextStyle(color: Colors.red)),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: controllerState.when(
//         data: (state) => _buildContent(context, ref, state),
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (error, stack) => _buildErrorState(context, error),
//       ),
//     );
//   }

//   Widget _buildContent(BuildContext context, WidgetRef ref, CarbLoadingState state) {
//     if (state.plan == null) {
//       return _buildNoPlanState(context, ref);
//     }

//     final plan = state.plan!;
//     final selectedDay = state.selectedDay;

//     // Calculate total consumed for the selected day
//     final daySelections = plan.daySelections[selectedDay] ?? DayFoodSelections.empty();
//     final totalConsumed = daySelections.totalCarbs;

//     return CustomScrollView(
//       slivers: [
//         // Header card as regular sliver
//         SliverToBoxAdapter(
//           child: CarbLoadingHeaderCard(plan: plan),
//         ),

//         // Day tabs as regular sliver
//         SliverToBoxAdapter(
//           child: CarbLoadingDayTabs(
//             selectedDay: selectedDay,
//             onDaySelected: (day) {
//               ref.read(carbLoadingControllerSimpleProvider.notifier).selectDay(day);
//             },
//           ),
//         ),

//         // Spacing
//         const SliverToBoxAdapter(
//           child: SizedBox(height: 16),
//         ),

//         // Sticky progress widget
//         SliverPersistentHeader(
//           pinned: true,
//           delegate: _StickyProgressDelegate(
//             plan: plan,
//             selectedDay: selectedDay,
//             totalConsumed: totalConsumed,
//             onEditTarget: () => _showEditTargetDialog(context, ref, plan),
//           ),
//         ),

//         // Spacing after sticky header
//         const SliverToBoxAdapter(
//           child: SizedBox(height: 16),
//         ),

//         // Meal sections
//         SliverToBoxAdapter(
//           child: _buildMealSections(context, ref, state, plan),
//         ),
//       ],
//     );
//   }

//   Widget _buildMealSections(BuildContext context, WidgetRef ref, CarbLoadingState state, CarbLoadingPlan plan) {
//     final daySelections = plan.daySelections[state.selectedDay] ?? DayFoodSelections.empty();
//     final meals = ['breakfast', 'lunch', 'snack1', 'dinner', 'snack2'];

//     // Calculate target carbs per meal based on daily target
//     // Distribution: Breakfast 25%, Lunch 25%, Snack1 15%, Dinner 25%, Snack2 10%
//     final dailyTarget = plan.dailyCarbTargetG;
//     final mealTargets = {
//       'breakfast': (dailyTarget * 0.25).round(),
//       'lunch': (dailyTarget * 0.25).round(),
//       'snack1': (dailyTarget * 0.15).round(),
//       'dinner': (dailyTarget * 0.25).round(),
//       'snack2': (dailyTarget * 0.10).round(),
//     };

//     return Column(
//       children: meals.map((mealName) {
//         final mealFoods = daySelections.meals[mealName] ?? MealFoods.empty();
//         final targetCarbs = mealTargets[mealName] ?? 0;

//         return CarbLoadingMealSection(
//           mealName: mealName,
//           mealFoods: mealFoods,
//           targetCarbs: targetCarbs,
//           onAddFood: (foodName) {
//             ref.read(carbLoadingControllerSimpleProvider.notifier).selectMeal(mealName);
//             ref.read(carbLoadingControllerSimpleProvider.notifier).addFood(foodName);
//           },
//           onRemoveFood: (foodName) {
//             ref.read(carbLoadingControllerSimpleProvider.notifier).selectMeal(mealName);
//             ref.read(carbLoadingControllerSimpleProvider.notifier).removeFood(foodName);
//           },
//           onUpdateFoodQuantity: (foodName, quantity) {
//             ref.read(carbLoadingControllerSimpleProvider.notifier).selectMeal(mealName);
//             ref.read(carbLoadingControllerSimpleProvider.notifier).updateFoodQuantity(foodName, quantity);
//           },
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildNoPlanState(BuildContext context, WidgetRef ref) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.local_dining,
//               size: 64,
//               color: Colors.grey[400],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'No Carb Loading Plan',
//               style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                 color: Colors.grey[600],
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Create a carb loading plan to start tracking your race preparation.',
//               style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                 color: Colors.grey[500],
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 24),
//             PrimaryButton(
//               onPressed: () {
//                 _showCreatePlanDialog(context, ref);
//               },
//               text: 'Create Plan',
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorState(BuildContext context, Object error) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.error_outline,
//               size: 64,
//               color: Colors.red[400],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Error Loading Plan',
//               style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                 color: Colors.red[600],
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               error.toString(),
//               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                 color: Colors.grey[600],
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showCreatePlanDialog(BuildContext context, WidgetRef ref) {
//     showDialog(
//       context: context,
//       builder: (context) => RaceInfoModal(
//         onCreatePlan: (raceDate, raceDistance, trainingVolume) {
//           ref.read(carbLoadingControllerSimpleProvider.notifier).createPlan(
//             raceDate: raceDate,
//             raceDistance: raceDistance,
//             trainingVolume: trainingVolume,
//           );
//         },
//       ),
//     );
//   }

//   void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
//     switch (action) {
//       case 'edit_plan':
//         _showEditPlanDialog(context, ref);
//         break;
//       case 'reset_progress':
//         _showResetProgressDialog(context, ref);
//         break;
//       case 'delete_plan':
//         _showDeletePlanDialog(context, ref);
//         break;
//     }
//   }

//   void _showEditPlanDialog(BuildContext context, WidgetRef ref) {
//     final currentState = ref.read(carbLoadingControllerSimpleProvider).valueOrNull;
//     final currentPlan = currentState?.plan;

//     if (currentPlan == null) return;

//     showDialog(
//       context: context,
//       builder: (context) => RaceInfoModal(
//         isEditing: true,
//         initialRaceDate: currentPlan.raceDate,
//         initialRaceDistance: currentPlan.raceDistance,
//         initialTrainingVolume: currentPlan.trainingVolume,
//         onCreatePlan: (raceDate, raceDistance, trainingVolume) {
//           ref.read(carbLoadingControllerSimpleProvider.notifier).updatePlan(
//             raceDate: raceDate,
//             raceDistance: raceDistance,
//             trainingVolume: trainingVolume,
//           );
//         },
//       ),
//     );
//   }

//   void _showEditTargetDialog(BuildContext context, WidgetRef ref, CarbLoadingPlan plan) {
//     showDialog(
//       context: context,
//       builder: (context) => EditCarbTargetDialog(
//         currentCarbsPerKg: plan.carbsPerKgTarget,
//         currentDailyTargetG: plan.dailyCarbTargetG,
//         bodyWeightKg: plan.bodyWeightKg,
//         onSave: (carbsPerKg, dailyTargetG) {
//           ref.read(carbLoadingControllerSimpleProvider.notifier).updateCarbTarget(
//             carbsPerKg: carbsPerKg,
//             dailyTargetG: dailyTargetG,
//           );
//         },
//       ),
//     );
//   }


//   void _showResetProgressDialog(BuildContext context, WidgetRef ref) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Reset Progress'),
//         content: const Text(
//           'This will clear all your food selections but keep your race information. Are you sure?',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               ref.read(carbLoadingControllerSimpleProvider.notifier).resetProgress();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Reset'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showDeletePlanDialog(BuildContext context, WidgetRef ref) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Plan'),
//         content: const Text(
//           'This will permanently delete your carb loading plan. This action cannot be undone.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               ref.read(carbLoadingControllerSimpleProvider.notifier).deletePlan();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Custom delegate for sticky progress widget
// class _StickyProgressDelegate extends SliverPersistentHeaderDelegate {
//   final CarbLoadingPlan plan;
//   final int selectedDay;
//   final int totalConsumed;
//   final VoidCallback onEditTarget;

//   const _StickyProgressDelegate({
//     required this.plan,
//     required this.selectedDay,
//     required this.totalConsumed,
//     required this.onEditTarget,
//   });

//   @override
//   double get minExtent => 120.0; // Minimum height when sticky

//   @override
//   double get maxExtent => 120.0; // Maximum height when expanded

//   @override
//   Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return Container(
//       color: AppTheme.baseCream, // Match background to prevent visual issues
//       child: DailyProgressWidget(
//         totalConsumed: totalConsumed,
//         targetAmount: plan.dailyCarbTargetG,
//         onEditTarget: onEditTarget,
//       ),
//     );
//   }

//   @override
//   bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
//     if (oldDelegate is! _StickyProgressDelegate) return true;
//     return oldDelegate.plan != plan ||
//            oldDelegate.selectedDay != selectedDay ||
//            oldDelegate.totalConsumed != totalConsumed;
//   }
// }