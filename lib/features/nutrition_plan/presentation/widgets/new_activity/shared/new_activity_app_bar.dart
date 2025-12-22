import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';

/// App bar for the New Activity screen
///
/// Features:
/// - Centered title "Create New Activity Plan"
/// - Circular back button on the left
/// - Transparent background
class NewActivityAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NewActivityAppBar({
    super.key,
    required this.isDark,
  });

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
      leading: Container(
        margin: const EdgeInsets.only(left: AppSpacing.md),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cream.withValues(alpha: 0.1)
                  : AppColors.blackberry.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.arrowLeft,
                size: 16,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}
