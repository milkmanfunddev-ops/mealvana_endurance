import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../application/recipe_service.dart';
import '../../domain/recipe.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Recipe> _recipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;
  String? _errorMessage;
  RecipeType? _selectedType;

  /// Chip display order: All, Breakfast, Mains, Snacks, Workout Fuel, Recovery.
  static const List<RecipeType> _chipOrder = [
    RecipeType.breakfast,
    RecipeType.mains,
    RecipeType.snacks,
    RecipeType.workoutFuel,
    RecipeType.recovery,
  ];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(recipeServiceProvider);

      // Hydrate the local cache on-demand (no-op when already fresh).
      // The user must be authenticated to reach this screen, so currentUser
      // should never be null here; fall back to empty string to satisfy the
      // interface — the cache-empty guard in the repository will still force a
      // remote fetch, which will succeed as long as the Supabase session is
      // active.
      final userId =
          ref.read(appExternalDepsProvider).supabaseClient.auth.currentUser?.id ??
              '';
      await service.ensureSynced(userId, force: force);

      final recipes = await service.getAllRecipes();
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _filteredRecipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load recipes. Please try again.';
      });
    }
  }

  void _filterRecipes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecipes = _recipes.where((recipe) {
        final matchesSearch = recipe.name.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query);
        final matchesType =
            _selectedType == null || recipe.type == _selectedType;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search recipes...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _filterRecipes(),
                ),
                const SizedBox(height: 16),
                // Type filter chips: All, Breakfast, Mains, Snacks, Workout Fuel, Recovery
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedType == null,
                        onSelected: () {
                          setState(() => _selectedType = null);
                          _filterRecipes();
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._chipOrder.map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: type.displayLabel,
                            isSelected: _selectedType == type,
                            onSelected: () {
                              setState(() => _selectedType = type);
                              _filterRecipes();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Recipes list / loading / error states
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[700],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecipes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredRecipes.isEmpty) {
      return const Center(
        child: Text(
          'No recipes found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRecipes(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredRecipes.length,
        itemBuilder: (context, index) {
          final recipe = _filteredRecipes[index];
          return _RecipeCard(recipe: recipe);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to recipe detail screen
          MealvanaSnackbar.showInfo(context, 'Recipe: ${recipe.name}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail image
                  _RecipeThumbnail(
                    imageUrl: recipe.imageUrl,
                    type: recipe.type,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.description,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        _getTypeIcon(recipe.type),
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${recipe.prepTimeMinutes} min',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _NutritionChip(
                    label: '${recipe.nutrition.calories.round()} cal',
                    icon: Icons.local_fire_department,
                  ),
                  const SizedBox(width: 8),
                  _NutritionChip(
                    label:
                        '${recipe.nutrition.carbohydratesGrams.round()}g carbs',
                    icon: Icons.grain,
                  ),
                  const SizedBox(width: 8),
                  _NutritionChip(
                    label:
                        '${recipe.nutrition.proteinGrams.round()}g protein',
                    icon: Icons.fitness_center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(RecipeType type) {
    switch (type) {
      case RecipeType.breakfast:
        return Icons.free_breakfast;
      case RecipeType.mains:
        return Icons.restaurant;
      case RecipeType.snacks:
        return Icons.cookie;
      case RecipeType.workoutFuel:
        return Icons.directions_run;
      case RecipeType.recovery:
        return Icons.restore;
    }
  }
}

/// Small rounded thumbnail (~56 px) shown beside each recipe card row.
///
/// Falls back to a category-coloured icon if the image URL is null or fails
/// to load.  Uses [Image.network] with an [errorBuilder] — no extra package
/// required.
class _RecipeThumbnail extends StatelessWidget {
  const _RecipeThumbnail({
    required this.imageUrl,
    required this.type,
  });

  final String? imageUrl;
  final RecipeType type;

  static const double _size = 56;

  Color _categoryColor(BuildContext context) {
    switch (type) {
      case RecipeType.breakfast:
        return Colors.orange.shade300;
      case RecipeType.mains:
        return Colors.teal.shade300;
      case RecipeType.snacks:
        return Colors.amber.shade300;
      case RecipeType.workoutFuel:
        return Colors.blue.shade300;
      case RecipeType.recovery:
        return Colors.purple.shade300;
    }
  }

  IconData _categoryIcon() {
    switch (type) {
      case RecipeType.breakfast:
        return Icons.free_breakfast;
      case RecipeType.mains:
        return Icons.restaurant;
      case RecipeType.snacks:
        return Icons.cookie;
      case RecipeType.workoutFuel:
        return Icons.directions_run;
      case RecipeType.recovery:
        return Icons.restore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(context);

    final placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_categoryIcon(), color: color, size: 28),
    );

    if (imageUrl == null) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: _size,
            height: _size,
            color: color.withValues(alpha: 0.15),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NutritionChip extends StatelessWidget {
  const _NutritionChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
