import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { createClient } from '@supabase/supabase-js';

/**
 * Performance Benchmarking Suite for All Edge Functions
 *
 * This suite aggregates performance metrics across all edge functions,
 * establishes SLA targets, and provides comprehensive performance analysis.
 */

const supabaseUrl = 'http://127.0.0.1:54321';
const supabaseKey = process.env.SUPABASE_ANON_KEY || '';
const supabase = createClient(supabaseUrl, supabaseKey);

// Performance SLA Targets (milliseconds)
const SLA_TARGETS = {
  // Algorithmic functions (should be fast)
  'generate-macros': {
    p50: 100,  // 50th percentile
    p95: 200,  // 95th percentile
    p99: 500,  // 99th percentile
    max: 1000  // Maximum acceptable
  },
  'barcode-lookup': {
    p50: 500,  // API calls included
    p95: 1500,
    p99: 3000,
    max: 5000
  },
  'save-food-preferences': {
    p50: 150,
    p95: 300,
    p99: 600,
    max: 1000
  },
  // AI-powered functions (more lenient)
  'generate-ai-nutrition-plan': {
    p50: 3000,
    p95: 8000,
    p99: 15000,
    max: 30000
  },
  'create-nutrition-plan': {
    p50: 2000,
    p95: 5000,
    p99: 10000,
    max: 20000
  },
  'carb-loading': {
    p50: 1500,
    p95: 3000,
    p99: 6000,
    max: 10000
  }
};

// Performance metrics collector
interface PerformanceMetrics {
  functionName: string;
  samples: number[];
  p50: number;
  p95: number;
  p99: number;
  mean: number;
  min: number;
  max: number;
  successRate: number;
  errors: string[];
}

class PerformanceCollector {
  private metrics: Map<string, PerformanceMetrics> = new Map();

  recordSample(functionName: string, duration: number, success: boolean = true, error?: string) {
    if (!this.metrics.has(functionName)) {
      this.metrics.set(functionName, {
        functionName,
        samples: [],
        p50: 0,
        p95: 0,
        p99: 0,
        mean: 0,
        min: Infinity,
        max: 0,
        successRate: 100,
        errors: []
      });
    }

    const metric = this.metrics.get(functionName)!;

    if (success) {
      metric.samples.push(duration);
    } else if (error) {
      metric.errors.push(error);
    }

    // Update calculations
    this.calculateStatistics(functionName);
  }

  private calculateStatistics(functionName: string) {
    const metric = this.metrics.get(functionName)!;
    const samples = [...metric.samples].sort((a, b) => a - b);

    if (samples.length === 0) return;

    metric.min = Math.min(...samples);
    metric.max = Math.max(...samples);
    metric.mean = samples.reduce((a, b) => a + b, 0) / samples.length;

    // Calculate percentiles
    metric.p50 = this.percentile(samples, 50);
    metric.p95 = this.percentile(samples, 95);
    metric.p99 = this.percentile(samples, 99);

    // Calculate success rate
    const totalAttempts = samples.length + metric.errors.length;
    metric.successRate = (samples.length / totalAttempts) * 100;
  }

  private percentile(sorted: number[], p: number): number {
    const index = Math.ceil((p / 100) * sorted.length) - 1;
    return sorted[Math.max(0, index)];
  }

  getReport(functionName: string): PerformanceMetrics | undefined {
    return this.metrics.get(functionName);
  }

  getAllReports(): PerformanceMetrics[] {
    return Array.from(this.metrics.values());
  }

  checkSLA(functionName: string): { passed: boolean; violations: string[] } {
    const metric = this.metrics.get(functionName);
    const sla = SLA_TARGETS[functionName as keyof typeof SLA_TARGETS];

    if (!metric || !sla) {
      return { passed: true, violations: [] };
    }

    const violations: string[] = [];

    if (metric.p50 > sla.p50) {
      violations.push(`P50: ${metric.p50.toFixed(0)}ms > ${sla.p50}ms`);
    }
    if (metric.p95 > sla.p95) {
      violations.push(`P95: ${metric.p95.toFixed(0)}ms > ${sla.p95}ms`);
    }
    if (metric.p99 > sla.p99) {
      violations.push(`P99: ${metric.p99.toFixed(0)}ms > ${sla.p99}ms`);
    }
    if (metric.max > sla.max) {
      violations.push(`Max: ${metric.max.toFixed(0)}ms > ${sla.max}ms`);
    }
    if (metric.successRate < 99) {
      violations.push(`Success rate: ${metric.successRate.toFixed(1)}% < 99%`);
    }

    return {
      passed: violations.length === 0,
      violations
    };
  }

  generateMarkdownReport(): string {
    const reports = this.getAllReports();
    let markdown = '# Performance Benchmark Report\n\n';
    markdown += `Generated: ${new Date().toISOString()}\n\n`;

    markdown += '## Summary\n\n';
    markdown += '| Function | Samples | P50 (ms) | P95 (ms) | P99 (ms) | Mean (ms) | Success Rate | SLA Status |\n';
    markdown += '|----------|---------|----------|----------|----------|-----------|--------------|------------|\n';

    for (const report of reports) {
      const slaCheck = this.checkSLA(report.functionName);
      const status = slaCheck.passed ? '✅ PASS' : '❌ FAIL';

      markdown += `| ${report.functionName} | ${report.samples.length} | `;
      markdown += `${report.p50.toFixed(0)} | ${report.p95.toFixed(0)} | `;
      markdown += `${report.p99.toFixed(0)} | ${report.mean.toFixed(0)} | `;
      markdown += `${report.successRate.toFixed(1)}% | ${status} |\n`;
    }

    markdown += '\n## Detailed Results\n\n';

    for (const report of reports) {
      const slaCheck = this.checkSLA(report.functionName);

      markdown += `### ${report.functionName}\n\n`;
      markdown += `- **Samples**: ${report.samples.length}\n`;
      markdown += `- **Min/Max**: ${report.min.toFixed(0)}ms / ${report.max.toFixed(0)}ms\n`;
      markdown += `- **Percentiles**: P50=${report.p50.toFixed(0)}ms, P95=${report.p95.toFixed(0)}ms, P99=${report.p99.toFixed(0)}ms\n`;
      markdown += `- **Mean**: ${report.mean.toFixed(0)}ms\n`;
      markdown += `- **Success Rate**: ${report.successRate.toFixed(1)}%\n`;

      if (!slaCheck.passed) {
        markdown += `- **⚠️ SLA Violations**:\n`;
        slaCheck.violations.forEach(v => markdown += `  - ${v}\n`);
      }

      if (report.errors.length > 0) {
        markdown += `- **Errors**: ${report.errors.length} occurrences\n`;
      }

      markdown += '\n';
    }

    return markdown;
  }
}

// Helper function to measure edge function performance
async function measureEdgeFunction(
  functionName: string,
  payload: any,
  collector: PerformanceCollector,
  samples: number = 10
): Promise<void> {
  console.log(`\n🎯 Benchmarking ${functionName} (${samples} samples)...`);

  for (let i = 0; i < samples; i++) {
    const start = Date.now();

    try {
      const { data, error } = await supabase.functions.invoke(functionName, {
        body: payload
      });

      const duration = Date.now() - start;

      if (error) {
        collector.recordSample(functionName, duration, false, error.message);
      } else {
        collector.recordSample(functionName, duration, true);
      }

      // Small delay to avoid rate limiting
      if (i < samples - 1) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    } catch (err) {
      const duration = Date.now() - start;
      collector.recordSample(functionName, duration, false, String(err));
    }
  }

  const report = collector.getReport(functionName)!;
  console.log(`  ✅ Complete: P50=${report.p50.toFixed(0)}ms, P95=${report.p95.toFixed(0)}ms`);
}

describe('🚀 Edge Functions Performance Benchmark Suite', () => {
  let collector: PerformanceCollector;
  let deviceId: string;

  beforeAll(() => {
    collector = new PerformanceCollector();
    deviceId = `test-device-${Date.now()}`;
  });

  afterAll(() => {
    // Generate and save the performance report
    const report = collector.generateMarkdownReport();
    console.log('\n' + '='.repeat(80));
    console.log(report);
    console.log('='.repeat(80));
  });

  describe('📊 Individual Function Benchmarks', () => {
    it('should benchmark generate-macros function', async () => {
      const payload = {
        distance: 26.2,
        pace: '8:00',
        weight_lbs: 150,
        gut_training_level: 'medium',
        temperature_f: 65
      };

      await measureEdgeFunction('generate-macros', payload, collector, 20);

      const slaCheck = collector.checkSLA('generate-macros');
      expect(slaCheck.passed, `SLA violations: ${slaCheck.violations.join(', ')}`).toBe(true);
    });

    it('should benchmark barcode-lookup function', async () => {
      const barcodes = [
        '096619756803',  // Clif Bar
        '722252100900',  // GU Energy Gel
        '052000131512',  // Gatorade
      ];

      for (const barcode of barcodes) {
        await measureEdgeFunction('barcode-lookup', { barcode }, collector, 5);
      }

      const slaCheck = collector.checkSLA('barcode-lookup');
      expect(slaCheck.passed, `SLA violations: ${slaCheck.violations.join(', ')}`).toBe(true);
    });

    it('should benchmark save-food-preferences function', async () => {
      const payload = {
        device_id: deviceId,
        preferences: {
          'Banana': 'like',
          'Gel': 'willing_to_try',
          'Sports Drink': 'like',
          'Oatmeal': 'dislike'
        }
      };

      await measureEdgeFunction('save-food-preferences', payload, collector, 15);

      const slaCheck = collector.checkSLA('save-food-preferences');
      expect(slaCheck.passed, `SLA violations: ${slaCheck.violations.join(', ')}`).toBe(true);
    });
  });

  describe('🔄 Load Pattern Benchmarks', () => {
    it('should handle burst load pattern', async () => {
      console.log('\n🌊 Testing burst load pattern...');

      // Simulate burst of requests
      const promises = [];
      const burstSize = 10;

      for (let i = 0; i < burstSize; i++) {
        promises.push(
          measureEdgeFunction('generate-macros', {
            distance: 10 + i,
            pace: '7:30',
            weight_lbs: 150,
            gut_training_level: 'medium'
          }, collector, 1)
        );
      }

      const start = Date.now();
      await Promise.all(promises);
      const totalTime = Date.now() - start;

      console.log(`  Burst of ${burstSize} requests completed in ${totalTime}ms`);
      expect(totalTime).toBeLessThan(10000); // Should handle burst within 10s
    });

    it('should handle sustained load pattern', async () => {
      console.log('\n📈 Testing sustained load pattern...');

      const duration = 5000; // 5 seconds
      const requestInterval = 200; // Request every 200ms
      const start = Date.now();
      let requestCount = 0;

      while (Date.now() - start < duration) {
        const payload = {
          distance: Math.random() * 20 + 3,
          pace: `${Math.floor(Math.random() * 4 + 6)}:${Math.floor(Math.random() * 60).toString().padStart(2, '0')}`,
          weight_lbs: Math.floor(Math.random() * 50 + 120)
        };

        // Fire and forget
        measureEdgeFunction('generate-macros', payload, collector, 1).catch(() => {});

        requestCount++;
        await new Promise(resolve => setTimeout(resolve, requestInterval));
      }

      console.log(`  Sustained load: ${requestCount} requests over ${duration}ms`);

      // Check that performance didn't degrade under sustained load
      const report = collector.getReport('generate-macros')!;
      expect(report.p95).toBeLessThan(500); // P95 should stay under 500ms even under load
    });
  });

  describe('🏁 Performance Race Conditions', () => {
    it('should handle concurrent requests to different functions', async () => {
      console.log('\n🎭 Testing concurrent multi-function calls...');

      const operations = [
        supabase.functions.invoke('generate-macros', {
          body: { distance: 13.1, pace: '8:00', weight_lbs: 160 }
        }),
        supabase.functions.invoke('barcode-lookup', {
          body: { barcode: '096619756803' }
        }),
        supabase.functions.invoke('save-food-preferences', {
          body: { device_id: deviceId, preferences: { 'Water': 'like' } }
        })
      ];

      const start = Date.now();
      const results = await Promise.allSettled(operations);
      const duration = Date.now() - start;

      // All should succeed
      const succeeded = results.filter(r => r.status === 'fulfilled').length;
      expect(succeeded).toBe(3);

      // Total time should be less than sum of individual times (parallelization)
      expect(duration).toBeLessThan(2000);
      console.log(`  All functions completed in ${duration}ms (parallel execution)`);
    });

    it('should measure cold start performance', async () => {
      console.log('\n❄️ Testing cold start performance...');

      // Wait for functions to potentially go cold
      console.log('  Waiting 30s for functions to cool down...');
      await new Promise(resolve => setTimeout(resolve, 30000));

      // Measure cold start
      const start = Date.now();
      const { data, error } = await supabase.functions.invoke('generate-macros', {
        body: { distance: 5, pace: '9:00', weight_lbs: 150 }
      });
      const coldStartTime = Date.now() - start;

      expect(error).toBeNull();
      expect(coldStartTime).toBeLessThan(3000); // Cold start should be under 3s

      console.log(`  Cold start time: ${coldStartTime}ms`);

      // Compare with warm start
      const warmStart = Date.now();
      await supabase.functions.invoke('generate-macros', {
        body: { distance: 5, pace: '9:00', weight_lbs: 150 }
      });
      const warmStartTime = Date.now() - warmStart;

      console.log(`  Warm start time: ${warmStartTime}ms`);
      console.log(`  Cold start penalty: ${(coldStartTime - warmStartTime)}ms`);
    }, 35000); // Extended timeout for cold start test
  });

  describe('📈 Performance Trends Analysis', () => {
    it('should analyze performance distribution', async () => {
      console.log('\n📊 Analyzing performance distribution...');

      // Run many samples for statistical significance
      await measureEdgeFunction('generate-macros', {
        distance: 10,
        pace: '8:00',
        weight_lbs: 150
      }, collector, 50);

      const report = collector.getReport('generate-macros')!;

      // Calculate standard deviation
      const mean = report.mean;
      const variance = report.samples.reduce((acc, val) => {
        return acc + Math.pow(val - mean, 2);
      }, 0) / report.samples.length;
      const stdDev = Math.sqrt(variance);
      const coefficientOfVariation = (stdDev / mean) * 100;

      console.log(`  Mean: ${mean.toFixed(0)}ms`);
      console.log(`  Std Dev: ${stdDev.toFixed(0)}ms`);
      console.log(`  CV: ${coefficientOfVariation.toFixed(1)}%`);

      // Performance should be consistent (low coefficient of variation)
      expect(coefficientOfVariation).toBeLessThan(50); // CV should be under 50%
    });

    it('should identify performance outliers', async () => {
      console.log('\n🔍 Identifying performance outliers...');

      const samples = 30;
      await measureEdgeFunction('generate-macros', {
        distance: 10,
        pace: '8:00',
        weight_lbs: 150
      }, collector, samples);

      const report = collector.getReport('generate-macros')!;

      // Calculate IQR for outlier detection
      const sorted = [...report.samples].sort((a, b) => a - b);
      const q1 = sorted[Math.floor(samples * 0.25)];
      const q3 = sorted[Math.floor(samples * 0.75)];
      const iqr = q3 - q1;
      const lowerBound = q1 - 1.5 * iqr;
      const upperBound = q3 + 1.5 * iqr;

      const outliers = report.samples.filter(s => s < lowerBound || s > upperBound);
      const outlierPercentage = (outliers.length / samples) * 100;

      console.log(`  Q1: ${q1.toFixed(0)}ms, Q3: ${q3.toFixed(0)}ms`);
      console.log(`  Outlier bounds: [${lowerBound.toFixed(0)}ms, ${upperBound.toFixed(0)}ms]`);
      console.log(`  Outliers: ${outliers.length}/${samples} (${outlierPercentage.toFixed(1)}%)`);

      // Outliers should be rare
      expect(outlierPercentage).toBeLessThan(10); // Less than 10% outliers
    });
  });

  describe('🎯 SLA Compliance Report', () => {
    it('should generate comprehensive SLA compliance report', async () => {
      console.log('\n📋 Generating SLA Compliance Report...\n');

      const functions = [
        'generate-macros',
        'barcode-lookup',
        'save-food-preferences'
      ];

      let allPassed = true;
      const results: any[] = [];

      for (const func of functions) {
        const report = collector.getReport(func);
        if (!report) continue;

        const slaCheck = collector.checkSLA(func);
        const sla = SLA_TARGETS[func as keyof typeof SLA_TARGETS];

        results.push({
          function: func,
          sla,
          actual: {
            p50: report.p50,
            p95: report.p95,
            p99: report.p99,
            max: report.max
          },
          passed: slaCheck.passed,
          violations: slaCheck.violations
        });

        if (!slaCheck.passed) allPassed = false;

        console.log(`${func}:`);
        console.log(`  SLA Status: ${slaCheck.passed ? '✅ PASS' : '❌ FAIL'}`);

        if (slaCheck.violations.length > 0) {
          console.log('  Violations:');
          slaCheck.violations.forEach(v => console.log(`    - ${v}`));
        }

        console.log('  Performance vs SLA:');
        console.log(`    P50: ${report.p50.toFixed(0)}ms (target: ${sla.p50}ms) ${report.p50 <= sla.p50 ? '✅' : '❌'}`);
        console.log(`    P95: ${report.p95.toFixed(0)}ms (target: ${sla.p95}ms) ${report.p95 <= sla.p95 ? '✅' : '❌'}`);
        console.log(`    P99: ${report.p99.toFixed(0)}ms (target: ${sla.p99}ms) ${report.p99 <= sla.p99 ? '✅' : '❌'}`);
        console.log('');
      }

      // Overall summary
      console.log('='.repeat(60));
      console.log('OVERALL SLA COMPLIANCE:', allPassed ? '✅ ALL PASS' : '❌ FAILURES DETECTED');
      console.log('='.repeat(60));

      expect(allPassed, 'One or more functions failed SLA compliance').toBe(true);
    });
  });
});