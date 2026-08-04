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

from auth import require_api_key, get_api_key_info, validate_signature, check_rate_limit
from fixtures import TEST_API_KEY, TEST_API_SECRET, TEST_API_KEY_INFO


class TestAPIKeyValidation:
    """Test API key validation functionality"""

    def test_get_api_key_info_success(self, patched_api_keys):
        """Test successful API key retrieval"""
        result = get_api_key_info(TEST_API_KEY)

        assert result is not None
        assert result['name'] == TEST_API_KEY_INFO['name']
        assert result['tier'] == TEST_API_KEY_INFO['tier']
        assert result['rate_limit'] == TEST_API_KEY_INFO['rate_limit']

    def test_get_api_key_info_invalid(self, patched_api_keys):
        """Test API key retrieval with invalid key"""
        # patched_api_keys makes TEST_API_KEY (only) valid, so 'invalid-key'
        # genuinely exercises "unknown key" rather than "no keys configured
        # at all."
        result = get_api_key_info('invalid-key')

        assert result is None


class TestSignatureValidation:
    """Test HMAC signature verification"""

    def test_validate_signature_success(self, patched_api_keys):
        """Test successful HMAC signature verification"""
        api_key = TEST_API_KEY
        timestamp = str(int(time.time()))
        body = '{"test": "data"}'
        secret = TEST_API_SECRET

        # Create valid signature
        message = f"{timestamp}{body}".encode('utf-8')
        signature = hmac.new(
            secret.encode('utf-8'),
            message,
            hashlib.sha256
        ).hexdigest()

        result = validate_signature(api_key, signature, timestamp, body)

        assert result is True

    def test_validate_signature_invalid_signature(self, patched_api_keys):
        """Test signature validation with invalid signature"""
        # patched_api_keys makes TEST_API_KEY valid, so this genuinely
        # exercises "valid key, wrong signature" rather than coincidentally
        # passing because the key itself doesn't exist.
        api_key = TEST_API_KEY
        timestamp = str(int(time.time()))
        body = '{"test": "data"}'

        result = validate_signature(api_key, 'invalid-signature', timestamp, body)

        assert result is False

    def test_validate_signature_invalid_api_key(self, patched_api_keys):
        """Test signature validation with invalid API key"""
        # patched_api_keys makes TEST_API_KEY (only) valid, so 'invalid-key'
        # genuinely exercises "unknown key" rather than "no keys configured
        # at all."
        timestamp = str(int(time.time()))
        body = '{"test": "data"}'

        result = validate_signature('invalid-key', 'some-signature', timestamp, body)

        assert result is False


class TestRateLimiting:
    """Test rate limiting functionality"""

    def test_check_rate_limit_within_limit(self, patched_api_keys):
        """Test rate limit check when within limit"""
        api_key = TEST_API_KEY

        # Clear any existing rate limit data
        from auth import rate_limit_store
        rate_limit_store.clear()

        allowed, remaining, reset_time = check_rate_limit(api_key)

        assert allowed is True
        assert remaining > 0
        assert reset_time > int(time.time())

    def test_check_rate_limit_invalid_key(self, patched_api_keys):
        """Test rate limit check with invalid API key"""
        # patched_api_keys makes TEST_API_KEY (only) valid, so 'invalid-key'
        # genuinely exercises "unknown key" rather than "no keys configured
        # at all."
        allowed, remaining, reset_time = check_rate_limit('invalid-key')

        assert allowed is False
        assert remaining == 0
        assert reset_time == 0

    def test_check_rate_limit_exceeded(self, patched_api_keys):
        """Test rate limit check when limit is exceeded"""
        api_key = TEST_API_KEY

        # Clear any existing rate limit data
        from auth import rate_limit_store
        rate_limit_store.clear()

        # Make requests up to the limit (100 for the fixture's rate_limit)
        for _ in range(TEST_API_KEY_INFO['rate_limit']):
            check_rate_limit(api_key)

        # Next request should be rate limited
        allowed, remaining, reset_time = check_rate_limit(api_key)

        assert allowed is False
        assert remaining == 0
