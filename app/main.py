from flask import Flask, jsonify, Blueprint, request, make_response
import os
import json
import base64
from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional
from functools import wraps
from auth import require_api_key  # API key authentication

app = Flask(__name__)

# ==============================================================================
# SECURITY HEADERS MIDDLEWARE
# ==============================================================================

@app.after_request
def add_security_headers(response):
    """Add security headers to all responses"""
    # Prevent clickjacking attacks
    response.headers['X-Frame-Options'] = 'DENY'

    # Prevent MIME type sniffing
    response.headers['X-Content-Type-Options'] = 'nosniff'

    # Enable XSS protection
    response.headers['X-XSS-Protection'] = '1; mode=block'

    # Content Security Policy
    response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"

    # Prevent sensitive data caching
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'

    # Referrer Policy
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'

    # Permissions Policy (formerly Feature-Policy)
    response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'

    return response

# ==============================================================================
# PYDANTIC MODELS FOR INPUT VALIDATION
# ==============================================================================

class UserInput(BaseModel):
    """Example Pydantic model for user input validation"""
    name: str = Field(..., min_length=1, max_length=100, description="User name")
    email: EmailStr = Field(..., description="Valid email address")
    age: Optional[int] = Field(None, ge=0, le=150, description="User age")
    message: Optional[str] = Field(None, max_length=500, description="User message")

    @validator('name')
    def name_must_not_contain_special_chars(cls, v):
        """Prevent injection attacks in name field"""
        if any(char in v for char in ['<', '>', '&', '"', "'"]):
            raise ValueError('Name contains invalid characters')
        return v.strip()

    @validator('message')
    def message_sanitize(cls, v):
        """Sanitize message field"""
        if v and any(char in v for char in ['<script', '<iframe', 'javascript:']):
            raise ValueError('Message contains potentially dangerous content')
        return v

class QueryParams(BaseModel):
    """Example model for query parameter validation"""
    page: int = Field(1, ge=1, le=1000, description="Page number")
    limit: int = Field(10, ge=1, le=100, description="Items per page")
    search: Optional[str] = Field(None, max_length=200, description="Search query")

# ==============================================================================
# VALIDATION DECORATOR
# ==============================================================================

def validate_json(model: BaseModel):
    """Decorator to validate JSON input against Pydantic model"""
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            try:
                # Get JSON data from request
                data = request.get_json(force=True)

                # Validate with Pydantic
                validated_data = model(**data)

                # Add validated data to kwargs
                kwargs['validated_data'] = validated_data

                return f(*args, **kwargs)

            except ValueError as e:
                return jsonify({
                    'error': 'Validation failed',
                    'details': str(e),
                    'status': 'error'
                }), 400
            except Exception as e:
                return jsonify({
                    'error': 'Invalid JSON',
                    'details': 'Request body must be valid JSON',
                    'status': 'error'
                }), 400

        return wrapper
    return decorator

# ==============================================================================
# APPLICATION ROUTES
# ==============================================================================

app = Flask(__name__)

# Create a Blueprint (a group of routes)
bp = Blueprint('api', __name__)

@bp.route('/')
def home():
    """Matches /<env>/ (with trailing slash)"""
    return jsonify({
        'message': 'AWS Lambda CI/CD Pipeline',
        'status': 'Deployment Successful',
        'environment': os.getenv('ENVIRONMENT', 'unknown'),
        'version': os.getenv('APP_VERSION', 'dev')
    })

@bp.route('/health')
def health():
    """Matches /<env>/health"""
    return jsonify({
        'status': 'healthy',
        'environment': os.getenv('ENVIRONMENT', 'unknown')
    }), 200

@bp.route('/validate', methods=['POST'])
@validate_json(UserInput)
def validate_input(validated_data: UserInput):
    """
    Example endpoint demonstrating Pydantic input validation

    POST /<env>/validate
    {
        "name": "John Doe",
        "email": "john@example.com",
        "age": 30,
        "message": "Hello world"
    }
    """
    return jsonify({
        'status': 'success',
        'message': 'Input validated successfully',
        'data': {
            'name': validated_data.name,
            'email': validated_data.email,
            'age': validated_data.age,
            'message': validated_data.message
        }
    }), 200

@bp.route('/items', methods=['GET'])
def get_items():
    """
    Example endpoint with query parameter validation

    GET /<env>/items?page=1&limit=10&search=test
    """
    try:
        # Get query parameters
        params = QueryParams(
            page=request.args.get('page', 1),
            limit=request.args.get('limit', 10),
            search=request.args.get('search')
        )

        # Simulate data response
        return jsonify({
            'status': 'success',
            'pagination': {
                'page': params.page,
                'limit': params.limit,
                'search': params.search
            },
            'items': [
                {'id': 1, 'name': 'Item 1'},
                {'id': 2, 'name': 'Item 2'}
            ]
        }), 200

    except ValueError as e:
        return jsonify({
            'error': 'Invalid query parameters',
            'details': str(e)
        }), 400

@bp.route('/protected', methods=['GET'])
@require_api_key()
def protected_endpoint():
    """
    Example protected endpoint requiring API key authentication

    Headers required:
    - X-API-Key: your-api-key-here

    GET /<env>/protected
    """
    # Access API key info added by the decorator
    api_key_info = request.api_key_info

    return jsonify({
        'status': 'success',
        'message': 'Access granted to protected resource',
        'api_key_id': api_key_info['key_id'],
        'permissions': api_key_info['permissions'],
        'rate_limit_remaining': api_key_info.get('rate_limit_remaining', 'N/A')
    }), 200

@bp.route('/signed', methods=['POST'])
@require_api_key(check_signature=True)
@validate_json(UserInput)
def signed_endpoint(validated_data: UserInput):
    """
    Example endpoint requiring both API key and HMAC signature

    Headers required:
    - X-API-Key: your-api-key-here
    - X-Signature: HMAC-SHA256 signature of request body
    - X-Timestamp: Unix timestamp (must be within 5 minutes)

    POST /<env>/signed
    {
        "name": "John Doe",
        "email": "john@example.com",
        "age": 30,
        "message": "Signed request"
    }
    """
    api_key_info = request.api_key_info

    return jsonify({
        'status': 'success',
        'message': 'Signed request verified successfully',
        'api_key_id': api_key_info['key_id'],
        'data': {
            'name': validated_data.name,
            'email': validated_data.email,
            'age': validated_data.age,
            'message': validated_data.message
        },
        'security': {
            'signature_verified': True,
            'timestamp_valid': True
        }
    }), 200

@bp.route('/admin/stats', methods=['GET'])
@require_api_key()
def admin_stats():
    """
    Example admin endpoint with permission checking

    Headers required:
    - X-API-Key: your-api-key-here (must have 'admin' permission)

    GET /<env>/admin/stats
    """
    api_key_info = request.api_key_info

    # Check for admin permission
    if 'admin' not in api_key_info.get('permissions', []):
        return jsonify({
            'error': 'Insufficient permissions',
            'required': ['admin'],
            'current': api_key_info.get('permissions', [])
        }), 403

    # Return admin statistics
    return jsonify({
        'status': 'success',
        'stats': {
            'total_requests': 12345,
            'error_rate': 0.02,
            'avg_response_time_ms': 145,
            'active_api_keys': 5
        },
        'environment': os.getenv('ENVIRONMENT', 'unknown')
    }), 200

# 1. Get the environment name (e.g., "dev", "staging", "prod")
# Default to 'dev' for local development if not specified
env_name = os.getenv('ENVIRONMENT', 'dev')

# Log the environment for debugging
print(f"Application starting with ENVIRONMENT={env_name}")

# 2. Register the routes with the environment prefix
# This makes the routes available at /{env_name}/ (e.g., /dev/, /staging/, /prod/)
app.register_blueprint(bp, url_prefix=f"/{env_name}")

# 3. Root route returns API information and available paths
@app.route('/')
def root():
    return jsonify({
        'message': 'API Gateway for AWS Lambda CI/CD Pipeline',
        'environment': env_name,
        'version': os.getenv('APP_VERSION', 'dev'),
        'endpoints': {
            'home': f'/{env_name}/',
            'health': f'/{env_name}/health',
            'validate': f'/{env_name}/validate (POST)',
            'items': f'/{env_name}/items?page=1&limit=10',
            'protected': f'/{env_name}/protected (requires X-API-Key)',
            'signed': f'/{env_name}/signed (requires X-API-Key + X-Signature)',
            'admin_stats': f'/{env_name}/admin/stats (requires admin permission)'
        },
        'security': {
            'authentication': 'API Key (X-API-Key header)',
            'signature': 'HMAC-SHA256 for sensitive operations',
            'rate_limiting': 'Per API key',
            'waf': 'AWS WAF enabled'
        },
        'hint': f'Try accessing /{env_name}/ for the main API endpoint'
    })

if __name__ == '__main__':
    # Only runs when testing locally on your machine
    app.run(host='0.0.0.0', port=5000, debug=True)

# ENTRY POINT FOR AWS LAMBDA
# Custom WSGI adapter for Flask on Lambda
def handler(event, context):
    # Extract request details from Lambda event (API Gateway format)
    http_method = event.get('requestContext', {}).get('http', {}).get('method', 'GET')
    path = event.get('rawPath', '/')
    headers = event.get('headers', {})
    query_string = event.get('rawQueryString', '')
    body = event.get('body', '')
    is_base64 = event.get('isBase64Encoded', False)

    # Decode body if base64 encoded
    if is_base64 and body:
        body = base64.b64decode(body).decode('utf-8')

    # Create WSGI environ
    environ = {
        'REQUEST_METHOD': http_method,
        'SCRIPT_NAME': '',
        'PATH_INFO': path,
        'QUERY_STRING': query_string,
        'CONTENT_TYPE': headers.get('content-type', ''),
        'CONTENT_LENGTH': str(len(body)) if body else '0',
        'SERVER_NAME': headers.get('host', 'lambda'),
        'SERVER_PORT': '443',
        'SERVER_PROTOCOL': 'HTTP/1.1',
        'wsgi.version': (1, 0),
        'wsgi.url_scheme': 'https',
        'wsgi.input': body,
        'wsgi.errors': '',
        'wsgi.multithread': False,
        'wsgi.multiprocess': False,
        'wsgi.run_once': False,
    }

    # Add HTTP headers to environ
    for key, value in headers.items():
        key = 'HTTP_' + key.upper().replace('-', '_')
        environ[key] = value

    # Call Flask app with test client
    with app.test_client() as client:
        response = client.open(
            path=path,
            method=http_method,
            headers=headers,
            query_string=query_string,
            data=body
        )

        # Convert Flask response to Lambda response format
        return {
            'statusCode': response.status_code,
            'headers': dict(response.headers),
            'body': response.get_data(as_text=True),
            'isBase64Encoded': False
        }