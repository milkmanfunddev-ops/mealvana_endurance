#!/bin/bash

# Script to fix Flutter 3.35 breaking changes
# This fixes:
# 1. DropdownButtonFormField: initialValue -> value
# 2. Color: withOpacity() -> withValues(alpha:)

echo "Fixing Flutter 3.35 breaking changes..."

# Fix 1: Replace DropdownButtonFormField initialValue with value
echo "Fixing DropdownButtonFormField initialValue -> value..."
find lib -name "*.dart" -type f -exec sed -i '' 's/DropdownButtonFormField\(.*\)\n\(.*\)initialValue:/DropdownButtonFormField\1\n\2value:/g' {} \;

# Alternative approach using perl for multiline
find lib -name "*.dart" -type f -exec perl -i -pe 's/initialValue:(\s+)(?=\S)/value:$1/g if /DropdownButtonFormField/' {} \;

# Fix 2: Replace withOpacity with withValues(alpha:)
echo "Fixing withOpacity -> withValues(alpha:)..."
find lib -name "*.dart" -type f -exec perl -i -pe 's/\.withOpacity\(([^)]+)\)/.withValues(alpha: $1)/g' {} \;

echo "Done! Running flutter analyze to verify..."
flutter analyze
