import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../../application/recipe_service.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

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
  RecipeType? _selectedType;

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

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    try {
      final recipes = await ref.read(recipeServiceProvider).getAllRecipes();
      setState(() {
        _recipes = recipes;
        _filteredRecipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterRecipes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecipes = _recipes.where((recipe) {
        final matchesSearch = recipe.name.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query);
        final matchesType = _selectedType == null || recipe.type == _selectedType;
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
                // Type filter
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
                      ...RecipeType.values.map((type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: _getTypeDisplayName(type),
                          isSelected: _selectedType == type,
                          onSelected: () {
                            setState(() => _selectedType = type);
                            _filterRecipes();
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Recipes list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecipes.isEmpty
                    ? const Center(
                        child: Text(
                          'No recipes found',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = _filteredRecipes[index];
                          return _RecipeCard(recipe: recipe);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _getTypeDisplayName(RecipeType type) {
    switch (type) {
      case RecipeType.preRun:
        return 'Pre-Run';
      case RecipeType.duringRun:
        return 'During Run';
      case RecipeType.postRun:
        return 'Post-Run';
      case RecipeType.general:
        return 'General';
    }
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
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
                    label: '${recipe.nutrition.carbohydratesGrams.round()}g carbs',
                    icon: Icons.grain,
                  ),
                  const SizedBox(width: 8),
                  _NutritionChip(
                    label: '${recipe.nutrition.proteinGrams.round()}g protein',
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
      case RecipeType.preRun:
        return Icons.schedule;
      case RecipeType.duringRun:
        return Icons.directions_run;
      case RecipeType.postRun:
        return Icons.restore;
      case RecipeType.general:
        return Icons.restaurant;
    }
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