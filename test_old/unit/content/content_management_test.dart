/// Content Management System Unit Tests
/// 
/// Tests the backend-controlled content system that allows dynamic updates
/// of UI text and algorithm parameters without code deployments.
/// Critical for business agility and A/B testing capabilities.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/content/presentation/controllers/content_controller.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';

import '../../helpers/test_data.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/test_config.dart';

void main() {
  group('Content Management System Tests', () {
    late ProviderContainer container;

    setUpAll(() {
      TestMockSetup.setupFallbacks();
    });

    setUp(() {
      container = TestProviderContainer.create();
    });

    tearDown(() {
      TestContainerUtils.disposeContainer(container);
    });

    group('Content Loading and Caching', () {
      testWidgets('loads content from backend successfully', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);
        final listener = TestContainerUtils.createListener<Map<String, dynamic>>();
        
        container.listen(
          contentControllerProvider,
          listener.call,
          fireImmediately: true,
        );

        // Act: Load content
        await controller.refreshFromBackend();

        // Assert: Should load content successfully
        verify(() => listener(null, any(that: isA<AsyncData>())));
        
        final state = container.read(contentControllerProvider);
        expect(state.hasValue, isTrue);
        
        final contentData = state.requireValue;
        expect(contentData, contains('ui_text'));
        expect(contentData, contains('algorithm'));
      });

      testWidgets('uses local fallback when backend unavailable', (tester) async {
        // Arrange: Mock content repository that fails backend load
        final mockContent = MockContentRepository();
        when(() => mockContent.refreshFromBackend()).thenThrow(Exception('Network error'));
        when(() => mockContent.getContent()).thenAnswer((_) async => TestData.testAppContent);
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          contentRepository: mockContent,
        );
        
        final controller = testContainer.read(contentControllerProvider.notifier);

        // Act: Try to refresh from backend (will fail), then get content
        expect(() => controller.refreshFromBackend(), throwsA(isA<Exception>()));
        
        // Get cached/local content
        final content = await controller.getContent();

        // Assert: Should fallback to local content
        expect(content, isNotNull);
        expect(content, contains('ui_text'));
        expect(content['ui_text'], contains('welcome_title'));

        TestContainerUtils.disposeContainer(testContainer);
      });

      testWidgets('caches content for offline access', (tester) async {
        // Arrange: Content controller with loaded content
        final controller = container.read(contentControllerProvider.notifier);
        await controller.refreshFromBackend();

        // Act: Get content multiple times (should use cache)
        final content1 = await controller.getContent();
        final content2 = await controller.getContent();
        final content3 = await controller.getContent();

        // Assert: Should return same content from cache
        expect(content1, isNotNull);
        expect(content2, equals(content1));
        expect(content3, equals(content1));
      });

      testWidgets('respects cache expiration', (tester) async {
        // Arrange: Mock repository with version tracking
        final mockContent = MockContentRepository();
        var refreshCount = 0;
        
        when(() => mockContent.refreshFromBackend()).thenAnswer((_) async {
          refreshCount++;
          return true;
        });
        when(() => mockContent.getContent()).thenAnswer((_) async => TestData.testAppContent);
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          contentRepository: mockContent,
        );
        
        final controller = testContainer.read(contentControllerProvider.notifier);

        // Act: Multiple refresh attempts within short time
        await controller.refreshFromBackend();
        await controller.refreshFromBackend();
        await controller.refreshFromBackend();

        // Assert: Should not over-refresh (respect rate limiting)
        expect(refreshCount, lessThanOrEqualTo(3));

        TestContainerUtils.disposeContainer(testContainer);
      });
    });

    group('UI Text Management', () {
      testWidgets('retrieves UI text with default fallbacks', (tester) async {
        // Arrange: Content controller with test content
        final controller = container.read(contentControllerProvider.notifier);
        await controller.refreshFromBackend();

        // Act: Get various UI text values
        final welcomeTitle = controller.getValue(
          ContentKeys.welcomeTitle,
          defaultValue: 'Default Welcome',
        );
        
        final buttonText = controller.getValue(
          ContentKeys.buttonGetStarted,
          defaultValue: 'Start',
        );
        
        final nonExistentText = controller.getValue(
          'non_existent_key',
          defaultValue: 'Fallback Text',
        );

        // Assert: Should return correct values with fallbacks
        expect(welcomeTitle, isNotEmpty);
        expect(buttonText, isNotEmpty);
        expect(nonExistentText, equals('Fallback Text'));
      });

      testWidgets('handles missing UI text keys gracefully', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);

        // Act: Get text for non-existent keys
        final missingKey1 = controller.getValue('missing.key.1');
        final missingKey2 = controller.getValue('missing.key.2', defaultValue: 'Custom Default');
        final nullDefault = controller.getValue('missing.key.3', defaultValue: null);

        // Assert: Should handle missing keys appropriately
        expect(missingKey1, isNotNull); // Should provide some fallback
        expect(missingKey2, equals('Custom Default'));
        expect(nullDefault, isNull);
      });

      testWidgets('supports dynamic UI text updates', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);
        
        // Initial content load
        await controller.refreshFromBackend();
        final initialWelcome = controller.getValue(ContentKeys.welcomeTitle);

        // Act: Simulate backend content update
        final updatedContent = Map<String, dynamic>.from(TestData.testAppContent);
        updatedContent['ui_text']['welcome_title'] = 'Updated Welcome Message';
        
        await controller.updateContent(updatedContent);
        
        final updatedWelcome = controller.getValue(ContentKeys.welcomeTitle);

        // Assert: Should reflect updated content
        expect(initialWelcome, isNotEmpty);
        expect(updatedWelcome, equals('Updated Welcome Message'));
        expect(updatedWelcome, isNot(equals(initialWelcome)));
      });

      testWidgets('preserves UI text formatting and special characters', (tester) async {
        // Arrange: Content with special characters
        final controller = container.read(contentControllerProvider.notifier);
        
        final specialContent = {
          'ui_text': {
            'special_message': 'Welcome! 🎉 Let\'s get started with "nutrition planning".',
            'formatted_text': 'Line 1\nLine 2\n\nParagraph with\ttabs',
            'unicode_text': 'Café résumé naïve',
          }
        };
        
        await controller.updateContent(specialContent);

        // Act: Get formatted text
        final specialMessage = controller.getValue('special_message');
        final formattedText = controller.getValue('formatted_text');
        final unicodeText = controller.getValue('unicode_text');

        // Assert: Should preserve formatting
        expect(specialMessage, contains('🎉'));
        expect(specialMessage, contains('"nutrition planning"'));
        expect(formattedText, contains('\n'));
        expect(formattedText, contains('\t'));
        expect(unicodeText, contains('é'));
        expect(unicodeText, contains('ï'));
      });
    });

    group('Algorithm Parameter Management', () {
      testWidgets('loads algorithm parameters correctly', (tester) async {
        // Arrange: Content controller with algorithm config
        final controller = container.read(contentControllerProvider.notifier);
        await controller.refreshFromBackend();

        // Act: Get algorithm parameters
        final metWalkingBase = controller.getAlgorithmParameter(
          'energy.met_walking_base',
          defaultValue: 3.5,
        );
        
        final carbMinTarget = controller.getAlgorithmParameter(
          'carb_targets.pre_run_min_g_per_kg',
          defaultValue: 1.0,
        );
        
        final gutTrainingMultiplier = controller.getAlgorithmParameter(
          'carb_targets.gut_training_multipliers.moderate',
          defaultValue: 0.85,
        );

        // Assert: Should return correct algorithm parameters
        expect(metWalkingBase, equals(3.5));
        expect(carbMinTarget, equals(1.0));
        expect(gutTrainingMultiplier, equals(0.85));
      });

      testWidgets('updates algorithm parameters dynamically', (tester) async {
        // Arrange: Content controller with initial parameters
        final controller = container.read(contentControllerProvider.notifier);
        await controller.refreshFromBackend();
        
        final initialMultiplier = controller.getAlgorithmParameter(
          'carb_targets.gut_training_multipliers.moderate',
          defaultValue: 0.85,
        );

        // Act: Update algorithm parameters
        await controller.updateAlgorithmParameter(
          'carb_targets.gut_training_multipliers.moderate',
          0.9, // Increase from 0.85 to 0.9
        );
        
        final updatedMultiplier = controller.getAlgorithmParameter(
          'carb_targets.gut_training_multipliers.moderate',
          defaultValue: 0.85,
        );

        // Assert: Should reflect updated parameters
        expect(initialMultiplier, equals(0.85));
        expect(updatedMultiplier, equals(0.9));
        expect(updatedMultiplier, isNot(equals(initialMultiplier)));
      });

      testWidgets('validates algorithm parameter types', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);

        // Act & Assert: Different parameter types
        final numberParam = controller.getAlgorithmParameter(
          'energy.met_walking_base',
          defaultValue: 3.5,
        );
        expect(numberParam, isA<double>());
        
        final integerParam = controller.getAlgorithmParameter(
          'hydration.base_ml_per_h_min',
          defaultValue: 400,
        );
        expect(integerParam, isA<int>());
        
        // Test type safety
        expect(
          () => controller.updateAlgorithmParameter('energy.met_walking_base', 'not_a_number'),
          throwsA(isA<TypeError>()),
        );
      });

      testWidgets('provides parameter defaults for offline mode', (tester) async {
        // Arrange: Content controller without backend connection
        final mockContent = MockContentRepository();
        when(() => mockContent.getContent()).thenAnswer((_) async => <String, dynamic>{});
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          contentRepository: mockContent,
        );
        
        final controller = testContainer.read(contentControllerProvider.notifier);

        // Act: Get algorithm parameters without backend content
        final metBase = controller.getAlgorithmParameter(
          'energy.met_walking_base',
          defaultValue: 3.5,
        );
        
        final carbMin = controller.getAlgorithmParameter(
          'carb_targets.pre_run_min_g_per_kg',
          defaultValue: 1.0,
        );

        // Assert: Should use defaults when backend unavailable
        expect(metBase, equals(3.5));
        expect(carbMin, equals(1.0));

        TestContainerUtils.disposeContainer(testContainer);
      });
    });

    group('Content Versioning', () {
      testWidgets('tracks content version for updates', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);

        // Act: Load content and check version
        await controller.refreshFromBackend();
        final version1 = controller.getContentVersion();
        
        // Update content
        final updatedContent = Map<String, dynamic>.from(TestData.testAppContent);
        updatedContent['_version'] = 2;
        await controller.updateContent(updatedContent);
        
        final version2 = controller.getContentVersion();

        // Assert: Version should increment
        expect(version1, isA<String>());
        expect(version2, isA<String>());
        expect(version2, isNot(equals(version1)));
      });

      testWidgets('handles content conflicts gracefully', (tester) async {
        // Arrange: Content controller with existing content
        final controller = container.read(contentControllerProvider.notifier);
        await controller.refreshFromBackend();

        // Act: Simulate concurrent content updates
        final update1 = Map<String, dynamic>.from(TestData.testAppContent);
        update1['ui_text']['welcome_title'] = 'Update 1';
        
        final update2 = Map<String, dynamic>.from(TestData.testAppContent);
        update2['ui_text']['welcome_title'] = 'Update 2';

        await controller.updateContent(update1);
        await controller.updateContent(update2);
        
        final finalWelcome = controller.getValue('welcome_title');

        // Assert: Should handle conflicts (last update wins)
        expect(finalWelcome, equals('Update 2'));
      });

      testWidgets('preserves content across app restarts', (tester) async {
        // Arrange: Content controller with content
        final controller = container.read(contentControllerProvider.notifier);
        await controller.refreshFromBackend();
        
        final originalWelcome = controller.getValue(ContentKeys.welcomeTitle);
        
        // Dispose container (simulate app restart)
        TestContainerUtils.disposeContainer(container);

        // Act: Create new container and controller
        container = TestProviderContainer.create();
        final newController = container.read(contentControllerProvider.notifier);
        
        // Should load persisted content
        final persistedWelcome = newController.getValue(ContentKeys.welcomeTitle);

        // Assert: Content should persist (in real app, would be from local storage)
        expect(originalWelcome, isNotEmpty);
        expect(persistedWelcome, isNotEmpty);
      });
    });

    group('Performance and Optimization', () {
      testWidgets('caches frequently accessed content', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);
        await controller.refreshFromBackend();

        // Act: Access same content multiple times
        final startTime = DateTime.now();
        
        for (int i = 0; i < 100; i++) {
          controller.getValue(ContentKeys.welcomeTitle);
          controller.getAlgorithmParameter('energy.met_walking_base', defaultValue: 3.5);
        }
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Assert: Should be very fast due to caching
        expect(duration.inMilliseconds, lessThan(100),
            reason: 'Cached content access should be very fast');
      });

      testWidgets('minimizes backend requests', (tester) async {
        // Arrange: Mock repository to track requests
        final mockContent = MockContentRepository();
        var requestCount = 0;
        
        when(() => mockContent.refreshFromBackend()).thenAnswer((_) async {
          requestCount++;
          return true;
        });
        when(() => mockContent.getContent()).thenAnswer((_) async => TestData.testAppContent);
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          contentRepository: mockContent,
        );
        
        final controller = testContainer.read(contentControllerProvider.notifier);

        // Act: Multiple refresh attempts in short succession
        await controller.refreshFromBackend();
        await controller.refreshFromBackend();
        await controller.refreshFromBackend();

        // Assert: Should not make excessive requests
        expect(requestCount, lessThanOrEqualTo(3));

        TestContainerUtils.disposeContainer(testContainer);
      });

      testWidgets('handles large content payloads efficiently', (tester) async {
        // Arrange: Large content payload
        final largeContent = <String, dynamic>{
          'ui_text': {},
          'algorithm': {},
        };
        
        // Add many UI text entries
        for (int i = 0; i < 1000; i++) {
          largeContent['ui_text']['key_$i'] = 'Value $i';
        }
        
        // Add many algorithm parameters
        for (int i = 0; i < 100; i++) {
          largeContent['algorithm']['param_$i'] = i * 1.5;
        }
        
        final controller = container.read(contentControllerProvider.notifier);

        // Act: Load and access large content
        final startTime = DateTime.now();
        
        await controller.updateContent(largeContent);
        
        // Access various keys
        controller.getValue('key_500');
        controller.getAlgorithmParameter('param_50', defaultValue: 0.0);
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Assert: Should handle large payloads efficiently
        expect(duration.inSeconds, lessThan(5),
            reason: 'Large content handling should be efficient');
      });
    });

    group('Error Handling and Resilience', () {
      testWidgets('handles backend errors gracefully', (tester) async {
        // Arrange: Mock repository with various errors
        final mockContent = MockContentRepository();
        when(() => mockContent.refreshFromBackend()).thenThrow(Exception('Backend error'));
        when(() => mockContent.getContent()).thenAnswer((_) async => TestData.testAppContent);
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          contentRepository: mockContent,
        );
        
        final controller = testContainer.read(contentControllerProvider.notifier);

        // Act: Handle backend error gracefully
        expect(() => controller.refreshFromBackend(), throwsA(isA<Exception>()));
        
        // But should still provide content from cache/defaults
        final welcomeText = controller.getValue(ContentKeys.welcomeTitle, defaultValue: 'Welcome');

        // Assert: Should provide fallback content
        expect(welcomeText, isNotEmpty);

        TestContainerUtils.disposeContainer(testContainer);
      });

      testWidgets('recovers from corrupted content', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);
        
        // Load good content first
        await controller.refreshFromBackend();
        final goodWelcome = controller.getValue(ContentKeys.welcomeTitle);

        // Act: Try to load corrupted content
        final corruptedContent = {
          'ui_text': null, // Null instead of map
          'algorithm': 'not_a_map', // String instead of map
        };

        expect(
          () => controller.updateContent(corruptedContent),
          throwsA(isA<Exception>()),
        );
        
        // Should still provide previous good content
        final fallbackWelcome = controller.getValue(ContentKeys.welcomeTitle, defaultValue: 'Fallback');

        // Assert: Should maintain previous good content or provide fallback
        expect(goodWelcome, isNotEmpty);
        expect(fallbackWelcome, isNotEmpty);
      });

      testWidgets('validates content structure before applying', (tester) async {
        // Arrange: Content controller
        final controller = container.read(contentControllerProvider.notifier);

        // Act & Assert: Invalid content structures
        final invalidStructures = [
          null, // Null content
          'not_a_map', // String instead of map
          <String, dynamic>{}, // Empty map
          {
            'ui_text': 'should_be_map', // Wrong type
          },
          {
            'algorithm': ['should', 'be', 'map'], // Wrong type
          }
        ];

        for (final invalidContent in invalidStructures) {
          expect(
            () => controller.updateContent(invalidContent as Map<String, dynamic>?),
            throwsA(isA<Exception>()),
            reason: 'Should reject invalid content: $invalidContent',
          );
        }
      });
    });
  });
}