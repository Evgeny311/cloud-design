import os
import threading
from app import create_app
from app.consumer import start_consumer

app = create_app()

# Start RabbitMQ consumer in a separate thread
consumer_thread = threading.Thread(target=start_consumer, daemon=True)
consumer_thread.start()

if __name__ == '__main__':
    port = int(os.getenv('APP_PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)