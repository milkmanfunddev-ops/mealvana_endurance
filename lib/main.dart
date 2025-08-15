import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'shared/core/app_router.dart';
import 'features/nutrition_plan/domain/food_item.dart';
import 'features/auth/domain/user_preferences.dart';
import 'features/auth/data/user_repository.dart';
import 'features/nutrition_plan/data/nutrition_plan_repository.dart';
import 'features/auth/application/auth_service.dart';
import 'features/nutrition_plan/application/nutrition_plan_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://wvmvsodrvbkxfydabqed.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyOTMxMDcsImV4cCI6MjA3MDg2OTEwN30.pG2IYdEIIFS8_zPxzr6pZplzWQqvD13dvslrpFMAPCk',
  );
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive adapters
  Hive.registerAdapter(FoodItemAdapter());
  Hive.registerAdapter(FoodCategoryAdapter());
  Hive.registerAdapter(NutritionInfoAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(GenderAdapter());
  Hive.registerAdapter(FoodPreferencesAdapter());
  Hive.registerAdapter(FoodPreferenceAdapter());
  Hive.registerAdapter(GutTrainingAdapter());
  
  // Initialize repositories after Hive is ready
  final userRepository = UserRepository();
  final nutritionPlanRepository = NutritionPlanRepository();
  
  await userRepository.init();
  await nutritionPlanRepository.init();
  
  runApp(
    ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(userRepository),
        nutritionPlanRepositoryProvider.overrideWithValue(nutritionPlanRepository),
      ],
      child: const MealvanaEnduranceApp(),
    ),
  );
}

class MealvanaEnduranceApp extends StatelessWidget {
  const MealvanaEnduranceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 Pro size from UI/UX docs
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Mealvana Endurance',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system, // Will implement theme provider later
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}