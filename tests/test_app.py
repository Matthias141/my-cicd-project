import pytest
import os
from app.main import app

@pytest.fixture
def client(monkeypatch):
    """
    Creates a test version of your application
    You can make requests to it without running a real server
    """
    # Set test environment variable
    monkeypatch.setenv('ENVIRONMENT', 'test')

    # Need to reimport to pick up the new environment variable
    from importlib import reload
    import app.main as main_module
    reload(main_module)

    test_app = main_module.app
    test_app.config['TESTING'] = True
    with test_app.test_client() as client:
        yield client

def test_home(client):
    """
    Test the home endpoint returns correct data
    """
    response = client.get('/test/')
    assert response.status_code == 200

    # Check if response is JSON
    json_data = response.get_json()
    assert json_data is not None

    # Check if expected fields are present
    assert 'message' in json_data
    assert json_data['message'] == 'AWS Lambda CI/CD Pipeline'
    assert json_data['environment'] == 'test'

def test_health(client):
    """
    Test the health check endpoint
    """
    response = client.get('/test/health')
    assert response.status_code == 200

    json_data = response.get_json()
    assert json_data is not None
    assert json_data['status'] == 'healthy'
    assert json_data['environment'] == 'test'
