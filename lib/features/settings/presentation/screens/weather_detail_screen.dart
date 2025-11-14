import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Weather Detail Screen - Kyle's Design System
/// Weather information and forecast display
class WeatherDetailScreen extends ConsumerStatefulWidget {
  const WeatherDetailScreen({super.key});

  @override
  ConsumerState<WeatherDetailScreen> createState() => _WeatherDetailScreenState();
}

class _WeatherDetailScreenState extends ConsumerState<WeatherDetailScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _animationController,
    );
    
    // Track weather screen opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(appExternalDepsProvider);
      analytics.analytics.track('weather_detail_opened');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildContent(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Weather',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      actions: [
        // Refresh button
        IconButton(
          onPressed: () => _refreshWeather(context),
          icon: Icon(
            FontAwesomeIcons.arrowsRotate,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // Current weather card
        Expanded(
          flex: 2,
          child: _buildCurrentWeather(context),
        ),
        
        const SizedBox(width: AppSpacing.sm),
        
        // Forecast section
        Expanded(
          flex: 3,
          child: _buildForecastSection(context),
        ),
      ],
    );
  }

  Widget _buildCurrentWeather(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                FontAwesomeIcons.cloudSun,
                size: AppIconSizes.md,
                color: AppColors.electrolyte,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Current Weather',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Weather display
          _buildWeatherDisplay(context),
          
          const SizedBox(height: AppSpacing.md),
          
          // Weather details
          _buildWeatherDetails(context),
        ],
      ),
    );
  }

  Widget _buildWeatherDisplay(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.electrolyte.withOpacity(0.8),
            AppColors.orange.withOpacity(0.6),
          ],
        ),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Stack(
        children: [
          // Weather icon
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Icon(
              FontAwesomeIcons.sun,
              size: 80,
              color: AppColors.cream,
            ),
          ),
          
          // Temperature
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  '72°F',
                  style: AppTextStyles.dataNumberLarge.copyWith(
                    color: AppColors.cream,
                  ),
                ),
                Text(
                  'Partly Cloudy',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.cream,
                  ),
                ),
              ],
            ),
          ),
          
          // Location
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.locationDot,
                  size: AppIconSizes.controlIcon,
                  color: AppColors.cream,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'San Francisco, CA',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.cream,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetails(BuildContext context) {
    return Column(
      children: [
        // Detail rows
        _buildDetailRow(
          context: context,
          icon: FontAwesomeIcons.wind,
          label: 'Wind',
          value: '12 mph NW',
        ),
        
        const SizedBox(height: AppSpacing.sm),
        
        _buildDetailRow(
          context: context,
          icon: FontAwesomeIcons.droplet,
          label: 'Humidity',
          value: '65%',
        ),
        
        const SizedBox(height: AppSpacing.sm),
        
        _buildDetailRow(
          context: context,
          icon: FontAwesomeIcons.gauge,
          label: 'Pressure',
          value: '30.15 in',
        ),
        
        const SizedBox(height: AppSpacing.sm),
        
        _buildDetailRow(
          context: context,
          icon: FontAwesomeIcons.eye,
          label: 'Visibility',
          value: '10 miles',
        ),
        
        const SizedBox(height: AppSpacing.sm),
        
        _buildDetailRow(
          context: context,
          icon: FontAwesomeIcons.sun,
          label: 'UV Index',
          value: '6 (High)',
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.electrolyte.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: AppIconSizes.controlIcon,
            color: AppColors.electrolyte,
          ),
        ),
        
        const SizedBox(width: AppSpacing.md),
        
        // Label
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        
        const SizedBox(width: AppSpacing.sm),
        
        // Value
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildForecastSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                FontAwesomeIcons.calendarDays,
                size: AppIconSizes.md,
                color: AppColors.electrolyte,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '7-Day Forecast',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: AppColors.electrolyte,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Daily'),
              Tab(text: 'Hourly'),
            ],
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Tab content
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyForecast(context),
                _buildHourlyForecast(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyForecast(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = _getForecastDay(index);
        final weather = _getForecastWeather(index);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildForecastDayCard(context, day, weather),
        );
      },
    );
  }

  Widget _buildHourlyForecast(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: 24,
      itemBuilder: (context, index) {
        final hour = _getForecastHour(index);
        final weather = _getForecastWeather(index);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildForecastHourCard(context, hour, weather),
        );
      },
    );
  }

  Widget _buildForecastDayCard(BuildContext context, String day, Map<String, dynamic> weather) {
    return BaseCard(
      child: Row(
        children: [
          // Day info
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: AppTextStyles.subtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  weather['condition'] as String,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Weather icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.electrolyte.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getWeatherIcon(weather['condition'] as String),
              size: AppIconSizes.lg,
              color: AppColors.electrolyte,
            ),
          ),
          
          // Temperature range
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${weather['high']}°',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${weather['low']}°',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastHourCard(BuildContext context, String hour, Map<String, dynamic> weather) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withOpacity(0.1),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          // Time
          Expanded(
            flex: 2,
            child: Text(
              hour,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          
          // Weather icon
          Icon(
            _getWeatherIcon(weather['condition'] as String),
            size: AppIconSizes.md,
            color: AppColors.electrolyte,
          ),
          
          // Temperature
          Expanded(
            flex: 2,
            child: Text(
              '${weather['temp']}°',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getForecastDay(int index) {
    final now = DateTime.now();
    final date = now.add(Duration(days: index));
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
  }

  String _getForecastHour(int index) {
    final now = DateTime.now();
    final hour = now.add(Duration(hours: index));
    return '${hour.hour.toString().padLeft(2, '0')}:00';
  }

  Map<String, dynamic> _getForecastWeather(int index) {
    // Mock forecast data
    final conditions = ['Sunny', 'Partly Cloudy', 'Cloudy', 'Rainy', 'Thunderstorms'];
    final temps = [72, 75, 68, 65, 70, 73, 69];
    final highs = [78, 80, 72, 68, 75, 77, 71];
    final lows = [65, 68, 62, 60, 65, 67, 63];
    
    return {
      'condition': conditions[index % conditions.length],
      'temp': temps[index % temps.length],
      'high': highs[index % highs.length],
      'low': lows[index % lows.length],
    };
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition) {
      case 'Sunny':
        return FontAwesomeIcons.sun;
      case 'Partly Cloudy':
        return FontAwesomeIcons.cloudSun;
      case 'Cloudy':
        return FontAwesomeIcons.cloud;
      case 'Rainy':
        return FontAwesomeIcons.cloudRain;
      case 'Thunderstorms':
        return FontAwesomeIcons.cloudBolt;
      default:
        return FontAwesomeIcons.cloud;
    }
  }

  void _refreshWeather(BuildContext context) {
    // Track weather refresh
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('weather_refreshed');

    // Show refresh indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshing weather data...'),
        backgroundColor: AppColors.electrolyte,
      ),
    );

    // In a real app, this would fetch fresh weather data
    Future.delayed(const Duration(seconds: 2), () {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weather data updated'),
          backgroundColor: AppColors.electrolyte,
        ),
      );
    });
  }
}