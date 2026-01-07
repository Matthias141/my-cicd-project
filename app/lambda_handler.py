"""
Lambda Handler - The Bridge Between AWS Lambda and Your Flask App

What's happening here:
1. AWS Lambda sends events (HTTP requests) to this handler
2. We convert Lambda events → Flask requests
3. Flask processes the request
4. We convert Flask response → Lambda response format
"""

import json
from main import app

def lambda_handler(event, context):
    """
    This is what AWS Lambda calls when a request comes in.
    
    Parameters:
    - event: Dictionary containing the HTTP request data from API Gateway
    - context: AWS Lambda runtime information (request ID, memory, etc.)
    
    Returns:
    - Dictionary with statusCode, headers, and body (what API Gateway expects)
    """
    
    # Check if this is a warm-up ping from EventBridge
    if event.get('warmup'):
        print("Warmup ping received - keeping Lambda warm")
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Lambda warmed up'})
        }
    
    # Extract HTTP method (GET, POST, etc.) from the event
    http_method = event.get('requestContext', {}).get('http', {}).get('method', 'GET')
    
    # Extract the path (e.g., "/", "/health", "/metrics")
    path = event.get('rawPath', '/')
    
    # Extract query parameters (e.g., "?name=John&age=25")
    query_params = event.get('rawQueryString', '')
    
    # Extract request body (for POST/PUT requests)
    body = event.get('body', '')
    
    # Extract headers
    headers = event.get('headers', {})
    
    print(f"Lambda received: {http_method} {path}")
    
    # Create a test request context for Flask
    with app.test_request_context(
        path=path,
        method=http_method,
        query_string=query_params,
        data=body,
        headers=headers
    ):
        try:
            # Let Flask handle the request
            response = app.full_dispatch_request()
            
            # Convert Flask response to Lambda/API Gateway format
            return {
                'statusCode': response.status_code,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',  # CORS for frontend
                },
                'body': response.get_data(as_text=True)
            }
        
        except Exception as e:
            # If something goes wrong, return error response
            print(f"Error processing request: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Internal server error',
                    'message': str(e)
                })
            }