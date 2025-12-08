import pika
import json
import logging
from app import db, create_app
from app.models import Order

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def process_order(ch, method, properties, body):
    """Process order message from RabbitMQ queue"""
    try:
        data = json.loads(body)
        logger.info(f"Received order: {data}")
        
        # Create Flask app context
        app = create_app()
        with app.app_context():
            # Create new order
            order = Order(
                user_id=data['user_id'],
                movie_id=data['movie_id'],
                movie_title=data['movie_title'],
                quantity=data['quantity'],
                price=data['price'],
                total_amount=data['total_amount'],
                status='processing'
            )
            
            db.session.add(order)
            db.session.commit()
            
            logger.info(f"Order {order.id} created successfully")
            
            # Acknowledge message
            ch.basic_ack(delivery_tag=method.delivery_tag)
            
    except Exception as e:
        logger.error(f"Error processing order: {str(e)}")
        # Reject message and requeue
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

def start_consumer():
    """Start RabbitMQ consumer"""
    from app.config import Config
    
    # Build RabbitMQ connection URL
    credentials = pika.PlainCredentials(Config.RABBITMQ_USER, Config.RABBITMQ_PASSWORD)
    parameters = pika.ConnectionParameters(
        host=Config.RABBITMQ_HOST,
        port=int(Config.RABBITMQ_PORT),
        credentials=credentials,
        heartbeat=600,
        blocked_connection_timeout=300
    )
    
    try:
        # Connect to RabbitMQ
        connection = pika.BlockingConnection(parameters)
        channel = connection.channel()
        
        # Declare queue
        channel.queue_declare(queue=Config.RABBITMQ_QUEUE, durable=True)
        
        # Set QoS
        channel.basic_qos(prefetch_count=1)
        
        # Start consuming
        channel.basic_consume(
            queue=Config.RABBITMQ_QUEUE,
            on_message_callback=process_order
        )
        
        logger.info(f"Started consuming from queue: {Config.RABBITMQ_QUEUE}")
        channel.start_consuming()
        
    except Exception as e:
        logger.error(f"Error starting consumer: {str(e)}")
        raise