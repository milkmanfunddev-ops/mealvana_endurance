import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Reports section placeholder - Coming Soon
class PortalReportsPlaceholder extends StatelessWidget {
  const PortalReportsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blackberryDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 72,
                color: AppColors.orange.withOpacity(0.6),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reports - Coming Soon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We\'re building powerful analytics and reporting tools for coaches.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textDarkSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.blackberry,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blackberryLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Feature Preview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.electrolyte,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow(Icons.trending_up, 'Athlete progress tracking'),
                    const SizedBox(height: 12),
                    _buildFeatureRow(Icons.restaurant, 'Nutrition compliance'),
                    const SizedBox(height: 12),
                    _buildFeatureRow(Icons.speed, 'Performance trends'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.electrolyte),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.cream,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
