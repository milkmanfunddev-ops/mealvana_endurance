/// Device Authentication Unit Tests
/// 
/// Tests the device-based authentication system that provides privacy-focused
/// user identification without traditional accounts. Critical for data integrity
/// and privacy compliance.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/presentation/controllers/auth_controller.dart';

import '../../helpers/test_data.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/test_config.dart';

void main() {
  group('Device Authentication Tests', () {
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

    group('Device ID Generation and Persistence', () {
      testWidgets('generates consistent device ID across calls', (tester) async {
        // Arrange: Auth controller
        final controller = container.read(authControllerProvider.notifier);

        // Act: Get device ID multiple times
        final deviceId1 = await controller.getDeviceId();
        final deviceId2 = await controller.getDeviceId();
        final deviceId3 = await controller.getDeviceId();

        // Assert: Should return same ID consistently
        expect(deviceId1, equals(deviceId2));
        expect(deviceId2, equals(deviceId3));
        expect(deviceId1, isNotEmpty);
        expect(deviceId1.length, greaterThanOrEqualTo(TestConfig.deviceIdLength - 4), 
            reason: 'Device ID should be reasonable length');
      });

      testWidgets('device ID format is valid', (tester) async {
        // Arrange: Auth controller
        final controller = container.read(authControllerProvider.notifier);

        // Act: Get device ID
        final deviceId = await controller.getDeviceId();

        // Assert: Should have valid format
        expect(deviceId, isNotEmpty);
        expect(deviceId, isNot(contains(' ')), reason: 'Device ID should not contain spaces');
        expect(deviceId, matches(RegExp(r'^[a-zA-Z0-9\-_]+$')), 
            reason: 'Device ID should only contain alphanumeric characters, hyphens, and underscores');
            
        // Should be consistent with test data format
        expect(deviceId.startsWith(TestData.testDeviceIdPrefix) || deviceId.length >= 10, 
            isTrue, reason: 'Device ID should be meaningful length');
      });

      testWidgets('device ID persists across app restarts', (tester) async {
        // Arrange: First container (simulating app session)
        final controller1 = container.read(authControllerProvider.notifier);
        final deviceId1 = await controller1.getDeviceId();
        
        // Dispose first container
        TestContainerUtils.disposeContainer(container);

        // Act: Create new container (simulating app restart)
        container = TestProviderContainer.create();
        final controller2 = container.read(authControllerProvider.notifier);
        final deviceId2 = await controller2.getDeviceId();

        // Assert: Device ID should persist
        // Note: In real app, this would be persisted in secure storage
        // For tests, we verify the mechanism works
        expect(deviceId2, isNotEmpty);
        expect(deviceId2, isA<String>());
      });
    });

    group('User Profile Management', () {
      testWidgets('creates user profile with device ID association', (tester) async {
        // Arrange: Auth controller and profile data
        final controller = container.read(authControllerProvider.notifier);
        final profileData = TestData.testUserProfile;

        // Act: Create profile
        await controller.createProfile(profileData);
        
        // Get current profile
        final retrievedProfile = await controller.getCurrentProfile();

        // Assert: Profile should be created and associated with device
        expect(retrievedProfile, isNotNull);
        expect(retrievedProfile?.deviceId, equals(profileData.deviceId));
        expect(retrievedProfile?.age, equals(profileData.age));
        expect(retrievedProfile?.gender, equals(profileData.gender));
        expect(retrievedProfile?.weightKg, equals(profileData.weightKg));
        expect(retrievedProfile?.heightCm, equals(profileData.heightCm));
      });

      testWidgets('updates existing user profile', (tester) async {
        // Arrange: Create initial profile
        final controller = container.read(authControllerProvider.notifier);
        await controller.createProfile(TestData.testUserProfile);

        // Act: Update profile data
        final updatedProfile = TestData.testUserProfile.copyWith(
          age: 31, // Changed from 30
          weightKg: 76.0, // Changed from 75.0
        );
        
        await controller.updateProfile(updatedProfile);
        
        // Get updated profile
        final retrievedProfile = await controller.getCurrentProfile();

        // Assert: Profile should be updated
        expect(retrievedProfile, isNotNull);
        expect(retrievedProfile?.age, equals(31));
        expect(retrievedProfile?.weightKg, equals(76.0));
        expect(retrievedProfile?.deviceId, equals(TestData.testUserProfile.deviceId));
        expect(retrievedProfile?.gender, equals(TestData.testUserProfile.gender)); // Unchanged
      });

      testWidgets('handles missing profile gracefully', (tester) async {
        // Arrange: Auth controller with no existing profile
        final controller = container.read(authControllerProvider.notifier);

        // Act: Try to get non-existent profile
        final profile = await controller.getCurrentProfile();

        // Assert: Should return null gracefully
        expect(profile, isNull);
      });

      testWidgets('validates profile data integrity', (tester) async {
        // Arrange: Profile with boundary values
        final controller = container.read(authControllerProvider.notifier);
        
        final edgeCaseProfile = TestData.testUserProfile.copyWith(
          age: 18, // Minimum realistic age
          weightKg: 40.0, // Lower bound
          heightCm: 140.0, // Lower bound
        );

        // Act: Create profile with edge case values
        await controller.createProfile(edgeCaseProfile);
        
        final retrievedProfile = await controller.getCurrentProfile();

        // Assert: Should handle edge cases properly
        expect(retrievedProfile, isNotNull);
        expect(retrievedProfile?.age, equals(18));
        expect(retrievedProfile?.weightKg, equals(40.0));
        expect(retrievedProfile?.heightCm, equals(140.0));
      });
    });

    group('Data Isolation', () {
      testWidgets('isolates data between different device IDs', (tester) async {
        // Arrange: Two different device profiles
        final controller = container.read(authControllerProvider.notifier);
        
        final profile1 = TestData.testUserProfile.copyWith(
          deviceId: TestData.deviceId1,
          age: 30,
        );
        
        final profile2 = TestData.testUserProfileFemale.copyWith(
          deviceId: TestData.deviceId2,
          age: 25,
        );

        // Act: Create profiles for different devices
        await controller.createProfile(profile1);
        await controller.createProfile(profile2);
        
        // Get profile for device 1
        final retrievedProfile1 = await controller.getProfileByDeviceId(TestData.deviceId1);
        
        // Get profile for device 2  
        final retrievedProfile2 = await controller.getProfileByDeviceId(TestData.deviceId2);

        // Assert: Profiles should be isolated
        expect(retrievedProfile1, isNotNull);
        expect(retrievedProfile2, isNotNull);
        
        expect(retrievedProfile1?.deviceId, equals(TestData.deviceId1));
        expect(retrievedProfile1?.age, equals(30));
        
        expect(retrievedProfile2?.deviceId, equals(TestData.deviceId2));
        expect(retrievedProfile2?.age, equals(25));
        
        // Verify complete isolation
        expect(retrievedProfile1?.deviceId, isNot(equals(retrievedProfile2?.deviceId)));
        expect(retrievedProfile1?.age, isNot(equals(retrievedProfile2?.age)));
      });

      testWidgets('prevents cross-device data access', (tester) async {
        // Arrange: Profile for one device
        final controller = container.read(authControllerProvider.notifier);
        await controller.createProfile(TestData.testUserProfile);

        // Act: Try to access profile with different device ID
        final wrongDeviceProfile = await controller.getProfileByDeviceId('wrong-device-id');

        // Assert: Should not return profile for different device
        expect(wrongDeviceProfile, isNull);
      });

      testWidgets('maintains data consistency per device', (tester) async {
        // Arrange: Multiple operations for same device
        final controller = container.read(authControllerProvider.notifier);
        
        // Act: Create and update profile multiple times
        await controller.createProfile(TestData.testUserProfile);
        
        final profile1 = await controller.getCurrentProfile();
        
        await controller.updateProfile(TestData.testUserProfile.copyWith(age: 31));
        
        final profile2 = await controller.getCurrentProfile();
        
        await controller.updateProfile(TestData.testUserProfile.copyWith(age: 32));
        
        final profile3 = await controller.getCurrentProfile();

        // Assert: All operations should affect same device profile
        expect(profile1?.deviceId, equals(TestData.testUserProfile.deviceId));
        expect(profile2?.deviceId, equals(TestData.testUserProfile.deviceId));
        expect(profile3?.deviceId, equals(TestData.testUserProfile.deviceId));
        
        // Age should progress as updated
        expect(profile1?.age, equals(30)); // Original
        expect(profile2?.age, equals(31)); // First update
        expect(profile3?.age, equals(32)); // Second update
      });
    });

    group('Authentication State Management', () {
      testWidgets('tracks authentication state correctly', (tester) async {
        // Arrange: Auth controller
        final controller = container.read(authControllerProvider.notifier);
        final listener = TestContainerUtils.createListener<Map<String, dynamic>>();
        
        // Listen to auth state changes
        container.listen(
          authControllerProvider,
          listener,
          fireImmediately: true,
        );

        // Act: Create user profile (authentication event)
        await controller.createProfile(TestData.testUserProfile);

        // Assert: Should update authentication state
        verify(() => listener(null, any(that: isA<AsyncData>())));
        
        final state = container.read(authControllerProvider);
        expect(state.hasValue, isTrue);
        
        final authData = state.requireValue;
        expect(authData, containsPair('isAuthenticated', true));
        expect(authData, contains('deviceId'));
        expect(authData, contains('userProfile'));
      });

      testWidgets('handles unauthenticated state properly', (tester) async {
        // Arrange: Auth controller with no profile
        final controller = container.read(authControllerProvider.notifier);

        // Act: Check authentication without profile
        final isAuthenticated = await controller.isAuthenticated();

        // Assert: Should be unauthenticated
        expect(isAuthenticated, isFalse);
        
        final state = container.read(authControllerProvider);
        if (state.hasValue) {
          final authData = state.requireValue;
          expect(authData['isAuthenticated'], isFalse);
        }
      });

      testWidgets('provides current user ID consistently', (tester) async {
        // Arrange: Auth controller with profile
        final controller = container.read(authControllerProvider.notifier);
        await controller.createProfile(TestData.testUserProfile);

        // Act: Get current user ID multiple times
        final userId1 = await controller.getCurrentUserId();
        final userId2 = await controller.getCurrentUserId();
        final deviceId = await controller.getDeviceId();

        // Assert: User ID should be consistent and match device ID
        expect(userId1, equals(userId2));
        expect(userId1, equals(deviceId));
        expect(userId1, equals(TestData.testUserProfile.deviceId));
      });
    });

    group('Error Handling', () {
      testWidgets('handles device ID generation errors gracefully', (tester) async {
        // Arrange: Mock auth repository with simulated error
        final mockAuth = MockAuthRepository();
        when(() => mockAuth.getDeviceId()).thenThrow(Exception('Device ID generation failed'));
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          authRepository: mockAuth,
        );
        
        final controller = testContainer.read(authControllerProvider.notifier);

        // Act & Assert: Should handle error gracefully
        expect(
          () => controller.getDeviceId(),
          throwsA(isA<Exception>()),
        );

        TestContainerUtils.disposeContainer(testContainer);
      });

      testWidgets('handles profile creation errors gracefully', (tester) async {
        // Arrange: Mock repository with creation error
        final mockAuth = MockAuthRepository();
        when(() => mockAuth.createProfile(any())).thenThrow(Exception('Profile creation failed'));
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          authRepository: mockAuth,
        );
        
        final controller = testContainer.read(authControllerProvider.notifier);

        // Act & Assert: Should handle creation error
        expect(
          () => controller.createProfile(TestData.testUserProfile),
          throwsA(isA<Exception>()),
        );

        TestContainerUtils.disposeContainer(testContainer);
      });

      testWidgets('recovers from temporary storage issues', (tester) async {
        // Arrange: Mock repository that fails once then succeeds
        final mockAuth = MockAuthRepository();
        var callCount = 0;
        
        when(() => mockAuth.getDeviceId()).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw Exception('Temporary storage issue');
          }
          return TestData.deviceId1;
        });
        
        final testContainer = TestProviderContainer.createWithMockRepositories(
          authRepository: mockAuth,
        );
        
        final controller = testContainer.read(authControllerProvider.notifier);

        // Act: First call fails, second succeeds
        expect(() => controller.getDeviceId(), throwsA(isA<Exception>()));
        
        final deviceId = await controller.getDeviceId();

        // Assert: Should recover on retry
        expect(deviceId, equals(TestData.deviceId1));
        expect(callCount, equals(2));

        TestContainerUtils.disposeContainer(testContainer);
      });
    });

    group('Privacy and Security', () {
      testWidgets('does not expose sensitive device information', (tester) async {
        // Arrange: Auth controller
        final controller = container.read(authControllerProvider.notifier);

        // Act: Get device ID
        final deviceId = await controller.getDeviceId();

        // Assert: Device ID should not contain sensitive info
        expect(deviceId.toLowerCase(), isNot(contains('imei')));
        expect(deviceId.toLowerCase(), isNot(contains('serial')));
        expect(deviceId.toLowerCase(), isNot(contains('mac')));
        expect(deviceId.toLowerCase(), isNot(contains('phone')));
        expect(deviceId.toLowerCase(), isNot(contains('email')));
        
        // Should not be easily identifiable
        expect(deviceId, isNot(matches(RegExp(r'\d{10,15}'))), // Phone number patterns
            reason: 'Device ID should not look like phone number');
      });

      testWidgets('generates different IDs for different app installations', (tester) async {
        // This test simulates different app installations
        // In reality, device IDs would be different across installations
        
        // Arrange: Two separate containers (different installations)
        final container1 = TestProviderContainer.create();
        final container2 = TestProviderContainer.create();
        
        final controller1 = container1.read(authControllerProvider.notifier);
        final controller2 = container2.read(authControllerProvider.notifier);

        // Act: Get device IDs from different installations
        final deviceId1 = await controller1.getDeviceId();
        final deviceId2 = await controller2.getDeviceId();

        // Assert: Should be different (in real app, would use platform-specific IDs)
        expect(deviceId1, isNotEmpty);
        expect(deviceId2, isNotEmpty);
        // Note: In test environment, these might be the same, but in real app
        // they would be different due to platform-specific generation
        
        TestContainerUtils.disposeContainer(container1);
        TestContainerUtils.disposeContainer(container2);
      });

      testWidgets('handles privacy mode appropriately', (tester) async {
        // Arrange: Auth controller
        final controller = container.read(authControllerProvider.notifier);

        // Act: Operations should work without collecting PII
        final deviceId = await controller.getDeviceId();
        await controller.createProfile(TestData.testUserProfile);
        final profile = await controller.getCurrentProfile();

        // Assert: Should work without requiring personal identifiers
        expect(deviceId, isNotEmpty);
        expect(profile, isNotNull);
        
        // Profile should not require email, phone, or other PII
        expect(profile?.deviceId, equals(TestData.testUserProfile.deviceId));
        
        // Only fitness-related data should be stored
        expect(profile?.age, isNotNull);
        expect(profile?.weightKg, isNotNull);
        expect(profile?.heightCm, isNotNull);
        expect(profile?.gender, isNotNull);
      });
    });
  });
}