#!/usr/bin/env python3
"""
Performance Benchmark Analyzer
Analyzes Locust test results and generates performance reports
"""

import json
import sys
import csv
from datetime import datetime
from pathlib import Path

def analyze_locust_stats(stats_file):
    """Analyze Locust statistics and generate performance report"""

    print("=" * 80)
    print("PERFORMANCE BENCHMARK REPORT")
    print("=" * 80)
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Stats File: {stats_file}")
    print("=" * 80)
    print()

    # Read CSV stats
    with open(stats_file, 'r') as f:
        reader = csv.DictReader(f)
        stats = list(reader)

    # Filter out aggregated rows
    endpoint_stats = [s for s in stats if s['Type'] != 'Aggregated']

    # Calculate overall metrics
    total_requests = sum(int(s['Request Count']) for s in endpoint_stats)
    total_failures = sum(int(s['Failure Count']) for s in endpoint_stats)

    if total_requests > 0:
        failure_rate = (total_failures / total_requests) * 100
    else:
        failure_rate = 0

    print("📊 OVERALL PERFORMANCE")
    print("-" * 80)
    print(f"Total Requests:        {total_requests:,}")
    print(f"Total Failures:        {total_failures:,}")
    print(f"Failure Rate:          {failure_rate:.2f}%")
    print()

    # Endpoint breakdown
    print("📈 ENDPOINT PERFORMANCE")
    print("-" * 80)
    print(f"{'Endpoint':<40} {'Requests':<12} {'Avg (ms)':<12} {'P95 (ms)':<12} {'Failures'}")
    print("-" * 80)

    for stat in endpoint_stats:
        endpoint = stat['Name'][:38]
        requests = int(stat['Request Count'])
        avg_response = float(stat['Average Response Time']) if stat['Average Response Time'] else 0
        p95_response = float(stat['95%']) if stat['95%'] else 0
        failures = int(stat['Failure Count'])

        # Color coding based on performance
        status = "✅" if avg_response < 500 and failures == 0 else "⚠️" if avg_response < 1000 else "❌"

        print(f"{status} {endpoint:<38} {requests:<10,} {avg_response:<10.0f} {p95_response:<10.0f} {failures}")

    print()

    # Performance thresholds
    print("🎯 PERFORMANCE THRESHOLDS")
    print("-" * 80)

    thresholds = {
        'Average Response Time': {'target': 500, 'unit': 'ms'},
        'P95 Response Time': {'target': 1000, 'unit': 'ms'},
        'Failure Rate': {'target': 1, 'unit': '%'},
        'Availability': {'target': 99.9, 'unit': '%'}
    }

    # Get aggregate stats
    agg_stats = next((s for s in stats if s['Type'] == 'Aggregated'), None)

    if agg_stats:
        avg_response = float(agg_stats['Average Response Time']) if agg_stats['Average Response Time'] else 0
        p95_response = float(agg_stats['95%']) if agg_stats['95%'] else 0
        availability = 100 - failure_rate

        results = {
            'Average Response Time': avg_response,
            'P95 Response Time': p95_response,
            'Failure Rate': failure_rate,
            'Availability': availability
        }

        passed = 0
        failed = 0

        for metric, value in results.items():
            threshold = thresholds[metric]
            target = threshold['target']
            unit = threshold['unit']

            if metric in ['Failure Rate']:
                status = "✅ PASS" if value <= target else "❌ FAIL"
                comparison = f"{value:.2f}{unit} <= {target}{unit}"
            else:
                status = "✅ PASS" if value <= target else "❌ FAIL"
                comparison = f"{value:.0f}{unit} <= {target}{unit}"

            if "PASS" in status:
                passed += 1
            else:
                failed += 1

            print(f"{status:<10} {metric:<25} {comparison}")

        print()
        print(f"Summary: {passed} passed, {failed} failed out of {passed + failed} thresholds")

        # Exit code based on results
        if failed > 0:
            print()
            print("⚠️  Some performance thresholds were not met!")
            return 1
        else:
            print()
            print("✅ All performance thresholds met!")
            return 0

    return 0

def generate_recommendations(stats_file):
    """Generate performance improvement recommendations"""

    print()
    print("💡 RECOMMENDATIONS")
    print("-" * 80)

    with open(stats_file, 'r') as f:
        reader = csv.DictReader(f)
        stats = list(reader)

    endpoint_stats = [s for s in stats if s['Type'] != 'Aggregated']

    recommendations = []

    for stat in endpoint_stats:
        endpoint = stat['Name']
        avg_response = float(stat['Average Response Time']) if stat['Average Response Time'] else 0
        failures = int(stat['Failure Count'])

        if avg_response > 1000:
            recommendations.append(f"🔴 {endpoint}: High latency ({avg_response:.0f}ms) - consider caching or optimization")
        elif avg_response > 500:
            recommendations.append(f"🟡 {endpoint}: Moderate latency ({avg_response:.0f}ms) - monitor and optimize if needed")

        if failures > 0:
            recommendations.append(f"🔴 {endpoint}: {failures} failures detected - investigate error logs")

    if not recommendations:
        print("✅ No performance issues detected!")
    else:
        for i, rec in enumerate(recommendations, 1):
            print(f"{i}. {rec}")

    print()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python analyze-performance.py <locust-stats.csv>")
        sys.exit(1)

    stats_file = sys.argv[1]

    if not Path(stats_file).exists():
        print(f"Error: Stats file '{stats_file}' not found")
        sys.exit(1)

    try:
        exit_code = analyze_locust_stats(stats_file)
        generate_recommendations(stats_file)
        sys.exit(exit_code)
    except Exception as e:
        print(f"Error analyzing stats: {e}")
        sys.exit(1)
