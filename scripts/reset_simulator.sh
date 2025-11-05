#!/bin/bash

# Script to completely delete app from iOS simulator for fresh install testing
# Usage: ./scripts/reset_simulator.sh

echo "🧹 Deleting Mealvana Endurance from iOS simulator..."

# Get the bundle ID from the app
BUNDLE_ID="com.leemartin.mealvanaEndurance"

# Get the booted simulator device ID
DEVICE_ID=$(xcrun simctl list devices | grep "Booted" | grep -oE '\([0-9A-F-]+\)' | tr -d '()')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No booted simulator found. Please start a simulator first."
    exit 1
fi

echo "📱 Found booted simulator: $DEVICE_ID"

# Uninstall the app
echo "🗑️  Uninstalling app..."
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || echo "App was not installed"

# Verify it's gone
APP_STATUS=$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" 2>&1)
if [[ "$APP_STATUS" == *"No such file"* ]] || [[ "$APP_STATUS" == *"not installed"* ]]; then
    echo "✅ App successfully deleted from simulator"
    echo ""
    echo "🚀 Now run: flutter run"
    echo "   You should see fresh install logs with seed DB copy"
else
    echo "⚠️  App may still be present. Try manually deleting from simulator."
fi
