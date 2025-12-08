from flask import Blueprint, jsonify, request
from app import db
from app.models import Movie

movies_bp = Blueprint('movies', __name__)

@movies_bp.route('/movies', methods=['GET'])
def get_movies():
    """Get all movies"""
    movies = Movie.query.all()
    return jsonify([movie.to_dict() for movie in movies]), 200

@movies_bp.route('/movies/<int:movie_id>', methods=['GET'])
def get_movie(movie_id):
    """Get a specific movie by ID"""
    movie = Movie.query.get(movie_id)
    if not movie:
        return jsonify({'error': 'Movie not found'}), 404
    return jsonify(movie.to_dict()), 200

@movies_bp.route('/movies', methods=['POST'])
def create_movie():
    """Create a new movie"""
    data = request.get_json()
    
    if not data or not all(k in data for k in ['title', 'price', 'stock']):
        return jsonify({'error': 'Missing required fields'}), 400
    
    movie = Movie(
        title=data['title'],
        description=data.get('description', ''),
        price=data['price'],
        stock=data['stock']
    )
    
    db.session.add(movie)
    db.session.commit()
    
    return jsonify(movie.to_dict()), 201

@movies_bp.route('/movies/<int:movie_id>', methods=['PUT'])
def update_movie(movie_id):
    """Update a movie"""
    movie = Movie.query.get(movie_id)
    if not movie:
        return jsonify({'error': 'Movie not found'}), 404
    
    data = request.get_json()
    
    if 'title' in data:
        movie.title = data['title']
    if 'description' in data:
        movie.description = data['description']
    if 'price' in data:
        movie.price = data['price']
    if 'stock' in data:
        movie.stock = data['stock']
    
    db.session.commit()
    
    return jsonify(movie.to_dict()), 200

@movies_bp.route('/movies/<int:movie_id>', methods=['DELETE'])
def delete_movie(movie_id):
    """Delete a movie"""
    movie = Movie.query.get(movie_id)
    if not movie:
        return jsonify({'error': 'Movie not found'}), 404
    
    db.session.delete(movie)
    db.session.commit()
    
    return jsonify({'message': 'Movie deleted successfully'}), 200

@movies_bp.route('/movies/<int:movie_id>/reduce-stock', methods=['POST'])
def reduce_stock(movie_id):
    """Reduce stock of a movie (used when order is placed)"""
    movie = Movie.query.get(movie_id)
    if not movie:
        return jsonify({'error': 'Movie not found'}), 404
    
    data = request.get_json()
    quantity = data.get('quantity', 1)
    
    if movie.stock < quantity:
        return jsonify({'error': 'Insufficient stock'}), 400
    
    movie.stock -= quantity
    db.session.commit()
    
    return jsonify(movie.to_dict()), 200