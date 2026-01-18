"""
Integration tests for protected API endpoints
"""
import pytest
import json
import sys
import os
from unittest.mock import patch, MagicMock

# Add app directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))


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

    @patch('app.auth.validate_api_key')
    def test_protected_endpoint_with_valid_api_key(self, mock_validate, client):
        """Test protected endpoint succeeds with valid API key"""
        # Mock successful validation
        mock_validate.return_value = {
            'key_id': 'test-key-123',
            'permissions': ['read', 'write'],
            'rate_limit': 1000
        }

        response = client.get(
            '/dev/protected',
            headers={'X-API-Key': 'test-key-123'}
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert data['api_key_id'] == 'test-key-123'

    @patch('app.auth.validate_api_key')
    def test_admin_endpoint_without_admin_permission(self, mock_validate, client):
        """Test admin endpoint returns 403 without admin permission"""
        # Mock validation with non-admin user
        mock_validate.return_value = {
            'key_id': 'test-key-123',
            'permissions': ['read'],  # No admin permission
            'rate_limit': 1000
        }

        response = client.get(
            '/dev/admin/stats',
            headers={'X-API-Key': 'test-key-123'}
        )

        assert response.status_code == 403
        data = json.loads(response.data)
        assert 'error' in data
        assert 'Insufficient permissions' in data['error']

    @patch('app.auth.validate_api_key')
    def test_admin_endpoint_with_admin_permission(self, mock_validate, client):
        """Test admin endpoint succeeds with admin permission"""
        # Mock validation with admin user
        mock_validate.return_value = {
            'key_id': 'admin-key',
            'permissions': ['read', 'write', 'admin'],
            'rate_limit': 1000
        }

        response = client.get(
            '/dev/admin/stats',
            headers={'X-API-Key': 'admin-key'}
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

    @patch('app.auth.validate_api_key')
    @patch('app.auth.verify_hmac_signature')
    def test_signed_endpoint_with_valid_signature(self, mock_verify, mock_validate, client):
        """Test signed endpoint succeeds with valid signature"""
        # Mock successful validation and signature verification
        mock_validate.return_value = {
            'key_id': 'test-key',
            'secret': 'test-secret',
            'permissions': ['read', 'write'],
            'rate_limit': 1000
        }
        mock_verify.return_value = True

        import time
        timestamp = str(int(time.time()))

        response = client.post(
            '/dev/signed',
            json={'name': 'John Doe', 'email': 'john@example.com', 'age': 30, 'message': 'test'},
            headers={
                'X-API-Key': 'test-key',
                'X-Signature': 'valid-signature',
                'X-Timestamp': timestamp
            }
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert data['security']['signature_verified'] is True

    @patch('app.auth.validate_api_key')
    @patch('app.auth.verify_hmac_signature')
    def test_signed_endpoint_with_invalid_signature(self, mock_verify, mock_validate, client):
        """Test signed endpoint fails with invalid signature"""
        mock_validate.return_value = {
            'key_id': 'test-key',
            'secret': 'test-secret',
            'permissions': ['read', 'write'],
            'rate_limit': 1000
        }
        mock_verify.return_value = False  # Invalid signature

        import time
        timestamp = str(int(time.time()))

        response = client.post(
            '/dev/signed',
            json={'name': 'John Doe', 'email': 'john@example.com', 'age': 30, 'message': 'test'},
            headers={
                'X-API-Key': 'test-key',
                'X-Signature': 'invalid-signature',
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
