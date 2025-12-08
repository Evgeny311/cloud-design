import os
import sys
from flask import jsonify
from app import create_app

print("=== API Gateway Starting ===", file=sys.stderr, flush=True)
print(f"Environment: {os.environ}", file=sys.stderr, flush=True)

app = create_app()

print("=== App created successfully ===", file=sys.stderr, flush=True)

# --- Добавляем приветственный маршрут ---
@app.route("/")
def home():
    return jsonify({
        "message": "Welcome to Play with Containers API Gateway 🚀",
        "status": "running",
        "endpoints": ["/health", "/inventory", "/billing"]
    })

# Запускаем приложение без if __name__ == '__main__'
if __name__ == '__main__':
    port = int(os.getenv('APP_PORT', 3000))
    app.run(host='0.0.0.0', port=port, debug=False)
else:
    # Когда запускается через CMD, тоже запускаем
    port = int(os.getenv('APP_PORT', 3000))
    app.run(host='0.0.0.0', port=port, debug=False)