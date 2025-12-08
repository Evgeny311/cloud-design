from flask import Blueprint, jsonify, request
from app import db
from app.models import Order

orders_bp = Blueprint('orders', __name__)

@orders_bp.route('/orders', methods=['GET'])
def get_orders():
    """Get all orders"""
    orders = Order.query.all()
    return jsonify([order.to_dict() for order in orders]), 200

@orders_bp.route('/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    """Get a specific order by ID"""
    order = Order.query.get(order_id)
    if not order:
        return jsonify({'error': 'Order not found'}), 404
    return jsonify(order.to_dict()), 200

@orders_bp.route('/orders/user/<int:user_id>', methods=['GET'])
def get_user_orders(user_id):
    """Get all orders for a specific user"""
    orders = Order.query.filter_by(user_id=user_id).all()
    return jsonify([order.to_dict() for order in orders]), 200

@orders_bp.route('/orders/<int:order_id>/status', methods=['PUT'])
def update_order_status(order_id):
    """Update order status"""
    order = Order.query.get(order_id)
    if not order:
        return jsonify({'error': 'Order not found'}), 404
    
    data = request.get_json()
    status = data.get('status')
    
    if not status:
        return jsonify({'error': 'Status is required'}), 400
    
    order.status = status
    db.session.commit()
    
    return jsonify(order.to_dict()), 200