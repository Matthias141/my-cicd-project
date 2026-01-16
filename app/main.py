from flask import Flask, jsonify, Blueprint
import os
from mangum import Mangum  # Adapter for AWS Lambda

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
# This wraps the Flask app so Lambda can speak to it
handler = Mangum(app)