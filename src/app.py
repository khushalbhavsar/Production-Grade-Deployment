from flask import Flask, render_template_string, request, jsonify, session
import json
import os
from datetime import datetime

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-here')  # Use environment variable in production

# Sample products with free images from Picsum
products = [
    {
        "id": 1,
        "name": "Wireless Headphones",
        "price": 99.99,
        "image": "https://picsum.photos/300/200?random=1",
        "category": "Electronics",
        "description": "High-quality wireless headphones with noise cancellation",
        "rating": 4.5
    },
    {
        "id": 2,
        "name": "Smart Watch",
        "price": 199.99,
        "image": "https://picsum.photos/300/200?random=2",
        "category": "Electronics",
        "description": "Feature-rich smartwatch with health monitoring",
        "rating": 4.2
    },
    {
        "id": 3,
        "name": "Running Shoes",
        "price": 79.99,
        "image": "https://picsum.photos/300/200?random=3",
        "category": "Fashion",
        "description": "Comfortable running shoes for all terrains",
        "rating": 4.7
    },
    {
        "id": 4,
        "name": "Coffee Maker",
        "price": 49.99,
        "image": "https://picsum.photos/300/200?random=4",
        "category": "Home",
        "description": "Automatic coffee maker with timer",
        "rating": 4.3
    },
    {
        "id": 5,
        "name": "Backpack",
        "price": 39.99,
        "image": "https://picsum.photos/300/200?random=5",
        "category": "Fashion",
        "description": "Waterproof backpack with laptop compartment",
        "rating": 4.6
    },
    {
        "id": 6,
        "name": "Desk Lamp",
        "price": 29.99,
        "image": "https://picsum.photos/300/200?random=6",
        "category": "Home",
        "description": "LED desk lamp with adjustable brightness",
        "rating": 4.4
    }
]

# HTML Template for E-commerce App
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShopEasy - Online Store</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        .product-card:hover {
            transform: translateY(-5px);
            transition: all 0.3s ease;
        }
        .cart-badge {
            position: absolute;
            top: -8px;
            right: -8px;
            background: #ef4444;
            color: white;
            border-radius: 50%;
            width: 20px;
            height: 20px;
            font-size: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .search-box:focus {
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }
    </style>
</head>
<body class="bg-gray-50">
    <!-- Navigation -->
    <nav class="bg-white shadow-lg sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4">
            <div class="flex justify-between items-center py-4">
                <div class="flex items-center">
                    <i class="fas fa-shopping-bag text-blue-600 text-2xl mr-2"></i>
                    <span class="text-xl font-bold text-gray-800">ShopEasy</span>
                </div>
                
                <!-- Search Bar -->
                <div class="flex-1 max-w-2xl mx-4">
                    <div class="relative">
                        <input type="text" 
                               id="searchInput"
                               placeholder="Search products..." 
                               class="w-full px-4 py-2 rounded-lg border border-gray-300 focus:outline-none focus:border-blue-500 search-box">
                        <i class="fas fa-search absolute right-3 top-3 text-gray-400"></i>
                    </div>
                </div>

                <!-- Cart Icon -->
                <div class="relative">
                    <button onclick="toggleCart()" class="p-2 text-gray-600 hover:text-blue-600 relative">
                        <i class="fas fa-shopping-cart text-xl"></i>
                        <span id="cartCount" class="cart-badge">0</span>
                    </button>
                </div>
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <section class="bg-gradient-to-r from-blue-600 to-purple-600 text-white py-16">
        <div class="max-w-7xl mx-auto px-4 text-center">
            <h1 class="text-4xl md:text-6xl font-bold mb-4">Welcome to ShopEasy</h1>
            <p class="text-xl mb-8">Discover amazing products at great prices</p>
            <button onclick="scrollToProducts()" class="bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100 transition duration-300">
                Start Shopping
            </button>
        </div>
    </section>

    <!-- Products Section -->
    <section id="products" class="max-w-7xl mx-auto px-4 py-12">
        <h2 class="text-3xl font-bold text-gray-800 mb-8 text-center">Featured Products</h2>
        
        <!-- Category Filters -->
        <div class="flex flex-wrap justify-center gap-2 mb-8">
            <button onclick="filterProducts('all')" class="px-4 py-2 bg-blue-600 text-white rounded-lg">All</button>
            <button onclick="filterProducts('Electronics')" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">Electronics</button>
            <button onclick="filterProducts('Fashion')" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">Fashion</button>
            <button onclick="filterProducts('Home')" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">Home</button>
        </div>

        <!-- Products Grid -->
        <div id="productsGrid" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {% for product in products %}
            <div class="bg-white rounded-lg shadow-md product-card border border-gray-200" data-category="{{ product.category }}">
                <img src="{{ product.image }}" alt="{{ product.name }}" class="w-full h-48 object-cover rounded-t-lg">
                <div class="p-4">
                    <div class="flex justify-between items-start mb-2">
                        <h3 class="text-lg font-semibold text-gray-800">{{ product.name }}</h3>
                        <span class="text-green-600 font-bold">${{ product.price }}</span>
                    </div>
                    <p class="text-gray-600 text-sm mb-3">{{ product.description }}</p>
                    <div class="flex justify-between items-center">
                        <div class="flex items-center">
                            {% for i in range(5) %}
                                {% if i < product.rating|int %}
                                    <i class="fas fa-star text-yellow-400"></i>
                                {% else %}
                                    <i class="far fa-star text-yellow-400"></i>
                                {% endif %}
                            {% endfor %}
                            <span class="text-sm text-gray-500 ml-1">{{ product.rating }}</span>
                        </div>
                        <button onclick="addToCart({{ product.id }})" 
                                class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-300">
                            <i class="fas fa-cart-plus mr-2"></i>Add to Cart
                        </button>
                    </div>
                </div>
            </div>
            {% endfor %}
        </div>
    </section>

    <!-- Shopping Cart Sidebar -->
    <div id="cartSidebar" class="fixed top-0 right-0 h-full w-96 bg-white shadow-2xl transform translate-x-full transition-transform duration-300 z-50">
        <div class="p-4 border-b border-gray-200 flex justify-between items-center">
            <h3 class="text-lg font-semibold">Your Shopping Cart</h3>
            <button onclick="toggleCart()" class="text-gray-500 hover:text-gray-700">
                <i class="fas fa-times text-xl"></i>
            </button>
        </div>
        <div id="cartItems" class="p-4 h-3/4 overflow-y-auto">
            <!-- Cart items will be loaded here -->
            <div id="emptyCart" class="text-center text-gray-500 py-8">
                <i class="fas fa-shopping-cart text-4xl mb-4 text-gray-300"></i>
                <p>Your cart is empty</p>
            </div>
        </div>
        <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200 bg-white">
            <div class="flex justify-between items-center mb-4">
                <span class="font-semibold">Total:</span>
                <span id="cartTotal" class="font-bold text-lg">$0.00</span>
            </div>
            <button onclick="checkout()" class="w-full bg-green-600 text-white py-3 rounded-lg font-semibold hover:bg-green-700 transition duration-300">
                <i class="fas fa-credit-card mr-2"></i>Checkout
            </button>
        </div>
    </div>

    <!-- Cart Overlay -->
    <div id="cartOverlay" class="fixed inset-0 bg-black bg-opacity-50 hidden z-40" onclick="toggleCart()"></div>

    <!-- Footer -->
    <footer class="bg-gray-800 text-white py-8 mt-12">
        <div class="max-w-7xl mx-auto px-4 text-center">
            <p>&copy; 2024 ShopEasy. All rights reserved. | Built with ❤️ using Flask</p>
            <div class="mt-4 space-x-4">
                <a href="#" class="text-gray-400 hover:text-white"><i class="fab fa-facebook"></i></a>
                <a href="#" class="text-gray-400 hover:text-white"><i class="fab fa-twitter"></i></a>
                <a href="#" class="text-gray-400 hover:text-white"><i class="fab fa-instagram"></i></a>
            </div>
        </div>
    </footer>

    <script>
        let cart = [];
        
        // Load cart from session
        function loadCart() {
            fetch('/get_cart')
                .then(response => response.json())
                .then(data => {
                    cart = data;
                    updateCartUI();
                });
        }

        // Add to cart
        function addToCart(productId) {
            fetch('/add_to_cart', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({product_id: productId})
            })
            .then(response => response.json())
            .then(data => {
                cart = data.cart;
                updateCartUI();
                
                // Show success message
                showNotification('Product added to cart!', 'success');
            });
        }

        // Remove from cart
        function removeFromCart(productId) {
            fetch('/remove_from_cart', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({product_id: productId})
            })
            .then(response => response.json())
            .then(data => {
                cart = data.cart;
                updateCartUI();
            });
        }

        // Update cart UI
        function updateCartUI() {
            const cartCount = document.getElementById('cartCount');
            const cartItems = document.getElementById('cartItems');
            const cartTotal = document.getElementById('cartTotal');
            const emptyCart = document.getElementById('emptyCart');

            // Update cart count
            cartCount.textContent = cart.reduce((total, item) => total + item.quantity, 0);

            // Update cart items
            if (cart.length === 0) {
                emptyCart.style.display = 'block';
                cartItems.innerHTML = '<div id="emptyCart" class="text-center text-gray-500 py-8"><i class="fas fa-shopping-cart text-4xl mb-4 text-gray-300"></i><p>Your cart is empty</p></div>';
            } else {
                emptyCart.style.display = 'none';
                let total = 0;
                cartItems.innerHTML = cart.map(item => {
                    total += item.price * item.quantity;
                    return `
                        <div class="flex items-center border-b border-gray-200 py-4">
                            <img src="${item.image}" alt="${item.name}" class="w-16 h-16 object-cover rounded">
                            <div class="flex-1 ml-4">
                                <h4 class="font-semibold">${item.name}</h4>
                                <p class="text-green-600 font-bold">$${item.price}</p>
                                <div class="flex items-center mt-2">
                                    <button onclick="updateQuantity(${item.id}, ${item.quantity - 1})" class="px-2 py-1 bg-gray-200 rounded-l">-</button>
                                    <span class="px-3 py-1 bg-gray-100">${item.quantity}</span>
                                    <button onclick="updateQuantity(${item.id}, ${item.quantity + 1})" class="px-2 py-1 bg-gray-200 rounded-r">+</button>
                                    <button onclick="removeFromCart(${item.id})" class="ml-4 text-red-500 hover:text-red-700">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    `;
                }).join('');
                cartTotal.textContent = `$${total.toFixed(2)}`;
            }
        }

        // Update quantity
        function updateQuantity(productId, newQuantity) {
            if (newQuantity < 1) {
                removeFromCart(productId);
                return;
            }
            
            fetch('/update_quantity', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({product_id: productId, quantity: newQuantity})
            })
            .then(response => response.json())
            .then(data => {
                cart = data.cart;
                updateCartUI();
            });
        }

        // Toggle cart sidebar
        function toggleCart() {
            const sidebar = document.getElementById('cartSidebar');
            const overlay = document.getElementById('cartOverlay');
            sidebar.classList.toggle('translate-x-full');
            overlay.classList.toggle('hidden');
        }

        // Filter products
        function filterProducts(category) {
            const products = document.querySelectorAll('.product-card');
            products.forEach(product => {
                if (category === 'all' || product.dataset.category === category) {
                    product.style.display = 'block';
                } else {
                    product.style.display = 'none';
                }
            });
        }

        // Search functionality
        document.getElementById('searchInput').addEventListener('input', function(e) {
            const searchTerm = e.target.value.toLowerCase();
            const products = document.querySelectorAll('.product-card');
            
            products.forEach(product => {
                const name = product.querySelector('h3').textContent.toLowerCase();
                const description = product.querySelector('p').textContent.toLowerCase();
                
                if (name.includes(searchTerm) || description.includes(searchTerm)) {
                    product.style.display = 'block';
                } else {
                    product.style.display = 'none';
                }
            });
        });

        // Scroll to products
        function scrollToProducts() {
            document.getElementById('products').scrollIntoView({ behavior: 'smooth' });
        }

        // Show notification
        function showNotification(message, type) {
            const notification = document.createElement('div');
            notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 ${
                type === 'success' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'
            }`;
            notification.textContent = message;
            document.body.appendChild(notification);
            
            setTimeout(() => {
                notification.remove();
            }, 3000);
        }

        // Checkout
        function checkout() {
            if (cart.length === 0) {
                showNotification('Your cart is empty!', 'error');
                return;
            }
            
            fetch('/checkout', {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showNotification('Order placed successfully!', 'success');
                    cart = [];
                    updateCartUI();
                    toggleCart();
                }
            });
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            loadCart();
        });
    </script>
</body>
</html>
"""

@app.route("/")
def home():
    return render_template_string(HTML_TEMPLATE, products=products)

@app.route("/health")
def health():
    """Health check endpoint for Kubernetes probes"""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})

@app.route("/add_to_cart", methods=["POST"])
def add_to_cart():
    if 'cart' not in session:
        session['cart'] = []
    
    data = request.get_json()
    product_id = data.get('product_id')
    
    # Find the product
    product = next((p for p in products if p['id'] == product_id), None)
    
    if product:
        # Check if product already in cart
        cart = session['cart']
        cart_item = next((item for item in cart if item['id'] == product_id), None)
        
        if cart_item:
            cart_item['quantity'] += 1
        else:
            cart.append({
                'id': product['id'],
                'name': product['name'],
                'price': product['price'],
                'image': product['image'],
                'quantity': 1
            })
        
        session['cart'] = cart
        return jsonify({'success': True, 'cart': cart})
    
    return jsonify({'success': False})

@app.route("/remove_from_cart", methods=["POST"])
def remove_from_cart():
    data = request.get_json()
    product_id = data.get('product_id')
    
    if 'cart' in session:
        cart = session['cart']
        session['cart'] = [item for item in cart if item['id'] != product_id]
        return jsonify({'success': True, 'cart': session['cart']})
    
    return jsonify({'success': False})

@app.route("/update_quantity", methods=["POST"])
def update_quantity():
    data = request.get_json()
    product_id = data.get('product_id')
    quantity = data.get('quantity')
    
    if 'cart' in session:
        cart = session['cart']
        cart_item = next((item for item in cart if item['id'] == product_id), None)
        
        if cart_item:
            if quantity <= 0:
                session['cart'] = [item for item in cart if item['id'] != product_id]
            else:
                cart_item['quantity'] = quantity
            
            return jsonify({'success': True, 'cart': session['cart']})
    
    return jsonify({'success': False})

@app.route("/get_cart")
def get_cart():
    return jsonify(session.get('cart', []))

@app.route("/checkout", methods=["POST"])
def checkout():
    if 'cart' in session:
        # In a real app, you'd process payment and save order
        session['cart'] = []
        return jsonify({'success': True, 'message': 'Order placed successfully!'})
    
    return jsonify({'success': False, 'message': 'Cart is empty!'})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
