"""
Tests for API key authentication and HMAC signature verification
"""
import pytest
import json
import time
import hmac
import hashlib
from unittest.mock import patch, MagicMock
import sys
import os

# Add app directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))

from auth import require_api_key, validate_api_key, verify_hmac_signature


class TestAPIKeyValidation:
    """Test API key validation functionality"""

    @patch('auth.boto3.client')
    def test_validate_api_key_success(self, mock_boto):
        """Test successful API key validation"""
        # Mock Secrets Manager response
        mock_secrets = MagicMock()
        mock_secrets.get_secret_value.return_value = {
            'SecretString': json.dumps({
                'api_keys': {
                    'test-key-123': {
                        'key_id': 'test-key-123',
                        'secret': 'test-secret',
                        'permissions': ['read', 'write'],
                        'rate_limit': 1000
                    }
                }
            })
        }
        mock_boto.return_value = mock_secrets

        result = validate_api_key('test-key-123')

        assert result is not None
        assert result['key_id'] == 'test-key-123'
        assert 'read' in result['permissions']
        assert 'write' in result['permissions']

    @patch('auth.boto3.client')
    def test_validate_api_key_invalid(self, mock_boto):
        """Test API key validation with invalid key"""
        mock_secrets = MagicMock()
        mock_secrets.get_secret_value.return_value = {
            'SecretString': json.dumps({'api_keys': {}})
        }
        mock_boto.return_value = mock_secrets

        result = validate_api_key('invalid-key')

        assert result is None

    @patch('auth.boto3.client')
    def test_validate_api_key_secrets_manager_error(self, mock_boto):
        """Test API key validation when Secrets Manager fails"""
        mock_secrets = MagicMock()
        mock_secrets.get_secret_value.side_effect = Exception("Secrets Manager error")
        mock_boto.return_value = mock_secrets

        result = validate_api_key('test-key')

        assert result is None


class TestHMACSignature:
    """Test HMAC signature verification"""

    def test_verify_hmac_signature_success(self):
        """Test successful HMAC signature verification"""
        secret = 'test-secret'
        timestamp = str(int(time.time()))
        body = '{"test": "data"}'

        # Create valid signature
        message = f"{timestamp}{body}"
        signature = hmac.new(
            secret.encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()

        result = verify_hmac_signature(signature, timestamp, body, secret)

        assert result is True

    def test_verify_hmac_signature_invalid_signature(self):
        """Test HMAC verification with invalid signature"""
        secret = 'test-secret'
        timestamp = str(int(time.time()))
        body = '{"test": "data"}'

        result = verify_hmac_signature('invalid-signature', timestamp, body, secret)

        assert result is False

    def test_verify_hmac_signature_expired_timestamp(self):
        """Test HMAC verification with expired timestamp"""
        secret = 'test-secret'
        # Timestamp from 10 minutes ago (should be rejected, max is 5 min)
        timestamp = str(int(time.time()) - 600)
        body = '{"test": "data"}'

        message = f"{timestamp}{body}"
        signature = hmac.new(
            secret.encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()

        result = verify_hmac_signature(signature, timestamp, body, secret)

        assert result is False

    def test_verify_hmac_signature_future_timestamp(self):
        """Test HMAC verification with future timestamp"""
        secret = 'test-secret'
        # Timestamp from future (should be rejected)
        timestamp = str(int(time.time()) + 600)
        body = '{"test": "data"}'

        message = f"{timestamp}{body}"
        signature = hmac.new(
            secret.encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()

        result = verify_hmac_signature(signature, timestamp, body, secret)

        assert result is False


class TestRequireAPIKeyDecorator:
    """Test the require_api_key decorator"""

    def test_decorator_without_api_key(self):
        """Test endpoint protection when API key is missing"""
        from flask import Flask

        app = Flask(__name__)

        @app.route('/protected')
        @require_api_key()
        def protected_endpoint():
            return {'status': 'success'}

        with app.test_client() as client:
            response = client.get('/protected')

            assert response.status_code == 401
            data = json.loads(response.data)
            assert 'error' in data
            assert 'API key required' in data['error']

    @patch('auth.validate_api_key')
    def test_decorator_with_valid_api_key(self, mock_validate):
        """Test endpoint protection with valid API key"""
        from flask import Flask

        # Mock successful validation
        mock_validate.return_value = {
            'key_id': 'test-key',
            'permissions': ['read'],
            'rate_limit': 1000
        }

        app = Flask(__name__)

        @app.route('/protected')
        @require_api_key()
        def protected_endpoint():
            return {'status': 'success'}

        with app.test_client() as client:
            response = client.get('/protected', headers={'X-API-Key': 'test-key'})

            assert response.status_code == 200
            data = json.loads(response.data)
            assert data['status'] == 'success'

    @patch('auth.validate_api_key')
    def test_decorator_with_invalid_api_key(self, mock_validate):
        """Test endpoint protection with invalid API key"""
        from flask import Flask

        # Mock failed validation
        mock_validate.return_value = None

        app = Flask(__name__)

        @app.route('/protected')
        @require_api_key()
        def protected_endpoint():
            return {'status': 'success'}

        with app.test_client() as client:
            response = client.get('/protected', headers={'X-API-Key': 'invalid-key'})

            assert response.status_code == 401


class TestRateLimiting:
    """Test rate limiting functionality"""

    @patch('auth.validate_api_key')
    @patch('auth.check_rate_limit')
    def test_rate_limit_not_exceeded(self, mock_rate_limit, mock_validate):
        """Test request succeeds when rate limit not exceeded"""
        from flask import Flask

        mock_validate.return_value = {
            'key_id': 'test-key',
            'permissions': ['read'],
            'rate_limit': 1000
        }
        mock_rate_limit.return_value = True  # Within limit

        app = Flask(__name__)

        @app.route('/protected')
        @require_api_key()
        def protected_endpoint():
            return {'status': 'success'}

        with app.test_client() as client:
            response = client.get('/protected', headers={'X-API-Key': 'test-key'})

            assert response.status_code == 200

    @patch('auth.validate_api_key')
    @patch('auth.check_rate_limit')
    def test_rate_limit_exceeded(self, mock_rate_limit, mock_validate):
        """Test request fails when rate limit exceeded"""
        from flask import Flask

        mock_validate.return_value = {
            'key_id': 'test-key',
            'permissions': ['read'],
            'rate_limit': 1000
        }
        mock_rate_limit.return_value = False  # Limit exceeded

        app = Flask(__name__)

        @app.route('/protected')
        @require_api_key()
        def protected_endpoint():
            return {'status': 'success'}

        with app.test_client() as client:
            response = client.get('/protected', headers={'X-API-Key': 'test-key'})

            assert response.status_code == 429  # Too Many Requests
