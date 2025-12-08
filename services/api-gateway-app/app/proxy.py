from flask import Blueprint, jsonify, request, current_app
import requests
import pika
import json
import logging
from datetime import datetime

gateway_bp = Blueprint('gateway', __name__)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def log_request(endpoint, method, status_code):
    """Log request to file"""
    try:
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'endpoint': endpoint,
            'method': method,
            'status_code': status_code
        }
        
        log_file = current_app.config['LOG_FILE']
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')
    except Exception as e:
        logger.error(f"Error logging request: {str(e)}")

def send_to_queue(data):
    """Send message to RabbitMQ queue"""
    try:
        config = current_app.config
        
        credentials = pika.PlainCredentials(
            config['RABBITMQ_USER'],
            config['RABBITMQ_PASSWORD']
        )
        
        parameters = pika.ConnectionParameters(
            host=config['RABBITMQ_HOST'],
            port=int(config['RABBITMQ_PORT']),
            credentials=credentials
        )
        
        connection = pika.BlockingConnection(parameters)
        channel = connection.channel()
        
        # Declare queue
        channel.queue_declare(queue=config['RABBITMQ_QUEUE'], durable=True)
        
        # Publish message
        channel.basic_publish(
            exchange='',
            routing_key=config['RABBITMQ_QUEUE'],
            body=json.dumps(data),
            properties=pika.BasicProperties(
                delivery_mode=2,  # Make message persistent
            )
        )
        
        connection.close()
        logger.info(f"Message sent to queue: {data}")
        return True
        
    except Exception as e:
        logger.error(f"Error sending message to queue: {str(e)}")
        return False

# ==================== HEALTH CHECK ====================
@gateway_bp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'api-gateway'}), 200

# ==================== INVENTORY ROUTES ====================
@gateway_bp.route('/api/movies', methods=['GET'])
def get_movies():
    """Get all movies from inventory service"""
    try:
        url = f"{current_app.config['INVENTORY_SERVICE_URL']}/api/movies"
        response = requests.get(url, timeout=5)
        log_request('/api/movies', 'GET', response.status_code)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error fetching movies: {str(e)}")
        log_request('/api/movies', 'GET', 500)
        return jsonify({'error': 'Failed to fetch movies'}), 500

@gateway_bp.route('/api/movies/<int:movie_id>', methods=['GET'])
def get_movie(movie_id):
    """Get a specific movie from inventory service"""
    try:
        url = f"{current_app.config['INVENTORY_SERVICE_URL']}/api/movies/{movie_id}"
        response = requests.get(url, timeout=5)
        log_request(f'/api/movies/{movie_id}', 'GET', response.status_code)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error fetching movie {movie_id}: {str(e)}")
        log_request(f'/api/movies/{movie_id}', 'GET', 500)
        return jsonify({'error': 'Failed to fetch movie'}), 500

@gateway_bp.route('/api/movies', methods=['POST'])
def create_movie():
    """Create a new movie in inventory service"""
    try:
        url = f"{current_app.config['INVENTORY_SERVICE_URL']}/api/movies"
        response = requests.post(url, json=request.get_json(), timeout=5)
        log_request('/api/movies', 'POST', response.status_code)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error creating movie: {str(e)}")
        log_request('/api/movies', 'POST', 500)
        return jsonify({'error': 'Failed to create movie'}), 500

# ==================== BILLING ROUTES ====================
@gateway_bp.route('/api/orders', methods=['GET'])
def get_orders():
    """Get all orders from billing service"""
    try:
        url = f"{current_app.config['BILLING_SERVICE_URL']}/api/orders"
        response = requests.get(url, timeout=5)
        log_request('/api/orders', 'GET', response.status_code)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error fetching orders: {str(e)}")
        log_request('/api/orders', 'GET', 500)
        return jsonify({'error': 'Failed to fetch orders'}), 500

@gateway_bp.route('/api/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    """Get a specific order from billing service"""
    try:
        url = f"{current_app.config['BILLING_SERVICE_URL']}/api/orders/{order_id}"
        response = requests.get(url, timeout=5)
        log_request(f'/api/orders/{order_id}', 'GET', response.status_code)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error fetching order {order_id}: {str(e)}")
        log_request(f'/api/orders/{order_id}', 'GET', 500)
        return jsonify({'error': 'Failed to fetch order'}), 500

@gateway_bp.route('/api/orders/user/<int:user_id>', methods=['GET'])
def get_user_orders(user_id):
    """Get all orders for a specific user"""
    try:
        url = f"{current_app.config['BILLING_SERVICE_URL']}/api/orders/user/{user_id}"
        response = requests.get(url, timeout=5)
        log_request(f'/api/orders/user/{user_id}', 'GET', response.status_code)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error fetching user orders: {str(e)}")
        log_request(f'/api/orders/user/{user_id}', 'GET', 500)
        return jsonify({'error': 'Failed to fetch user orders'}), 500

# ==================== ORDER CREATION (with Queue) ====================
@gateway_bp.route('/api/orders', methods=['POST'])
def create_order():
    """Create a new order and send to RabbitMQ queue"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['user_id', 'movie_id', 'quantity']
        if not all(field in data for field in required_fields):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Get movie details from inventory
        movie_url = f"{current_app.config['INVENTORY_SERVICE_URL']}/api/movies/{data['movie_id']}"
        movie_response = requests.get(movie_url, timeout=5)
        
        if movie_response.status_code != 200:
            return jsonify({'error': 'Movie not found'}), 404
        
        movie = movie_response.json()
        
        # Check stock availability
        if movie['stock'] < data['quantity']:
            return jsonify({'error': 'Insufficient stock'}), 400
        
        # Reduce stock in inventory
        reduce_stock_url = f"{current_app.config['INVENTORY_SERVICE_URL']}/api/movies/{data['movie_id']}/reduce-stock"
        stock_response = requests.post(
            reduce_stock_url,
            json={'quantity': data['quantity']},
            timeout=5
        )
        
        if stock_response.status_code != 200:
            return jsonify({'error': 'Failed to reduce stock'}), 500
        
        # Prepare order data
        order_data = {
            'user_id': data['user_id'],
            'movie_id': data['movie_id'],
            'movie_title': movie['title'],
            'quantity': data['quantity'],
            'price': movie['price'],
            'total_amount': movie['price'] * data['quantity']
        }
        
        # Send to RabbitMQ queue
        if send_to_queue(order_data):
            log_request('/api/orders', 'POST', 202)
            return jsonify({
                'message': 'Order received and queued for processing',
                'order_data': order_data
            }), 202
        else:
            log_request('/api/orders', 'POST', 500)
            return jsonify({'error': 'Failed to queue order'}), 500
        
    except Exception as e:
        logger.error(f"Error creating order: {str(e)}")
        log_request('/api/orders', 'POST', 500)
        return jsonify({'error': 'Failed to create order'}), 500