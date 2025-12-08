from flask import Flask

def create_app():
    app = Flask(__name__)
    
    # Load configuration
    from app.config import Config
    app.config.from_object(Config)
    
    # Register routes
    from app.proxy import gateway_bp
    app.register_blueprint(gateway_bp)
    
    return app