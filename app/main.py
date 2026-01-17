from flask import Flask, jsonify, Blueprint
import os
import json
import base64

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
        'endpoints': {
            'home': f'/{env_name}/',
            'health': f'/{env_name}/health'
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