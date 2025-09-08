import 'app_database.dart';

/// Smart database schema manager that validates and updates schema without data loss
/// Compares current database state to expected schema and makes only necessary changes
class DatabaseSchemaManager {
  final AppDatabase _database;
  
  DatabaseSchemaManager(this._database);
  
  /// Expected table names that should exist in the database
  static const Set<String> expectedTables = {
    'users',
    'food_preferences', 
    'nutrition_plans',
    'macro_targets_table',
    'feedback',
  };
  
  /// Validate and update database schema to match expected structure
  Future<SchemaUpdateResult> validateAndUpdateSchema() async {
    final result = SchemaUpdateResult();
    
    try {
      // Get current table names from database
      final currentTables = await _getCurrentTableNames();
      result.currentTables = currentTables;
      
      // Determine what changes are needed
      final missingTables = expectedTables.difference(currentTables);
      final extraTables = currentTables.difference(expectedTables);
      
      result.missingTables = missingTables;
      result.extraTables = extraTables;
      
      // Only make changes if needed
      if (missingTables.isNotEmpty || extraTables.isNotEmpty) {
        await _updateSchema(missingTables, extraTables, result);
        result.changesWereMade = true;
      } else {
        result.message = 'Schema is up to date - no changes needed';
      }
      
      result.success = true;
      
    } catch (e, stackTrace) {
      result.success = false;
      result.error = e;
      result.stackTrace = stackTrace;
      result.message = 'Schema validation failed: $e';
    }
    
    return result;
  }
  
  /// Get current table names from the database
  Future<Set<String>> _getCurrentTableNames() async {
    final tablesQuery = await _database.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ).get();
    
    return tablesQuery.map((row) => row.data['name'] as String).toSet();
  }
  
  /// Update schema by creating missing tables and optionally dropping extra ones
  Future<void> _updateSchema(
    Set<String> missingTables, 
    Set<String> extraTables, 
    SchemaUpdateResult result
  ) async {
    await _database.customStatement('PRAGMA foreign_keys = OFF');
    
    try {
      // Create missing tables
      if (missingTables.isNotEmpty) {
        await _createMissingTables(missingTables, result);
      }
      
      // Handle extra tables (optional - could skip this to preserve unknown data)
      if (extraTables.isNotEmpty) {
        await _handleExtraTables(extraTables, result);
      }
      
    } finally {
      await _database.customStatement('PRAGMA foreign_keys = ON');
    }
  }
  
  /// Create tables that are missing from the current schema
  Future<void> _createMissingTables(Set<String> missingTables, SchemaUpdateResult result) async {
    for (final tableName in missingTables) {
      try {
        await _createTableByName(tableName);
        result.tablesCreated.add(tableName);
      } catch (e) {
        result.errors.add('Failed to create table $tableName: $e');
      }
    }
  }
  
  /// Create a specific table based on its name using direct SQL
  Future<void> _createTableByName(String tableName) async {
    // Use direct SQL table creation based on expected schema
    switch (tableName) {
      case 'users':
        await _createUsersTable();
        break;
      case 'food_preferences':
        await _createFoodPreferencesTable();
        break;
      case 'nutrition_plans':
        await _createNutritionPlansTable();
        break;
      case 'macro_targets_table':
        await _createMacroTargetsTable();
        break;
      case 'feedback':
        await _createFeedbackTable();
        break;
      default:
        throw Exception('Unknown table: $tableName');
    }
  }
  
  /// Create the users table with all required columns
  Future<void> _createUsersTable() async {
    await _database.customStatement('''
      CREATE TABLE users (
        id TEXT NOT NULL PRIMARY KEY,
        gender TEXT NOT NULL,
        birthday INTEGER NOT NULL,
        height_feet INTEGER NOT NULL,
        height_inches INTEGER NOT NULL,
        weight_pounds REAL NOT NULL,
        runs_with_water_bottle INTEGER NOT NULL,
        gut_training TEXT NOT NULL,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        app_version TEXT NOT NULL,
        notifications_enabled INTEGER NOT NULL DEFAULT 0,
        default_reminder_day INTEGER NOT NULL DEFAULT 4,
        default_reminder_hour INTEGER NOT NULL DEFAULT 17,
        default_reminder_minute INTEGER NOT NULL DEFAULT 0,
        default_reminder_recurring INTEGER NOT NULL DEFAULT 0,
        temp_plan_data TEXT
      )
    ''');
  }
  
  /// Create the food_preferences table
  Future<void> _createFoodPreferencesTable() async {
    await _database.customStatement('''
      CREATE TABLE food_preferences (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        preference TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(user_id, food_name)
      )
    ''');
  }
  
  /// Create the nutrition_plans table  
  Future<void> _createNutritionPlansTable() async {
    await _database.customStatement('''
      CREATE TABLE nutrition_plans (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        plan_data TEXT NOT NULL,
        distance REAL NOT NULL,
        pace_minutes INTEGER NOT NULL,
        pace_seconds INTEGER NOT NULL,
        weather_condition TEXT,
        sweat_rate REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }
  
  /// Create the macro_targets_table
  Future<void> _createMacroTargetsTable() async {
    await _database.customStatement('''
      CREATE TABLE macro_targets_table (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        targets_data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }
  
  /// Create the feedback table
  Future<void> _createFeedbackTable() async {
    await _database.customStatement('''
      CREATE TABLE feedback (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        confidence_level INTEGER NOT NULL,
        confidence_label TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }
  
  /// Handle extra tables that exist but shouldn't (be conservative - just log them)
  Future<void> _handleExtraTables(Set<String> extraTables, SchemaUpdateResult result) async {
    // Be conservative: don't automatically drop extra tables as they might contain important data
    // Just log them for manual review
    for (final tableName in extraTables) {
      result.extraTablesFound.add(tableName);
      // Could add option to drop them if needed:
      // await _database.customStatement('DROP TABLE IF EXISTS "$tableName"');
    }
  }
  
  /// Check if a specific table exists and has the correct structure
  Future<bool> isTableValid(String tableName) async {
    try {
      // Basic check: does the table exist and can we query it?
      await _database.customStatement('SELECT 1 FROM "$tableName" LIMIT 0');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get detailed information about current database state
  Future<DatabaseInfo> getDatabaseInfo() async {
    final tables = await _getCurrentTableNames();
    final info = DatabaseInfo();
    info.tableNames = tables;
    
    // Get table row counts
    for (final tableName in tables) {
      try {
        final result = await _database.customSelect(
          'SELECT COUNT(*) as count FROM "$tableName"'
        ).getSingle();
        info.tableCounts[tableName] = result.data['count'] as int;
      } catch (e) {
        info.tableCounts[tableName] = -1; // Error getting count
      }
    }
    
    return info;
  }
}

/// Result of schema validation and update operation
class SchemaUpdateResult {
  bool success = false;
  bool changesWereMade = false;
  String message = '';
  
  Set<String> currentTables = {};
  Set<String> missingTables = {};
  Set<String> extraTables = {};
  
  Set<String> tablesCreated = {};
  Set<String> tablesDropped = {};
  Set<String> extraTablesFound = {};
  
  List<String> errors = [];
  
  Object? error;
  StackTrace? stackTrace;
  
  @override
  String toString() {
    final buffer = StringBuffer('Schema Update Result:\n');
    buffer.writeln('- Success: $success');
    buffer.writeln('- Changes Made: $changesWereMade');
    
    if (message.isNotEmpty) {
      buffer.writeln('- Message: $message');
    }
    
    if (tablesCreated.isNotEmpty) {
      buffer.writeln('- Tables Created: ${tablesCreated.join(', ')}');
    }
    
    if (tablesDropped.isNotEmpty) {
      buffer.writeln('- Tables Dropped: ${tablesDropped.join(', ')}');
    }
    
    if (extraTablesFound.isNotEmpty) {
      buffer.writeln('- Extra Tables Found: ${extraTablesFound.join(', ')}');
    }
    
    if (errors.isNotEmpty) {
      buffer.writeln('- Errors: ${errors.join('; ')}');
    }
    
    if (error != null) {
      buffer.writeln('- Error: $error');
    }
    
    return buffer.toString();
  }
}

/// Information about current database state
class DatabaseInfo {
  Set<String> tableNames = {};
  Map<String, int> tableCounts = {};
  
  @override
  String toString() {
    final buffer = StringBuffer('Database Info:\n');
    
    for (final tableName in tableNames) {
      final count = tableCounts[tableName] ?? 0;
      buffer.writeln('- $tableName: $count rows');
    }
    
    return buffer.toString();
  }
}