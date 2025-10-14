# Edge Function Integration Tests

This directory contains **integration and E2E tests for all edge functions** with shared dependencies and configuration.

## 📁 Structure

```
test/integration/edge/
├── package.json          # Shared dependencies for all edge functions
├── package-lock.json     # Dependency lock file
├── node_modules/         # Shared node_modules (no duplication!)
├── test-config.ts        # Centralized test configuration
├── .env.test            # Shared environment variables
├── vitest.config.ts     # Shared test runner configuration
├── tsconfig.json        # Shared TypeScript configuration
└── {function-name}/     # Individual edge function tests
    ├── README.md        # Function-specific documentation
    ├── integration.test.ts
    ├── e2e.test.ts
    └── (no config files - uses shared configs)
```

## 🎯 Key Benefits

### ✅ **No Node Modules Duplication**
- Single `node_modules/` directory shared across all edge functions
- Faster install times and reduced disk space usage
- Consistent dependency versions across all tests

### ✅ **Centralized Configuration**
- Shared authentication configuration in `test-config.ts`
- Common environment variables in `.env.test`
- Unified Vitest and TypeScript configurations

### ✅ **Easy to Scale**
- Adding new edge function tests requires only creating a new directory
- No need to duplicate package.json or configuration files
- Consistent testing patterns across all functions

## 🚀 Running Tests

```bash
# Install shared dependencies (run once)
npm install

# Run all edge function tests
npm test

# Run specific edge function tests
npm run test:generate-ai-nutrition-plan

# Run all E2E tests
npm run test:e2e

# Watch mode
npm run test:watch
```

## 🔧 Adding New Edge Function Tests

1. Create new directory: `mkdir {function-name}/`
2. Add test files: `{function-name}/*.test.ts`
3. Update package.json scripts if needed
4. Import shared config: `import { TEST_CONFIG } from '../test-config'`

**No need to create:**
- ❌ package.json (use shared)
- ❌ node_modules (use shared)
- ❌ vitest.config.ts (use shared)
- ❌ tsconfig.json (use shared)
- ❌ .env.test (use shared)

## 🔐 Authentication

All edge function tests use the centralized authentication from `test-config.ts`:

```typescript
import { getEdgeFunctionHeaders } from '../test-config';

const response = await fetch(url, {
  method: 'POST',
  headers: getEdgeFunctionHeaders(), // ✅ Consistent auth
  body: JSON.stringify(data)
});
```

## 📊 Current Test Coverage

### Generate AI Nutrition Plan
- **Working Integration**: 10/10 tests passing ✅
- **E2E System Tests**: 9/9 tests passing ✅
- **Performance**: Sub-second response times
- **Authentication**: Fixed service role key usage

## 🎯 Next Steps

When adding tests for other edge functions:

1. **generate-macros** - Macro calculation testing
2. **create-nutrition-plan** - Plan creation validation
3. **barcode-lookup** - Product scanning integration
4. **carb-loading** - Carb loading plan generation

Follow the same pattern:
- Create `{function-name}/` directory
- Add test files using shared configuration
- Update package.json scripts as needed
- Document in function-specific README