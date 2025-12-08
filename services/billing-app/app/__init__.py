from flask import Flask
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

def create_app():
    app = Flask(__name__)
    
    # Load configuration
    from app.config import Config
    app.config.from_object(Config)
    
    # Initialize database
    db.init_app(app)
    
    # Register routes
    from app.routes import orders_bp
    app.register_blueprint(orders_bp, url_prefix='/api')
    
    return app