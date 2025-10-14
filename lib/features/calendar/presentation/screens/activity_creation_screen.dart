import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart';

/// Activity Creation Screen with tabbed interface.
///
/// Allows users to create different types of activities:
/// - Running: Full distance/pace/gut entry workflow
/// - Biking: Under construction placeholder
/// - Swimming: Under construction placeholder
///
/// After completing the Running tab workflow (which includes nutrition plan generation),
/// the user is returned to the Activities List screen.
class ActivityCreationScreen extends ConsumerStatefulWidget {
  final DateTime selectedDate;

  const ActivityCreationScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  ConsumerState<ActivityCreationScreen> createState() => _ActivityCreationScreenState();
}

class _ActivityCreationScreenState extends ConsumerState<ActivityCreationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: AppTheme.baseCream,
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: SafeArea(
            child: Row(
              children: [
                // Back arrow button
                CustomAppBarBackButton(),
                // Tabs
                Expanded(
                  child: TabBar(
                    
                    controller: _tabController,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    indicatorColor: AppTheme.primary900,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    labelColor: AppTheme.primary900,
                    unselectedLabelColor: Colors.grey[400],
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.directions_run, size: 24),
                        text: 'Running',
                      ),
                      Tab(
                        icon: Icon(Icons.directions_bike, size: 24),
                        text: 'Biking',
                      ),
                      Tab(
                        icon: Icon(Icons.pool, size: 24),
                        text: 'Swimming',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Running tab - embed the existing distance/pace/gut entry workflow
          DistancePaceGutEntryScreen(
            initialDate: widget.selectedDate,
          ),

          // Biking tab - under construction
          _buildUnderConstructionTab(
            icon: Icons.directions_bike,
            title: 'Biking',
            message: 'Biking activities coming soon!',
          ),

          // Swimming tab - under construction
          _buildUnderConstructionTab(
            icon: Icons.pool,
            title: 'Swimming',
            message: 'Swimming activities coming soon!',
          ),
        ],
      ),
    );
  }

  Widget _buildUnderConstructionTab({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction, size: 16, color: Colors.orange[800]),
                const SizedBox(width: 8),
                Text(
                  'Under Construction',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
