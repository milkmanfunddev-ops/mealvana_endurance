import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../core/app_router.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';

/// Root app widget that handles app initialization and navigation
/// Following Andrea Bizzotto's patterns for app startup
class RootAppWidget extends ConsumerWidget {
  const RootAppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
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
          themeMode: ThemeMode.system,
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}

