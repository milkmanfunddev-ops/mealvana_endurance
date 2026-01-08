#!/bin/bash
# =============================================================================
# Mealvana Endurance - Web Build Script for Vercel
# =============================================================================
# This script generates .dart_defines.json from environment variables and
# builds the Flutter web app.
#
# Required Environment Variables:
#   SUPABASE_URL          - Supabase project URL
#   SUPABASE_ANON_KEY     - Supabase anonymous/public key
#
# Optional Environment Variables (have defaults):
#   APP_ENVIRONMENT       - 'dev' or 'prod' (default: 'prod')
#   SENTRY_DSN            - Sentry DSN for error tracking
#   SENTRY_ENVIRONMENT    - Sentry environment name
#   MIXPANEL_PROJECT_TOKEN - Mixpanel analytics token
#   WIREDASH_PROJECT_ID   - Wiredash feedback project ID
#   WIREDASH_SECRET       - Wiredash secret key
#   USDA_API_KEY          - USDA FoodData Central API key
#
# Usage:
#   ./scripts/build_web.sh              # Production build
#   ./scripts/build_web.sh --dev        # Development build
#   ./scripts/build_web.sh --local      # Local build (reads from .env.web.local)
# =============================================================================

set -e  # Exit on error

echo "========================================"
echo "Mealvana Endurance - Web Build"
echo "========================================"

# Parse arguments
BUILD_MODE="release"
USE_LOCAL_ENV=false

for arg in "$@"; do
  case $arg in
    --dev)
      BUILD_MODE="debug"
      ;;
    --local)
      USE_LOCAL_ENV=true
      ;;
  esac
done

# Load local environment if requested
if [ "$USE_LOCAL_ENV" = true ] && [ -f ".env.web.local" ]; then
  echo "Loading environment from .env.web.local..."
  # Source JSON file as environment variables
  export SUPABASE_URL=$(grep -o '"SUPABASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' .env.web.local | cut -d'"' -f4)
  export SUPABASE_ANON_KEY=$(grep -o '"SUPABASE_ANON_KEY"[[:space:]]*:[[:space:]]*"[^"]*"' .env.web.local | cut -d'"' -f4)
  export SENTRY_DSN=$(grep -o '"SENTRY_DSN"[[:space:]]*:[[:space:]]*"[^"]*"' .env.web.local | cut -d'"' -f4)
  export MIXPANEL_PROJECT_TOKEN=$(grep -o '"MIXPANEL_PROJECT_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"' .env.web.local | cut -d'"' -f4)
  export APP_ENVIRONMENT=$(grep -o '"APP_ENVIRONMENT"[[:space:]]*:[[:space:]]*"[^"]*"' .env.web.local | cut -d'"' -f4)
fi

# Validate required environment variables
if [ -z "$SUPABASE_URL" ]; then
  echo "ERROR: SUPABASE_URL environment variable is required"
  exit 1
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "ERROR: SUPABASE_ANON_KEY environment variable is required"
  exit 1
fi

echo "Environment: ${APP_ENVIRONMENT:-prod}"
echo "Build mode: $BUILD_MODE"
echo ""

# Set defaults for optional variables
APP_ENVIRONMENT="${APP_ENVIRONMENT:-prod}"
SENTRY_DSN="${SENTRY_DSN:-}"
SENTRY_ENVIRONMENT="${SENTRY_ENVIRONMENT:-}"
MIXPANEL_PROJECT_TOKEN="${MIXPANEL_PROJECT_TOKEN:-}"
WIREDASH_PROJECT_ID="${WIREDASH_PROJECT_ID:-mealvana-endurance-vn1pxw3}"
WIREDASH_SECRET="${WIREDASH_SECRET:-}"
USDA_API_KEY="${USDA_API_KEY:-}"

# Generate .dart_defines.json
echo "Generating .dart_defines.json..."

# Use printf to avoid heredoc issues with special characters
# Strip any trailing newlines/whitespace from env vars
SUPABASE_URL=$(echo -n "$SUPABASE_URL" | tr -d '\n\r')
SUPABASE_ANON_KEY=$(echo -n "$SUPABASE_ANON_KEY" | tr -d '\n\r')
SENTRY_DSN=$(echo -n "$SENTRY_DSN" | tr -d '\n\r')
SENTRY_ENVIRONMENT=$(echo -n "$SENTRY_ENVIRONMENT" | tr -d '\n\r')
MIXPANEL_PROJECT_TOKEN=$(echo -n "$MIXPANEL_PROJECT_TOKEN" | tr -d '\n\r')
WIREDASH_PROJECT_ID=$(echo -n "$WIREDASH_PROJECT_ID" | tr -d '\n\r')
WIREDASH_SECRET=$(echo -n "$WIREDASH_SECRET" | tr -d '\n\r')
USDA_API_KEY=$(echo -n "$USDA_API_KEY" | tr -d '\n\r')
APP_ENVIRONMENT=$(echo -n "$APP_ENVIRONMENT" | tr -d '\n\r')

printf '%s\n' '{' \
  "  \"SUPABASE_URL\": \"$SUPABASE_URL\"," \
  "  \"SUPABASE_ANON_KEY\": \"$SUPABASE_ANON_KEY\"," \
  "  \"SENTRY_DSN\": \"$SENTRY_DSN\"," \
  "  \"SENTRY_ENVIRONMENT\": \"$SENTRY_ENVIRONMENT\"," \
  "  \"MIXPANEL_PROJECT_TOKEN\": \"$MIXPANEL_PROJECT_TOKEN\"," \
  "  \"WIREDASH_PROJECT_ID\": \"$WIREDASH_PROJECT_ID\"," \
  "  \"WIREDASH_SECRET\": \"$WIREDASH_SECRET\"," \
  "  \"USDA_API_KEY\": \"$USDA_API_KEY\"," \
  "  \"APP_ENVIRONMENT\": \"$APP_ENVIRONMENT\"" \
  '}' > .dart_defines.json

echo ".dart_defines.json created successfully"
echo ""

# Determine Flutter binary path
# On Vercel, Flutter is cloned to ./flutter
# Locally, use system Flutter
if [ -f "./flutter/bin/flutter" ]; then
  FLUTTER="./flutter/bin/flutter"
  echo "Using Vercel Flutter: $FLUTTER"
else
  FLUTTER="flutter"
  echo "Using system Flutter: $(which flutter)"
fi

# Build the web app
echo ""
echo "Building Flutter web app..."
echo "========================================"

# Show the dart defines file for debugging
echo "Contents of .dart_defines.json:"
cat .dart_defines.json
echo ""
echo "========================================"

if [ "$BUILD_MODE" = "release" ]; then
  echo "Running: $FLUTTER build web --release --wasm --pwa-strategy=none -t lib/main_web.dart --dart-define-from-file=.dart_defines.json"
  $FLUTTER build web \
    --release \
    --wasm \
    --pwa-strategy=none \
    -t lib/main_web.dart \
    --dart-define-from-file=.dart_defines.json 2>&1
  BUILD_EXIT_CODE=$?
  echo "Flutter build exit code: $BUILD_EXIT_CODE"
  if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo "ERROR: Flutter build failed with exit code $BUILD_EXIT_CODE"
    exit $BUILD_EXIT_CODE
  fi
else
  $FLUTTER build web \
    --profile \
    --pwa-strategy=none \
    -t lib/main_web.dart \
    --dart-define-from-file=.dart_defines.json
fi

echo ""
echo "========================================"
echo "Build completed successfully!"
echo "Output: build/web/"
echo "========================================"

# Clean up .dart_defines.json (contains secrets)
# Note: On Vercel this is fine since the build container is ephemeral
# Uncomment if you want to clean up locally:
# rm -f .dart_defines.json
