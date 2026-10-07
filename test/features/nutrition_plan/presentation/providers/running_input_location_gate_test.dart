// Seam test through the real notifier (Finding 100-004): the running form
// asks the weather service for location only when the activity's date is
// upcoming and inside the forecast window.
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/running_input_controller.dart';
import 'package:mealvana_endurance/features/weather/application/weather_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockWeatherService extends Mock implements WeatherService {}

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  late _MockWeatherService weather;
  late ProviderContainer container;

  setUp(() {
    weather = _MockWeatherService();
    when(() => weather.getCurrentLocation()).thenAnswer((_) async => null);
    when(
      () => weather.getWeatherForecast(
        location: any(named: 'location'),
        activityDate: any(named: 'activityDate'),
      ),
    ).thenThrow(Exception('offline'));
    final users = _MockUserRepository();
    when(() => users.getCurrentUser()).thenAnswer((_) async => null);
    container = ProviderContainer(
      overrides: [
        weatherServiceProvider.overrideWith((ref) => weather),
        userRepositoryProvider.overrideWith((_) async => users),
      ],
    );
    addTearDown(container.dispose);
  });

  RunningInputController controller() =>
      container.read(runningInputControllerProvider.notifier);

  test('a past activity never asks for location', () async {
    final c = controller();
    c.initializeWithDate(DateTime.now().subtract(const Duration(days: 1)));

    await c.fetchLocationIfNeeded();

    verifyNever(() => weather.getCurrentLocation());
  });

  test('an activity beyond the forecast window never asks either', () async {
    final c = controller();
    c.initializeWithDate(DateTime.now().add(const Duration(days: 40)));

    await c.fetchLocationIfNeeded();

    verifyNever(() => weather.getCurrentLocation());
  });

  test('tomorrow\'s activity asks once', () async {
    final c = controller();
    c.initializeWithDate(DateTime.now().add(const Duration(days: 1)));

    await c.fetchLocationIfNeeded();

    verify(() => weather.getCurrentLocation()).called(1);
  });

  test('moving a past date into the window asks then', () async {
    final c = controller();
    c.initializeWithDate(DateTime.now().subtract(const Duration(days: 3)));
    await c.fetchLocationIfNeeded();
    verifyNever(() => weather.getCurrentLocation());

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    c.updateDateTime(tomorrow, const TimeOfDay(hour: 7, minute: 0));
    await Future<void>.delayed(Duration.zero);

    verify(() => weather.getCurrentLocation()).called(1);
  });
}
