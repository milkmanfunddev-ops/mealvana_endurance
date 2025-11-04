import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/environment_switcher_dialog.dart';

/// Main Settings Menu - Category selection screen
class SettingsMenuScreen extends ConsumerWidget {
  const SettingsMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: GestureDetector(
          onLongPress: () {
            // Secret environment switcher - activated by long-pressing the title
            showDialog(
              context: context,
              builder: (context) => EnvironmentSwitcherDialog(config: config),
            );
          },
          child: Text(
            'Settings',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 18.sp,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   'Choose a category',
            //   style: AppTheme.textStyle.copyWith(
            //     color: AppTheme.baseGrey,
            //     fontSize: 14.sp,
            //   ),
            // ),
            // SizedBox(height: 20.h),

            // Profile Settings
            _buildCategoryTile(
              context: context,
              icon: Icons.person_outline,
              title: 'Profile',
              description: 'Personal info, height, weight',
              onTap: () => context.push('/settings/profile'),
            ),
            SizedBox(height: 16.h),

            // Sport Settings
            _buildCategoryTile(
              context: context,
              icon: Icons.directions_bike_outlined,
              title: 'Sport Settings',
              description: 'Cycling, swimming, GI sensitivity',
              onTap: () => context.push('/settings/sports'),
            ),
            SizedBox(height: 16.h),

            // Preferences
            _buildCategoryTile(
              context: context,
              icon: Icons.tune_outlined,
              title: 'Preferences',
              description: 'Units, gut training, food likes',
              onTap: () => context.push('/settings/preferences'),
            ),
            SizedBox(height: 16.h),

            // Help & Feedback
            _buildCategoryTile(
              context: context,
              icon: Icons.help_outline,
              title: 'Help & Feedback',
              description: 'Report bugs, get support',
              onTap: () => context.push('/settings/help'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppTheme.baseGrey.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.baseBlack.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.primary600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                icon,
                size: 28.sp,
                color: AppTheme.primary600,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.textStyle.copyWith(
                      color: AppTheme.baseBlack,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    description,
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18.sp,
              color: AppTheme.baseGrey,
            ),
          ],
        ),
      ),
    );
  }
}
