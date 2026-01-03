"""
Unit tests for ShopEasy Flask Application
"""
import pytest
import sys
import os

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from app import app, products


@pytest.fixture
def client():
    """Create a test client for the Flask application"""
    app.config['TESTING'] = True
    app.config['SECRET_KEY'] = 'test-secret-key'
    with app.test_client() as client:
        yield client


@pytest.fixture
def init_session(client):
    """Initialize session for cart operations"""
    with client.session_transaction() as sess:
        sess['cart'] = []


class TestHomePage:
    """Tests for the home page"""
    
    def test_home_page_loads(self, client):
        """Test that home page loads successfully"""
        response = client.get('/')
        assert response.status_code == 200
    
    def test_home_page_contains_products(self, client):
        """Test that home page contains product names"""
        response = client.get('/')
        assert b'ShopEasy' in response.data
        assert b'Wireless Headphones' in response.data


class TestHealthCheck:
    """Tests for health check endpoint"""
    
    def test_health_endpoint(self, client):
        """Test that health endpoint returns 200"""
        response = client.get('/health')
        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'healthy'


class TestCart:
    """Tests for shopping cart functionality"""
    
    def test_get_empty_cart(self, client, init_session):
        """Test getting an empty cart"""
        response = client.get('/get_cart')
        assert response.status_code == 200
        assert response.get_json() == []
    
    def test_add_to_cart(self, client, init_session):
        """Test adding a product to cart"""
        response = client.post('/add_to_cart', 
                               json={'product_id': 1},
                               content_type='application/json')
        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] == True
        assert len(data['cart']) == 1
        assert data['cart'][0]['id'] == 1
    
    def test_add_invalid_product(self, client, init_session):
        """Test adding an invalid product to cart"""
        response = client.post('/add_to_cart', 
                               json={'product_id': 999},
                               content_type='application/json')
        data = response.get_json()
        assert data['success'] == False


class TestProducts:
    """Tests for product data"""
    
    def test_products_exist(self):
        """Test that products list is not empty"""
        assert len(products) > 0
    
    def test_product_structure(self):
        """Test that products have required fields"""
        required_fields = ['id', 'name', 'price', 'category', 'description', 'rating']
        for product in products:
            for field in required_fields:
                assert field in product


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
