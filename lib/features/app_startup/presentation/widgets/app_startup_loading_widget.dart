import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Loading widget shown during app initialization
class AppStartupLoadingWidget extends StatelessWidget {
  const AppStartupLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseWhite,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary900),
          strokeWidth: 3.0,
        ),
      ),
    );
  }
}