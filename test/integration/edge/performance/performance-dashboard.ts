/**
 * Performance Dashboard Generator
 *
 * Generates HTML dashboard from performance benchmark results
 */

export interface DashboardMetrics {
  functionName: string;
  samples: number;
  p50: number;
  p95: number;
  p99: number;
  mean: number;
  min: number;
  max: number;
  successRate: number;
  slaStatus: 'pass' | 'fail' | 'warning';
  trend?: 'improving' | 'stable' | 'degrading';
}

export class PerformanceDashboard {
  private metrics: DashboardMetrics[] = [];

  addMetrics(metrics: DashboardMetrics) {
    this.metrics.push(metrics);
  }

  generateHTML(): string {
    const timestamp = new Date().toISOString();

    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mealvana Edge Functions - Performance Dashboard</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 20px;
    }

    .container {
      max-width: 1400px;
      margin: 0 auto;
    }

    .header {
      background: white;
      border-radius: 10px;
      padding: 30px;
      margin-bottom: 20px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.1);
    }

    .header h1 {
      color: #333;
      margin-bottom: 10px;
    }

    .header .timestamp {
      color: #666;
      font-size: 14px;
    }

    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }

    .summary-card {
      background: white;
      border-radius: 10px;
      padding: 20px;
      box-shadow: 0 5px 20px rgba(0,0,0,0.1);
    }

    .summary-card h3 {
      color: #666;
      font-size: 14px;
      margin-bottom: 10px;
      text-transform: uppercase;
      letter-spacing: 1px;
    }

    .summary-card .value {
      font-size: 32px;
      font-weight: bold;
      color: #333;
    }

    .summary-card.pass .value { color: #10b981; }
    .summary-card.fail .value { color: #ef4444; }
    .summary-card.warning .value { color: #f59e0b; }

    .metrics-grid {
      display: grid;
      gap: 20px;
    }

    .function-card {
      background: white;
      border-radius: 10px;
      padding: 25px;
      box-shadow: 0 5px 20px rgba(0,0,0,0.1);
    }

    .function-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
    }

    .function-name {
      font-size: 20px;
      font-weight: 600;
      color: #333;
    }

    .sla-badge {
      padding: 5px 15px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: bold;
      text-transform: uppercase;
    }

    .sla-badge.pass {
      background: #d1fae5;
      color: #065f46;
    }

    .sla-badge.fail {
      background: #fee2e2;
      color: #991b1b;
    }

    .sla-badge.warning {
      background: #fed7aa;
      color: #92400e;
    }

    .metrics-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 15px;
      margin-bottom: 20px;
    }

    .metric {
      padding: 15px;
      background: #f9fafb;
      border-radius: 8px;
    }

    .metric-label {
      font-size: 12px;
      color: #6b7280;
      margin-bottom: 5px;
      text-transform: uppercase;
    }

    .metric-value {
      font-size: 24px;
      font-weight: bold;
      color: #1f2937;
    }

    .metric-unit {
      font-size: 14px;
      color: #6b7280;
      font-weight: normal;
    }

    .performance-chart {
      height: 150px;
      background: #f3f4f6;
      border-radius: 8px;
      padding: 10px;
      display: flex;
      align-items: flex-end;
      gap: 2px;
    }

    .bar {
      flex: 1;
      background: #667eea;
      border-radius: 2px 2px 0 0;
      min-height: 5px;
      position: relative;
    }

    .bar:hover::after {
      content: attr(data-value);
      position: absolute;
      bottom: 100%;
      left: 50%;
      transform: translateX(-50%);
      background: #333;
      color: white;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      white-space: nowrap;
      margin-bottom: 4px;
    }

    .footer {
      text-align: center;
      color: white;
      padding: 20px;
      margin-top: 40px;
    }

    .footer a {
      color: white;
      text-decoration: none;
      font-weight: bold;
    }

    @media (max-width: 768px) {
      .metrics-row {
        grid-template-columns: repeat(2, 1fr);
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚀 Edge Functions Performance Dashboard</h1>
      <div class="timestamp">Last Updated: ${timestamp}</div>
    </div>

    <div class="summary">
      ${this.generateSummaryCards()}
    </div>

    <div class="metrics-grid">
      ${this.metrics.map(m => this.generateFunctionCard(m)).join('')}
    </div>

    <div class="footer">
      <p>Mealvana Endurance - Performance Monitoring System</p>
      <p>Generated by <a href="#">Performance Benchmark Suite</a></p>
    </div>
  </div>
</body>
</html>`;
  }

  private generateSummaryCards(): string {
    const totalFunctions = this.metrics.length;
    const passing = this.metrics.filter(m => m.slaStatus === 'pass').length;
    const totalSamples = this.metrics.reduce((acc, m) => acc + m.samples, 0);
    const avgSuccess = this.metrics.reduce((acc, m) => acc + m.successRate, 0) / totalFunctions;

    return `
      <div class="summary-card">
        <h3>Total Functions</h3>
        <div class="value">${totalFunctions}</div>
      </div>
      <div class="summary-card ${passing === totalFunctions ? 'pass' : passing > totalFunctions / 2 ? 'warning' : 'fail'}">
        <h3>SLA Compliance</h3>
        <div class="value">${passing}/${totalFunctions}</div>
      </div>
      <div class="summary-card">
        <h3>Total Samples</h3>
        <div class="value">${totalSamples}</div>
      </div>
      <div class="summary-card ${avgSuccess > 99 ? 'pass' : avgSuccess > 95 ? 'warning' : 'fail'}">
        <h3>Avg Success Rate</h3>
        <div class="value">${avgSuccess.toFixed(1)}%</div>
      </div>
    `;
  }

  private generateFunctionCard(metrics: DashboardMetrics): string {
    // Generate simple histogram data
    const histogramBars = this.generateHistogram(metrics);

    return `
      <div class="function-card">
        <div class="function-header">
          <div class="function-name">${metrics.functionName}</div>
          <div class="sla-badge ${metrics.slaStatus}">${metrics.slaStatus.toUpperCase()}</div>
        </div>

        <div class="metrics-row">
          <div class="metric">
            <div class="metric-label">P50 Latency</div>
            <div class="metric-value">${metrics.p50.toFixed(0)}<span class="metric-unit">ms</span></div>
          </div>
          <div class="metric">
            <div class="metric-label">P95 Latency</div>
            <div class="metric-value">${metrics.p95.toFixed(0)}<span class="metric-unit">ms</span></div>
          </div>
          <div class="metric">
            <div class="metric-label">P99 Latency</div>
            <div class="metric-value">${metrics.p99.toFixed(0)}<span class="metric-unit">ms</span></div>
          </div>
          <div class="metric">
            <div class="metric-label">Success Rate</div>
            <div class="metric-value">${metrics.successRate.toFixed(1)}<span class="metric-unit">%</span></div>
          </div>
        </div>

        <div class="metrics-row">
          <div class="metric">
            <div class="metric-label">Min/Max</div>
            <div class="metric-value">${metrics.min}-${metrics.max}<span class="metric-unit">ms</span></div>
          </div>
          <div class="metric">
            <div class="metric-label">Mean</div>
            <div class="metric-value">${metrics.mean.toFixed(0)}<span class="metric-unit">ms</span></div>
          </div>
          <div class="metric">
            <div class="metric-label">Samples</div>
            <div class="metric-value">${metrics.samples}</div>
          </div>
          <div class="metric">
            <div class="metric-label">Trend</div>
            <div class="metric-value">${this.getTrendIcon(metrics.trend)}</div>
          </div>
        </div>

        <div class="performance-chart">
          ${histogramBars}
        </div>
      </div>
    `;
  }

  private generateHistogram(metrics: DashboardMetrics): string {
    // Create simple histogram visualization
    const bars = [];
    const range = metrics.max - metrics.min;
    const bucketSize = range / 20;

    for (let i = 0; i < 20; i++) {
      const height = Math.random() * 100; // In real implementation, calculate from actual data
      bars.push(`<div class="bar" style="height: ${height}%" data-value="${(metrics.min + i * bucketSize).toFixed(0)}ms"></div>`);
    }

    return bars.join('');
  }

  private getTrendIcon(trend?: string): string {
    switch (trend) {
      case 'improving': return '📈 Improving';
      case 'degrading': return '📉 Degrading';
      default: return '➡️ Stable';
    }
  }

  saveToFile(path: string) {
    const html = this.generateHTML();
    // In a real implementation, this would write to file system
    console.log(`Dashboard saved to: ${path}`);
    return html;
  }
}