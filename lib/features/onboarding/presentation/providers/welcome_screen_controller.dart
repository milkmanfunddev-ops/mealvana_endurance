import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

part 'welcome_screen_controller.g.dart';

/// State for the welcome screen
class WelcomeScreenState {
  final String appTitle;
  final String subtitle;
  final String feature1Title;
  final String feature1Description;
  final String feature2Title;
  final String feature2Description;
  final String feature3Title;
  final String feature3Description;
  final String getStartedButtonText;
  final String skipButtonText;

  const WelcomeScreenState({
    required this.appTitle,
    required this.subtitle,
    required this.feature1Title,
    required this.feature1Description,
    required this.feature2Title,
    required this.feature2Description,
    required this.feature3Title,
    required this.feature3Description,
    required this.getStartedButtonText,
    required this.skipButtonText,
  });
}

/// Controller for welcome screen content
@riverpod
class WelcomeScreenController extends _$WelcomeScreenController {
  ContentService get _contentService => ref.read(contentServiceProvider);

  @override
  FutureOr<WelcomeScreenState> build() {
    // Load content synchronously from in-memory cache
    final appTitle = _contentService.getValue(ContentKeys.welcomeScreenTitle, defaultValue: 'Mealvana Endurance');
    final subtitle = _contentService.getValue(ContentKeys.welcomeScreenSubtitle, defaultValue: 'Personalized Nutrition Plans\nfor Long Run Days');
    final feature1Title = _contentService.getValue(ContentKeys.welcomeScreenFeature1Title, defaultValue: 'Smart Calculations');
    final feature1Description = _contentService.getValue(ContentKeys.welcomeScreenFeature1Description, defaultValue: 'Evidence-based nutrition formulas tailored to your body and run distance');
    final feature2Title = _contentService.getValue(ContentKeys.welcomeScreenFeature2Title, defaultValue: 'Food Preferences');
    final feature2Description = _contentService.getValue(ContentKeys.welcomeScreenFeature2Description, defaultValue: 'Plans based on foods you actually like and want to try');
    final feature3Title = _contentService.getValue(ContentKeys.welcomeScreenFeature3Title, defaultValue: 'Offline Ready');
    final feature3Description = _contentService.getValue(ContentKeys.welcomeScreenFeature3Description, defaultValue: 'Works completely offline - no internet required');
    final getStartedButtonText = _contentService.getValue(ContentKeys.welcomeScreenGetStartedButton, defaultValue: 'Get Started');
    final skipButtonText = _contentService.getValue(ContentKeys.welcomeScreenSkipButton, defaultValue: 'Skip for Now');

    return WelcomeScreenState(
      appTitle: appTitle,
      subtitle: subtitle,
      feature1Title: feature1Title,
      feature1Description: feature1Description,
      feature2Title: feature2Title,
      feature2Description: feature2Description,
      feature3Title: feature3Title,
      feature3Description: feature3Description,
      getStartedButtonText: getStartedButtonText,
      skipButtonText: skipButtonText,
    );
  }

  /// Refresh content from backend
  Future<void> refreshContent() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }
}