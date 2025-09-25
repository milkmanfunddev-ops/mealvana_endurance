import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../auth/application/auth_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_preferences_content.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// Food preferences editing screen for settings
/// Allows users to update their food preferences after onboarding
class FoodPreferencesEditScreen extends ConsumerStatefulWidget {
  const FoodPreferencesEditScreen({super.key});

  @override
  ConsumerState<FoodPreferencesEditScreen> createState() => _FoodPreferencesEditScreenState();
}

class _FoodPreferencesEditScreenState extends ConsumerState<FoodPreferencesEditScreen> {
  final Map<String, FoodPreference> _selectedPreferences = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  Future<void> _loadExistingPreferences() async {
    try {
      final authService = ref.read(authServiceProvider);

      // Load existing preferences using auth service
      final currentUser = await authService.getCurrentUser();
      if (currentUser != null) {
        final existingPreferences = await authService.getFoodPreferences(currentUser.id);

        setState(() {
          // Use existing preferences if available
          if (existingPreferences != null) {
            _selectedPreferences.addAll(existingPreferences);
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading existing preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading food preferences: $e'),
            backgroundColor: AppTheme.highlight600,
          ),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Save preferences via auth service
      final currentUser = await authService.getCurrentUser();
      if (currentUser != null) {
        await authService.saveFoodPreferences(currentUser.id, _selectedPreferences);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Food preferences saved!'),
            backgroundColor: AppTheme.primary600,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to settings
        context.pop();
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: AppTheme.highlight600,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.baseCream,
        appBar: AppBar(
          backgroundColor: AppTheme.baseCream,
          foregroundColor: AppTheme.baseWhite,
          leading: const CustomAppBarBackButton(),
          title: const Text('Food Preferences'),
          centerTitle: true,
          iconTheme: IconThemeData(color: AppTheme.baseWhite),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = content.getValue(ContentKeys.foodPreferencesTitle, defaultValue: 'Food Preferences');

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
        onSave: _savePreferences,
        saveButtonText: 'Save Changes',
        isSaving: _isSaving,
        showSaveButton: true,
        layout: FoodPreferencesLayout.settings,
      ),
    );
  }
}