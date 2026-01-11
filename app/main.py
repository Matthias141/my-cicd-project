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

# 1. Get the environment name (e.g., "dev", "yes", "staging")
env_name = os.getenv('ENVIRONMENT')

# 2. Register the routes with the prefix
if env_name:
    # This makes the routes available at /dev/, /staging/, etc.
    app.register_blueprint(bp, url_prefix=f"/{env_name}")
else:
    # Fallback for local testing (no prefix)
    app.register_blueprint(bp, url_prefix='/')

# 3. Add a root route just in case (catches / if no prefix matches)
@app.route('/')
def root():
    return jsonify({
        'message': 'You hit the root path. Try adding the environment name.',
        'hint': f'Go to /{env_name}/' if env_name else 'Local mode'
    })

if __name__ == '__main__':
    # Only runs when testing locally on your machine
    app.run(host='0.0.0.0', port=5000, debug=True)

# ENTRY POINT FOR AWS LAMBDA
# This wraps the Flask app so Lambda can speak to it
handler = Mangum(app)