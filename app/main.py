"""
Flask Application - Your Web Service

This is the actual application logic. Lambda will call this through lambda_handler.py
"""

from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route('/')
def home():
    """Home page - returns info about the deployment"""
    return jsonify({
        'message': 'AWS Lambda CI/CD Pipeline',
        'environment': os.getenv('ENVIRONMENT', 'unknown'),
        'version': os.getenv('APP_VERSION', 'dev'),
        'region': os.getenv('AWS_REGION', 'unknown'),
        'function_name': os.getenv('AWS_LAMBDA_FUNCTION_NAME', 'local')
    })

@app.route('/health')
def health():
    """
    Health check endpoint
    API Gateway uses this to verify Lambda is working
    """
    return jsonify({
        'status': 'healthy',
        'environment': os.getenv('ENVIRONMENT', 'unknown')
    }), 200

@app.route('/metrics')
def metrics():
    """
    Metrics endpoint for monitoring systems
    In a real app, this would return actual performance metrics
    """
    return jsonify({
        'function_name': os.getenv('AWS_LAMBDA_FUNCTION_NAME', 'local'),
        'environment': os.getenv('ENVIRONMENT', 'unknown'),
        'requests_handled': 'tracked_by_cloudwatch'
    })

# This block only runs when testing locally (not in Lambda)
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

---

## File: `app/requirements.txt` (Updated)
```
Flask==3.0.0
awslambdaric==2.0.10