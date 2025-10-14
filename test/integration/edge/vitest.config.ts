import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    name: 'edge-functions',
    environment: 'node',
    globals: true,
    testTimeout: 30000,
    hookTimeout: 30000,
    reporters: ['verbose'],
    coverage: {
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'test/',
        '*.config.ts'
      ]
    },
    include: [
      '**/*.test.{js,ts}',
      '**/*.spec.{js,ts}'
    ]
  }
});