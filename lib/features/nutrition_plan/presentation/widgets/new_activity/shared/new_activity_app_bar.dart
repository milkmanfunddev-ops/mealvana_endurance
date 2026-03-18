import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';

/// App bar for the New Activity screen
///
/// Features:
/// - Centered title "Create New Activity Plan"
/// - Circular back button on the left
/// - Transparent background
class NewActivityAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NewActivityAppBar({super.key, required this.isDark});

  final bool isDark;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Text(
        'Create New Activity Plan',
        style: AppTextStyles.sectionTitle.copyWith(
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
      ),
      leading: CustomAppBarBackButton(
        iconColor: isDark ? AppColors.cream : AppColors.blackberry,
        backgroundColor: (isDark ? AppColors.cream : AppColors.blackberry)
            .withValues(alpha: 0.1),
      ),
    );
  }
}
