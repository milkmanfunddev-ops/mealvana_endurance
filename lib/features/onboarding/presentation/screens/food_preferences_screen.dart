import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_preferences_content.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// Food preferences screen - final step of onboarding
/// Users select their food preferences using radio options
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() =>
      _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  final Map<String, FoodPreference> _selectedPreferences = {};

  Future<void> _completeOnboarding() async {
    print('🔄 Food preferences screen - Complete onboarding button pressed');
    print('📊 Food preferences screen - Selected preferences count: ${_selectedPreferences.length}');

    final controller = ref.read(onboardingControllerProvider.notifier);
    print('🎮 Food preferences screen - Calling controller.saveFoodPreferences');

    final success = await controller.saveFoodPreferences(_selectedPreferences);
    print('📋 Food preferences screen - Save result: $success');

    if (success && mounted) {
      print('🎯 Food preferences screen - Success! Navigating to /main');
      context.go('/main');
    } else {
      print('❌ Food preferences screen - Failed to save or not mounted. Success: $success, Mounted: $mounted');
      if (!success) {
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save food preferences. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(onboardingControllerProvider);
    final content = ref.read(contentServiceProvider);

    final title = content.getValue(
      ContentKeys.foodPreferencesTitle,
      defaultValue: 'Food Preferences',
    );
    final completeLabel = content.getValue(
      ContentKeys.foodPreferencesCompleteButton,
      defaultValue: 'Complete Setup',
    );

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        foregroundColor: AppTheme.baseWhite,
        leading: const CustomAppBarBackButton(),
        title: Text(title),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.baseWhite),
      ),
      body: FoodPreferencesContent(
        selectedPreferences: _selectedPreferences,
        onPreferenceChanged: (foodName, preference) {
          setState(() {
            _selectedPreferences[foodName] = preference;
          });
        },
        onSave: asyncState.isLoading ? null : _completeOnboarding,
        saveButtonText: completeLabel,
        isSaving: asyncState.isLoading,
        showSaveButton: true,
        layout: FoodPreferencesLayout.onboarding,
      ),
    );
  }
}
