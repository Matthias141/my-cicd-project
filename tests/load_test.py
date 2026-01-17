"""
Load Testing with Locust - AWS Lambda API Performance Tests

This script simulates realistic user traffic patterns to test:
- Response times under load
- Throughput capacity
- Error rates at scale
- Concurrent user handling
"""

from locust import HttpUser, task, between, events
import json
import random
import time
from datetime import datetime

# Performance thresholds
RESPONSE_TIME_THRESHOLD = 500  # ms
ERROR_RATE_THRESHOLD = 1  # percent

class APIUser(HttpUser):
    """Simulates a typical API user"""

    # Wait between 1-3 seconds between requests (realistic user behavior)
    wait_time = between(1, 3)

    def on_start(self):
        """Called when a simulated user starts"""
        self.api_key = "test-api-key-12345"  # Would come from environment in real scenario
        self.headers = {
            "Content-Type": "application/json",
            "X-API-Key": self.api_key
        }

    @task(10)  # Weight: 10 (most common request)
    def get_health(self):
        """Test health check endpoint"""
        with self.client.get(
            "/dev/health",
            headers=self.headers,
            catch_response=True,
            name="/health"
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")

    @task(8)  # Weight: 8
    def get_home(self):
        """Test main endpoint"""
        with self.client.get(
            "/dev/",
            headers=self.headers,
            catch_response=True,
            name="/"
        ) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if "message" in data:
                        response.success()
                    else:
                        response.failure("Response missing 'message' field")
                except json.JSONDecodeError:
                    response.failure("Response is not valid JSON")
            else:
                response.failure(f"Got status code {response.status_code}")

    @task(5)  # Weight: 5
    def get_items_paginated(self):
        """Test pagination endpoint with various parameters"""
        page = random.randint(1, 10)
        limit = random.choice([10, 20, 50, 100])
        search = random.choice(["test", "product", "user", ""])

        with self.client.get(
            f"/dev/items?page={page}&limit={limit}&search={search}",
            headers=self.headers,
            catch_response=True,
            name="/items (paginated)"
        ) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 400:
                response.success()  # Expected for invalid params
            else:
                response.failure(f"Got status code {response.status_code}")

    @task(3)  # Weight: 3
    def post_validate_input(self):
        """Test input validation endpoint"""
        test_data = {
            "name": f"Test User {random.randint(1, 1000)}",
            "email": f"user{random.randint(1, 1000)}@example.com",
            "age": random.randint(18, 80),
            "message": "This is a test message for load testing"
        }

        with self.client.post(
            "/dev/validate",
            json=test_data,
            headers=self.headers,
            catch_response=True,
            name="/validate"
        ) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if data.get("status") == "success":
                        response.success()
                    else:
                        response.failure("Validation failed unexpectedly")
                except json.JSONDecodeError:
                    response.failure("Response is not valid JSON")
            else:
                response.failure(f"Got status code {response.status_code}")

    @task(2)  # Weight: 2 (stress test)
    def rapid_fire_requests(self):
        """Simulate burst traffic - rapid successive requests"""
        for _ in range(5):
            self.client.get("/dev/health", headers=self.headers, name="/health (burst)")
            time.sleep(0.1)  # 100ms between burst requests


class StressTestUser(HttpUser):
    """Simulates aggressive/stress testing scenarios"""

    wait_time = between(0.1, 0.5)  # Much faster request rate

    def on_start(self):
        self.api_key = "stress-test-key"
        self.headers = {
            "Content-Type": "application/json",
            "X-API-Key": self.api_key
        }

    @task(5)
    def stress_health_check(self):
        """Hammer the health endpoint"""
        self.client.get("/dev/health", headers=self.headers, name="/health (stress)")

    @task(3)
    def stress_with_invalid_data(self):
        """Test error handling under load"""
        invalid_data = {
            "name": "<script>alert('xss')</script>",  # Should be blocked
            "email": "not-an-email",
            "age": 999,
            "message": "x" * 10000  # Too long
        }

        self.client.post(
            "/dev/validate",
            json=invalid_data,
            headers=self.headers,
            name="/validate (invalid)"
        )


# Event listeners for custom metrics and reporting
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when test starts"""
    print(f"\n{'='*60}")
    print(f"🚀 Load Test Started: {datetime.now()}")
    print(f"{'='*60}\n")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when test stops - print summary"""
    stats = environment.stats

    print(f"\n{'='*60}")
    print(f"📊 Load Test Summary")
    print(f"{'='*60}")
    print(f"Total Requests: {stats.total.num_requests}")
    print(f"Total Failures: {stats.total.num_failures}")
    print(f"Failure Rate: {stats.total.fail_ratio * 100:.2f}%")
    print(f"Average Response Time: {stats.total.avg_response_time:.2f}ms")
    print(f"Median Response Time: {stats.total.median_response_time:.2f}ms")
    print(f"95th Percentile: {stats.total.get_response_time_percentile(0.95):.2f}ms")
    print(f"99th Percentile: {stats.total.get_response_time_percentile(0.99):.2f}ms")
    print(f"Max Response Time: {stats.total.max_response_time:.2f}ms")
    print(f"Requests/sec: {stats.total.total_rps:.2f}")
    print(f"{'='*60}\n")

    # Check if performance meets thresholds
    avg_response_time = stats.total.avg_response_time
    error_rate = stats.total.fail_ratio * 100

    print("🎯 Performance Validation:")
    if avg_response_time <= RESPONSE_TIME_THRESHOLD:
        print(f"✅ Response Time: {avg_response_time:.2f}ms (threshold: {RESPONSE_TIME_THRESHOLD}ms)")
    else:
        print(f"❌ Response Time: {avg_response_time:.2f}ms (threshold: {RESPONSE_TIME_THRESHOLD}ms)")

    if error_rate <= ERROR_RATE_THRESHOLD:
        print(f"✅ Error Rate: {error_rate:.2f}% (threshold: {ERROR_RATE_THRESHOLD}%)")
    else:
        print(f"❌ Error Rate: {error_rate:.2f}% (threshold: {ERROR_RATE_THRESHOLD}%)")

    print(f"{'='*60}\n")


# Test scenarios - can be run with different user counts
"""
Usage Examples:

# Baseline test (simulate 10 concurrent users)
locust -f load_test.py --headless -u 10 -r 2 -t 1m --host=https://your-api.execute-api.us-east-1.amazonaws.com

# Stress test (simulate 100 concurrent users)
locust -f load_test.py --headless -u 100 -r 10 -t 2m --host=https://your-api.execute-api.us-east-1.amazonaws.com

# Spike test (rapid user increase)
locust -f load_test.py --headless -u 500 -r 50 -t 30s --host=https://your-api.execute-api.us-east-1.amazonaws.com

# Endurance test (sustained load)
locust -f load_test.py --headless -u 50 -r 5 -t 10m --host=https://your-api.execute-api.us-east-1.amazonaws.com

# With HTML report
locust -f load_test.py --headless -u 50 -r 5 -t 2m --host=https://your-api.execute-api.us-east-1.amazonaws.com --html=report.html

Flags:
-u: Number of users
-r: Spawn rate (users per second)
-t: Test duration
--host: Target API URL
--html: Generate HTML report
"""
