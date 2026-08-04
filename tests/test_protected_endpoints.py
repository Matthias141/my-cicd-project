"""
Integration tests for protected API endpoints
"""
import pytest
import json
import sys
import os
import hmac
import hashlib
import time

# Add app directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))

from fixtures import (
    TEST_API_KEY,
    TEST_API_KEY_INFO,
    TEST_ADMIN_API_KEY,
    TEST_ADMIN_KEY_INFO,
)


class TestProtectedEndpoints:
    """Test protected API endpoints"""

    @pytest.fixture
    def app(self):
        """Create Flask app for testing"""
        from main import app
        app.config['TESTING'] = True
        return app

    @pytest.fixture
    def client(self, app):
        """Create test client"""
        return app.test_client()

    def test_public_endpoints_accessible(self, client):
        """Test that public endpoints are accessible without API key"""
        # Root endpoint
        response = client.get('/')
        assert response.status_code == 200

        # Health endpoint
        response = client.get('/dev/health')
        assert response.status_code == 200

        # Home endpoint
        response = client.get('/dev/')
        assert response.status_code == 200

    def test_protected_endpoint_without_api_key(self, client):
        """Test protected endpoint returns 401 without API key"""
        response = client.get('/dev/protected')

        assert response.status_code == 401
        data = json.loads(response.data)
        assert 'error' in data

    def test_protected_endpoint_with_valid_api_key(self, patched_api_keys, client):
        """Test protected endpoint succeeds with valid API key"""
        # patched_api_keys (tests/conftest.py) injects TEST_API_KEY into the
        # real auth.API_KEYS - this exercises the actual require_api_key()
        # decorator and get_api_key_info() lookup end-to-end, not a mocked
        # stand-in for them.
        response = client.get(
            '/dev/protected',
            headers={'X-API-Key': TEST_API_KEY}
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert data['api_key_id'] == TEST_API_KEY_INFO['key_id']

    def test_admin_endpoint_without_admin_permission(self, patched_api_keys, client):
        """Test admin endpoint returns 403 without admin permission"""
        # TEST_API_KEY_INFO['permissions'] is ['read'] - genuinely lacks
        # admin, rather than a mock asserting it does.
        response = client.get(
            '/dev/admin/stats',
            headers={'X-API-Key': TEST_API_KEY}
        )

        assert response.status_code == 403
        data = json.loads(response.data)
        assert 'error' in data
        assert 'Insufficient permissions' in data['error']

    def test_admin_endpoint_with_admin_permission(self, patched_api_keys, client):
        """Test admin endpoint succeeds with admin permission"""
        # TEST_ADMIN_API_KEY is a distinct key from TEST_API_KEY, present in
        # API_KEYS at the same time (see conftest.py) - proves the admin
        # check is genuinely permission-based, not just "any key works."
        response = client.get(
            '/dev/admin/stats',
            headers={'X-API-Key': TEST_ADMIN_API_KEY}
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert 'stats' in data


class TestSignedEndpoints:
    """Test HMAC signed endpoints"""

    @pytest.fixture
    def app(self):
        """Create Flask app for testing"""
        from main import app
        app.config['TESTING'] = True
        return app

    @pytest.fixture
    def client(self, app):
        """Create test client"""
        return app.test_client()

    def test_signed_endpoint_without_signature(self, client):
        """Test signed endpoint returns 401 without signature"""
        response = client.post(
            '/dev/signed',
            json={'name': 'Test', 'email': 'test@example.com', 'age': 30, 'message': 'test'},
            headers={'X-API-Key': 'test-key'}
        )

        assert response.status_code == 401

    def test_signed_endpoint_with_valid_signature(self, patched_api_keys, client):
        """Test signed endpoint succeeds with valid signature"""
        # Real HMAC over the exact raw body bytes being sent, using
        # TEST_API_KEY_INFO['secret'] - exercises the actual
        # validate_signature() implementation end-to-end (message =
        # timestamp + raw body, HMAC-SHA256), not a mock asserting True.
        # Body is serialized once and sent as raw data (not via the
        # `json=` kwarg) so what's signed is byte-identical to what's sent.
        payload = {'name': 'John Doe', 'email': 'john@example.com', 'age': 30, 'message': 'test'}
        body = json.dumps(payload)
        timestamp = str(int(time.time()))
        message = f"{timestamp}{body}".encode('utf-8')
        signature = hmac.new(
            TEST_API_KEY_INFO['secret'].encode('utf-8'),
            message,
            hashlib.sha256
        ).hexdigest()

        response = client.post(
            '/dev/signed',
            data=body,
            content_type='application/json',
            headers={
                'X-API-Key': TEST_API_KEY,
                'X-Signature': signature,
                'X-Timestamp': timestamp
            }
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert data['security']['signature_verified'] is True

    def test_signed_endpoint_with_invalid_signature(self, patched_api_keys, client):
        """Test signed endpoint fails with invalid signature"""
        # Valid API key, deliberately wrong signature - exercises the real
        # validate_signature() rejecting a genuine mismatch, not a mock
        # asserting False.
        payload = {'name': 'John Doe', 'email': 'john@example.com', 'age': 30, 'message': 'test'}
        body = json.dumps(payload)
        timestamp = str(int(time.time()))

        response = client.post(
            '/dev/signed',
            data=body,
            content_type='application/json',
            headers={
                'X-API-Key': TEST_API_KEY,
                'X-Signature': 'deliberately-wrong-signature',
                'X-Timestamp': timestamp
            }
        )

        assert response.status_code == 401


class TestInputValidation:
    """Test Pydantic input validation"""

    @pytest.fixture
    def app(self):
        """Create Flask app for testing"""
        from main import app
        app.config['TESTING'] = True
        return app

    @pytest.fixture
    def client(self, app):
        """Create test client"""
        return app.test_client()

    def test_validate_endpoint_with_valid_data(self, client):
        """Test validation endpoint accepts valid data"""
        valid_data = {
            'name': 'John Doe',
            'email': 'john@example.com',
            'age': 30,
            'message': 'This is a test message'
        }

        response = client.post('/dev/validate', json=valid_data)

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'

    def test_validate_endpoint_with_invalid_email(self, client):
        """Test validation endpoint rejects invalid email"""
        invalid_data = {
            'name': 'John Doe',
            'email': 'not-an-email',
            'age': 30,
            'message': 'Test'
        }

        response = client.post('/dev/validate', json=invalid_data)

        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'error' in data

    def test_validate_endpoint_with_invalid_age(self, client):
        """Test validation endpoint rejects invalid age"""
        invalid_data = {
            'name': 'John Doe',
            'email': 'john@example.com',
            'age': 150,  # Too old
            'message': 'Test'
        }

        response = client.post('/dev/validate', json=invalid_data)

        assert response.status_code == 400

    def test_validate_endpoint_with_missing_field(self, client):
        """Test validation endpoint rejects missing required fields"""
        incomplete_data = {
            'name': 'John Doe',
            'email': 'john@example.com'
            # Missing age and message
        }

        response = client.post('/dev/validate', json=incomplete_data)

        assert response.status_code == 400


class TestSecurityHeaders:
    """Test security headers are properly set"""

    @pytest.fixture
    def app(self):
        """Create Flask app for testing"""
        from main import app
        app.config['TESTING'] = True
        return app

    @pytest.fixture
    def client(self, app):
        """Create test client"""
        return app.test_client()

    def test_security_headers_present(self, client):
        """Test that all security headers are present in responses"""
        response = client.get('/dev/')

        # Check for security headers
        assert 'X-Frame-Options' in response.headers
        assert response.headers['X-Frame-Options'] == 'DENY'

        assert 'X-Content-Type-Options' in response.headers
        assert response.headers['X-Content-Type-Options'] == 'nosniff'

        assert 'X-XSS-Protection' in response.headers
        assert '1; mode=block' in response.headers['X-XSS-Protection']

        assert 'Content-Security-Policy' in response.headers
        assert "default-src 'self'" in response.headers['Content-Security-Policy']

        assert 'Strict-Transport-Security' in response.headers
        assert 'Referrer-Policy' in response.headers
        assert 'Permissions-Policy' in response.headers
