import unittest
import json
import os
import sys

# Add the parent directory to the path so we can import app.py
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from main import app

class TestAPIGateway(unittest.TestCase):
    def setUp(self):
        # Set the environment variable just like AWS does
        os.environ['ENVIRONMENT'] = 'yes'
        self.app = app.test_client()
        self.app.testing = True

    def test_health_check(self):
        """Test if /health returns 200 OK"""
        # Note: We must include the /yes prefix because of the Blueprint logic
        response = self.app.get('/yes/health')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(data['status'], 'healthy')
        print("✅ Health Check Passed")

    def test_home_redirect(self):
        """Test if /yes redirects to /yes/ (Flask strict slashes)"""
        response = self.app.get('/yes')
        # 308 is the permanent redirect status for missing slashes
        self.assertEqual(response.status_code, 308) 
        print("✅ Redirect Logic Passed")

    def test_home_page(self):
        """Test if /yes/ returns the main JSON"""
        response = self.app.get('/yes/')
        self.assertEqual(response.status_code, 200)
        print("✅ Home Page Passed")

if __name__ == '__main__':
    unittest.main()