import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';

/// Mixin to add analytics tracking capabilities to any widget
/// Provides easy access to common tracking methods
mixin AnalyticsMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  
  /// Get the analytics service
  AnalyticsService get analytics => ref.read(analyticsServiceProvider);
  
  /// Track screen view automatically when widget is built
  void trackScreenView(String screenName) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      analytics.trackScreenViewed(screenName);
    });
  }
  
  /// Track screen view with automatic screen name detection
  void trackAutoScreenView() {
    final screenName = T.toString().replaceAll('State', '').replaceAll('_', ' ');
    trackScreenView(screenName);
  }
  
  /// Track button press or interaction
  Future<void> trackInteraction(String action, {Map<String, dynamic>? properties}) async {
    await analytics.track(action, properties: properties);
  }
  
  /// Track form submission
  Future<void> trackFormSubmission(String formName, {
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? formData,
  }) async {
    await analytics.track('Form Submitted', properties: {
      'Form Name': formName,
      'Success': success,
      'Error Message': errorMessage,
      ...?formData,
    });
  }
  
  /// Track navigation action
  Future<void> trackNavigation(String destination, {String? source}) async {
    await analytics.track('Navigation', properties: {
      'Destination': destination,
      'Source': source ?? T.toString(),
    });
  }
  
  /// Track error with automatic screen context
  Future<void> trackScreenError(String errorMessage, {
    String? errorType,
    Map<String, dynamic>? additionalContext,
  }) async {
    await analytics.trackError(
      errorType: errorType ?? 'Screen Error',
      errorMessage: errorMessage,
      screenName: T.toString(),
      additionalContext: additionalContext,
    );
  }
}

/// Mixin for ConsumerWidget (stateless widgets)
mixin AnalyticsMixinStateless {
  
  /// Track interaction from stateless widget
  Future<void> trackInteraction(
    WidgetRef ref, 
    String action, {
    Map<String, dynamic>? properties,
  }) async {
    final analytics = ref.read(analyticsServiceProvider);
    await analytics.track(action, properties: properties);
  }
  
  /// Track screen view from stateless widget
  void trackScreenView(WidgetRef ref, String screenName) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(analyticsServiceProvider);
      analytics.trackScreenViewed(screenName);
    });
  }
}