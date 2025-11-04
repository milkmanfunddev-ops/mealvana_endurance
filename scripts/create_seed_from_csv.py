#!/usr/bin/env python3
"""
Create seed database from CSV exports
Run with: python3 scripts/create_seed_from_csv.py
"""

import sqlite3
import csv
import os

# Paths
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED_DB_PATH = os.path.join(PROJECT_ROOT, 'assets', 'data', 'app_seed.db')
CSV_DIR = os.path.join(PROJECT_ROOT, 'docs')

# Ensure assets/data directory exists
os.makedirs(os.path.dirname(SEED_DB_PATH), exist_ok=True)

# Remove existing seed database
if os.path.exists(SEED_DB_PATH):
    os.remove(SEED_DB_PATH)
    print(f"Deleted existing seed database")

# Create database connection
conn = sqlite3.connect(SEED_DB_PATH)
cursor = conn.cursor()

print("Creating seed database schema...")

# Create tables (simplified SQLite versions)
cursor.execute("""
CREATE TABLE categories (
    id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL
)
""")

cursor.execute("""
CREATE TABLE product_types (
    id TEXT NOT NULL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_plural TEXT NOT NULL,
    sort_order INTEGER,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
)
""")

cursor.execute("""
CREATE TABLE foods (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT,
    image_address TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    serving_amount REAL,
    max_servings_before INTEGER,
    max_servings_during INTEGER,
    sodium_mg INTEGER,
    caffeine_mg INTEGER,
    potassium_mg INTEGER,
    fat_per_serving REAL,
    carbs_per_serving REAL,
    protein_per_serving REAL,
    calories_per_serving INTEGER,
    fluid_ml_per_serving REAL,
    show_in_preferences INTEGER DEFAULT 0,
    display_name TEXT,
    max_servings_after INTEGER,
    is_electrolyte INTEGER DEFAULT 0,
    display_name_plural TEXT,
    to_exclude_from_solver INTEGER DEFAULT 0,
    product_type_id TEXT REFERENCES product_types(id),
    description TEXT,
    serving_description TEXT,
    serving_size TEXT,
    is_essential INTEGER DEFAULT 0,
    is_other_food INTEGER,
    cycling_suitable INTEGER DEFAULT 1,
    swimming_suitable INTEGER DEFAULT 1,
    suitable_for_activities TEXT
)
""")

cursor.execute("""
CREATE TABLE food_categories (
    food_id TEXT NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES categories(id),
    PRIMARY KEY (food_id, category_id)
)
""")

cursor.execute("""
CREATE TABLE meal_types (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0
)
""")

cursor.execute("""
CREATE TABLE carb_loading_foods (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    display_name TEXT,
    carbs_per_serving REAL,
    serving_size TEXT,
    serving_unit TEXT,
    is_default INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
)
""")

cursor.execute("""
CREATE TABLE carb_loading_food_meal_types (
    food_id TEXT NOT NULL,
    meal_type_id TEXT NOT NULL,
    PRIMARY KEY (food_id, meal_type_id)
)
""")

print("Schema created successfully!")

# Helper function to convert boolean strings to integers
def bool_to_int(value):
    if value == '' or value == 'null':
        return None
    if isinstance(value, str):
        return 1 if value.lower() in ('true', 't', '1') else 0
    return 1 if value else 0

# Helper function to convert null strings
def null_to_none(value):
    if value == '' or value == 'null':
        return None
    return value

# Import categories
print("\nImporting categories...")
with open(os.path.join(CSV_DIR, 'categories.csv'), 'r') as f:
    reader = csv.reader(f)
    for row in reader:
        if len(row) >= 2:
            cursor.execute("INSERT INTO categories (id, name) VALUES (?, ?)",
                         (int(row[0]), row[1]))
print(f"Imported {cursor.rowcount} categories")

# Import product_types
print("\nImporting product_types...")
with open(os.path.join(CSV_DIR, 'product_types.csv'), 'r') as f:
    reader = csv.reader(f)
    for row in reader:
        if len(row) >= 4:
            cursor.execute("INSERT INTO product_types (id, code, name, name_plural, sort_order, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                         (row[0], row[1], row[2], row[3],
                          null_to_none(row[4]) if len(row) > 4 else None,
                          null_to_none(row[5]) if len(row) > 5 else None))
print(f"Imported product_types")

# Import foods
print("\nImporting foods...")
with open(os.path.join(CSV_DIR, 'foods.csv'), 'r') as f:
    reader = csv.reader(f)
    count = 0
    for row in reader:
        if len(row) >= 22:
            cursor.execute("""INSERT INTO foods (
                id, name, image_address, created_at, serving_amount,
                max_servings_before, max_servings_during, sodium_mg, caffeine_mg, potassium_mg,
                fat_per_serving, carbs_per_serving, protein_per_serving, calories_per_serving, fluid_ml_per_serving,
                show_in_preferences, display_name, max_servings_after, is_electrolyte, display_name_plural,
                to_exclude_from_solver, product_type_id, description, serving_description, serving_size,
                is_essential, is_other_food, cycling_suitable, swimming_suitable, suitable_for_activities
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                         (row[0], null_to_none(row[1]), null_to_none(row[2]), null_to_none(row[3]), null_to_none(row[4]),
                          null_to_none(row[5]), null_to_none(row[6]), null_to_none(row[7]), null_to_none(row[8]), null_to_none(row[9]),
                          null_to_none(row[10]), null_to_none(row[11]), null_to_none(row[12]), null_to_none(row[13]), null_to_none(row[14]),
                          bool_to_int(row[15]), null_to_none(row[16]), null_to_none(row[17]), bool_to_int(row[18]), null_to_none(row[19]),
                          bool_to_int(row[20]), null_to_none(row[21]),
                          null_to_none(row[22]) if len(row) > 22 else None,
                          null_to_none(row[23]) if len(row) > 23 else None,
                          null_to_none(row[24]) if len(row) > 24 else None,
                          bool_to_int(row[25]) if len(row) > 25 else 0,
                          bool_to_int(row[26]) if len(row) > 26 else None,
                          bool_to_int(row[27]) if len(row) > 27 else 1,
                          bool_to_int(row[28]) if len(row) > 28 else 1,
                          null_to_none(row[29]) if len(row) > 29 else None))
            count += 1
print(f"Imported {count} foods")

# Import food_categories (if file has data)
print("\nImporting food_categories...")
fc_path = os.path.join(CSV_DIR, 'food_categories.csv')
if os.path.exists(fc_path) and os.path.getsize(fc_path) > 0:
    with open(fc_path, 'r') as f:
        reader = csv.reader(f)
        count = 0
        for row in reader:
            if len(row) >= 2:
                cursor.execute("INSERT INTO food_categories (food_id, category_id) VALUES (?, ?)",
                             (row[0], int(row[1])))
                count += 1
    print(f"Imported {count} food_categories")
else:
    print("No food_categories data to import")

# Import meal_types
print("\nImporting meal_types...")
with open(os.path.join(CSV_DIR, 'meal_types.csv'), 'r') as f:
    reader = csv.reader(f)
    count = 0
    for row in reader:
        if len(row) >= 3:
            cursor.execute("INSERT INTO meal_types (id, name, display_name, sort_order) VALUES (?, ?, ?, ?)",
                         (row[0], row[1], row[2],
                          null_to_none(row[3]) if len(row) > 3 else 0))
            count += 1
print(f"Imported {count} meal_types")

# Import carb_loading_foods
print("\nImporting carb_loading_foods...")
with open(os.path.join(CSV_DIR, 'carb_loading_foods.csv'), 'r') as f:
    reader = csv.reader(f)
    count = 0
    for row in reader:
        if len(row) >= 4:
            cursor.execute("""INSERT INTO carb_loading_foods
                           (id, name, display_name, carbs_per_serving, serving_size, serving_unit, is_default, created_at)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                         (row[0], row[1], null_to_none(row[2]), null_to_none(row[3]),
                          null_to_none(row[4]) if len(row) > 4 else None,
                          null_to_none(row[5]) if len(row) > 5 else None,
                          bool_to_int(row[6]) if len(row) > 6 else 1,
                          null_to_none(row[7]) if len(row) > 7 else None))
            count += 1
print(f"Imported {count} carb_loading_foods")

# Import carb_loading_food_meal_types
print("\nImporting carb_loading_food_meal_types...")
with open(os.path.join(CSV_DIR, 'carb_loading_food_meal_types.csv'), 'r') as f:
    reader = csv.reader(f)
    count = 0
    for row in reader:
        if len(row) >= 2:
            cursor.execute("INSERT INTO carb_loading_food_meal_types (food_id, meal_type_id) VALUES (?, ?)",
                         (row[0], row[1]))
            count += 1
print(f"Imported {count} carb_loading_food_meal_types")

# Commit and optimize
conn.commit()

print("\nOptimizing database...")
cursor.execute("VACUUM")

# Verify data
print("\n=== Verification ===")
cursor.execute("SELECT COUNT(*) FROM foods")
print(f"Foods: {cursor.fetchone()[0]}")

cursor.execute("SELECT COUNT(*) FROM categories")
print(f"Categories: {cursor.fetchone()[0]}")

cursor.execute("SELECT COUNT(*) FROM product_types")
print(f"Product types: {cursor.fetchone()[0]}")

cursor.execute("SELECT COUNT(*) FROM carb_loading_foods")
print(f"Carb loading foods: {cursor.fetchone()[0]}")

cursor.execute("SELECT COUNT(*) FROM meal_types")
print(f"Meal types: {cursor.fetchone()[0]}")

cursor.execute("SELECT COUNT(*) FROM carb_loading_food_meal_types")
print(f"Carb loading food meal types: {cursor.fetchone()[0]}")

cursor.execute("SELECT COUNT(*) FROM food_categories")
print(f"Food categories: {cursor.fetchone()[0]}")

# Close connection
conn.close()

# Check file size
file_size = os.path.getsize(SEED_DB_PATH)
file_size_kb = file_size / 1024
file_size_mb = file_size_kb / 1024

print(f"\n✅ Seed database created successfully!")
print(f"Path: {SEED_DB_PATH}")
print(f"Size: {file_size_kb:.1f} KB ({file_size_mb:.2f} MB)")

if file_size_mb > 1:
    print(f"⚠️  Warning: File size is > 1MB. Consider optimizing.")
else:
    print(f"✅ File size is acceptable (< 1MB)")
