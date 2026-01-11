# Create the correct test file

import pytest
from app.main import app

@pytest.fixture
def client():
    """
    Creates a test version of your application
    You can make requests to it without running a real server
    """
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_home(client):
    """
    Test the home endpoint returns correct data
    """
    response = client.get('/')
    assert response.status_code == 200
    
    # Check if response is JSON
    json_data = response.get_json()
    assert json_data is not None
    
    # Check if expected fields are present
    assert 'message' in json_data
    assert json_data['message'] == 'AWS Lambda CI/CD Pipeline'

def test_health(client):
    """
    Test the health check endpoint
    """
    response = client.get('/health')
    assert response.status_code == 200
    
    json_data = response.get_json()
    assert json_data is not None
    assert json_data['status'] == 'healthy'

def test_metrics(client):
    """
    Test the metrics endpoint
    """
    response = client.get('/metrics')
    assert response.status_code == 200
    
    json_data = response.get_json()
    assert json_data is not None
    assert 'function_name' in json_data
