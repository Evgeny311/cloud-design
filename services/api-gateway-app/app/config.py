import os

class Config:
    # Service URLs
    INVENTORY_SERVICE_URL = os.getenv('INVENTORY_SERVICE_URL', 'http://inventory-app:8080')
    BILLING_SERVICE_URL = os.getenv('BILLING_SERVICE_URL', 'http://billing-app:8080')
    
    # RabbitMQ Configuration
    RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbit-queue')
    RABBITMQ_PORT = os.getenv('RABBITMQ_PORT', '5672')
    RABBITMQ_USER = os.getenv('RABBITMQ_USER', 'admin')
    RABBITMQ_PASSWORD = os.getenv('RABBITMQ_PASSWORD', 'admin')
    RABBITMQ_QUEUE = os.getenv('RABBITMQ_QUEUE', 'payment_queue')
    
    # Logging
    LOG_FILE = '/var/log/gateway/gateway.log'