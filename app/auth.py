"""
API Key Authentication and Authorization Module

Provides:
- API key validation
- Request signature verification
- Rate limiting per API key
- Audit logging
"""

import hashlib
import hmac
import time
from functools import wraps
from flask import request, jsonify
import os
import json

# In production, these would come from AWS Secrets Manager
# For demo purposes, we'll use environment variables
API_KEYS = {
    "test-api-key-12345": {
        "name": "Test Client",
        "tier": "free",
        "rate_limit": 100,  # requests per minute
        "secret": "test-secret-key-67890"
    },
    "prod-api-key-abcde": {
        "name": "Production Client",
        "tier": "premium",
        "rate_limit": 1000,
        "secret": "prod-secret-key-xyz123"
    }
}

# Simple in-memory rate limiting (in production, use Redis/DynamoDB)
rate_limit_store = {}

def get_api_key_info(api_key):
    """Get information about an API key"""
    return API_KEYS.get(api_key)

def validate_signature(api_key, signature, timestamp, body):
    """
    Validate HMAC signature for request

    Client generates signature:
    signature = HMAC-SHA256(secret, timestamp + body)
    """
    key_info = get_api_key_info(api_key)
    if not key_info:
        return False

    secret = key_info['secret']

    # Create expected signature
    message = f"{timestamp}{body}".encode('utf-8')
    expected_sig = hmac.new(
        secret.encode('utf-8'),
        message,
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(signature, expected_sig)

def check_rate_limit(api_key):
    """
    Check if API key has exceeded rate limit

    Returns (allowed, remaining, reset_time)
    """
    key_info = get_api_key_info(api_key)
    if not key_info:
        return (False, 0, 0)

    limit = key_info['rate_limit']
    now = int(time.time())
    window_start = now - 60  # 1 minute window

    # Initialize if not exists
    if api_key not in rate_limit_store:
        rate_limit_store[api_key] = []

    # Remove old timestamps
    rate_limit_store[api_key] = [
        ts for ts in rate_limit_store[api_key]
        if ts > window_start
    ]

    current_count = len(rate_limit_store[api_key])
    remaining = max(0, limit - current_count)

    if current_count >= limit:
        reset_time = rate_limit_store[api_key][0] + 60
        return (False, 0, reset_time)

    # Add current timestamp
    rate_limit_store[api_key].append(now)

    return (True, remaining, now + 60)

def log_api_request(api_key, endpoint, status, response_time_ms):
    """Log API request for audit purposes"""
    log_entry = {
        "timestamp": time.time(),
        "api_key": api_key,
        "endpoint": endpoint,
        "status": status,
        "response_time_ms": response_time_ms,
        "ip": request.remote_addr,
        "user_agent": request.headers.get('User-Agent', '')
    }

    # In production, send to CloudWatch Logs or DynamoDB
    print(f"[API_AUDIT] {json.dumps(log_entry)}")

def require_api_key(check_signature=False):
    """
    Decorator to require API key authentication

    Usage:
        @app.route('/protected')
        @require_api_key()
        def protected_endpoint():
            # api_key_info available in request context
            pass

        @app.route('/signed')
        @require_api_key(check_signature=True)
        def signed_endpoint():
            # Both API key and signature verified
            pass
    """
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            start_time = time.time()

            # Get API key from header
            api_key = request.headers.get('X-API-Key')

            if not api_key:
                log_api_request(None, request.path, 401, 0)
                return jsonify({
                    'error': 'Missing API key',
                    'message': 'Provide X-API-Key header'
                }), 401

            # Validate API key
            key_info = get_api_key_info(api_key)
            if not key_info:
                log_api_request(api_key, request.path, 401, 0)
                return jsonify({
                    'error': 'Invalid API key',
                    'message': 'API key not recognized'
                }), 401

            # Check rate limit
            allowed, remaining, reset_time = check_rate_limit(api_key)
            if not allowed:
                response_time = (time.time() - start_time) * 1000
                log_api_request(api_key, request.path, 429, response_time)
                return jsonify({
                    'error': 'Rate limit exceeded',
                    'message': f'Try again after {reset_time}',
                    'limit': key_info['rate_limit'],
                    'reset_time': reset_time
                }), 429, {
                    'X-RateLimit-Limit': str(key_info['rate_limit']),
                    'X-RateLimit-Remaining': '0',
                    'X-RateLimit-Reset': str(reset_time),
                    'Retry-After': str(reset_time - int(time.time()))
                }

            # Verify signature if required
            if check_signature:
                signature = request.headers.get('X-Signature')
                timestamp = request.headers.get('X-Timestamp')

                if not signature or not timestamp:
                    log_api_request(api_key, request.path, 401, 0)
                    return jsonify({
                        'error': 'Missing signature',
                        'message': 'Provide X-Signature and X-Timestamp headers'
                    }), 401

                # Check timestamp freshness (prevent replay attacks)
                try:
                    req_time = int(timestamp)
                    now = int(time.time())
                    if abs(now - req_time) > 300:  # 5 minute window
                        log_api_request(api_key, request.path, 401, 0)
                        return jsonify({
                            'error': 'Request expired',
                            'message': 'Timestamp too old or in future'
                        }), 401
                except ValueError:
                    log_api_request(api_key, request.path, 400, 0)
                    return jsonify({
                        'error': 'Invalid timestamp',
                        'message': 'X-Timestamp must be Unix timestamp'
                    }), 400

                # Validate signature
                body = request.get_data(as_text=True) if request.data else ""
                if not validate_signature(api_key, signature, timestamp, body):
                    log_api_request(api_key, request.path, 401, 0)
                    return jsonify({
                        'error': 'Invalid signature',
                        'message': 'Request signature verification failed'
                    }), 401

            # Add API key info to request context
            request.api_key_info = key_info

            # Execute route function
            response = f(*args, **kwargs)

            # Add rate limit headers
            if isinstance(response, tuple):
                data, status, headers = response if len(response) == 3 else (response[0], response[1], {})
            else:
                data, status, headers = response, 200, {}

            headers['X-RateLimit-Limit'] = str(key_info['rate_limit'])
            headers['X-RateLimit-Remaining'] = str(remaining)
            headers['X-RateLimit-Reset'] = str(reset_time)

            # Log successful request
            response_time = (time.time() - start_time) * 1000
            log_api_request(api_key, request.path, status, response_time)

            return data, status, headers

        return wrapper
    return decorator

# Example usage in main.py:
"""
from auth import require_api_key

@bp.route('/protected')
@require_api_key()
def protected_endpoint():
    client_name = request.api_key_info['name']
    return jsonify({
        'message': f'Hello {client_name}!',
        'tier': request.api_key_info['tier']
    })

@bp.route('/signed', methods=['POST'])
@require_api_key(check_signature=True)
def signed_endpoint():
    # Both API key and signature verified
    return jsonify({'status': 'verified'})
"""
