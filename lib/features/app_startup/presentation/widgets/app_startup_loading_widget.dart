import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Loading widget shown during app initialization
class AppStartupLoadingWidget extends StatelessWidget {
  const AppStartupLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
          strokeWidth: 3.0,
        ),
      ),
    );
  }
}
