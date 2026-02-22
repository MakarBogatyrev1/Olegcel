from flask import Flask, jsonify, request
from flask_cors import CORS
from models import db, Click, User
from database import init_db, get_db_stats
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

# Конфигурация базы данных
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(app.instance_path, 'clicks.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'pool_size': 10,
    'pool_recycle': 3600,
}

# Инициализация БД
db.init_app(app)

# Инициализируем БД при запуске
with app.app_context():
    init_db(app)

@app.route('/api/click', methods=['POST'])
def save_click():
    """Сохранение нажатия в БД"""
    try:
        data = request.json
        username = data.get('username', 'test_user')
        click_count = data.get('click_count', 1)
        
        # Получаем или создаем пользователя
        user = User.query.filter_by(username=username).first()
        if not user:
            user = User(username=username, total_clicks=0)
            db.session.add(user)
            db.session.flush()  # Чтобы получить ID
        
        # Обновляем счетчик пользователя
        user.total_clicks += click_count
        
        # Создаем запись о нажатии
        click = Click(
            user_id=user.id,  # Используем ID пользователя
            click_count=click_count
        )
        db.session.add(click)
        
        # Сохраняем изменения
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': f'Click saved! Total clicks for {username}: {user.total_clicks}',
            'user_total': user.total_clicks,
            'click_id': click.id,
            'user_id': user.id
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/clicks/<username>', methods=['GET'])
def get_user_clicks(username):
    """Получение количества нажатий пользователя"""
    user = User.query.filter_by(username=username).first()
    
    if user:
        # Получаем историю нажатий
        click_history = Click.query.filter_by(user_id=user.id)\
            .order_by(Click.timestamp.desc())\
            .limit(20)\
            .all()
        
        return jsonify({
            'status': 'success',
            'username': username,
            'user_id': user.id,
            'total_clicks': user.total_clicks,
            'history': [click.to_dict() for click in click_history]
        })
    else:
        return jsonify({
            'status': 'error',
            'message': 'User not found',
            'total_clicks': 0,
            'history': []
        }), 404

@app.route('/api/all_clicks', methods=['GET'])
def get_all_clicks():
    """Получение всех данных о нажатиях"""
    users = User.query.all()
    stats = get_db_stats()
    
    return jsonify({
        'status': 'success',
        'users': [user.to_dict() for user in users],
        'stats': stats
    })

@app.route('/api/reset_user/<username>', methods=['POST'])
def reset_user(username):
    """Сброс счетчика пользователя"""
    try:
        user = User.query.filter_by(username=username).first()
        if user:
            user.total_clicks = 0
            # Опционально: удаляем историю нажатий
            Click.query.filter_by(user_id=user.id).delete()
            db.session.commit()
            
            return jsonify({
                'status': 'success',
                'message': f'User {username} reset successfully',
                'total_clicks': 0
            })
        else:
            return jsonify({
                'status': 'error',
                'message': 'User not found'
            }), 404
            
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/leaderboard', methods=['GET'])
def get_leaderboard():
    """Получение таблицы лидеров"""
    users = User.query.order_by(User.total_clicks.desc()).limit(10).all()
    
    return jsonify({
        'status': 'success',
        'leaderboard': [
            {
                'username': user.username,
                'total_clicks': user.total_clicks,
                'user_id': user.id,
                'rank': i + 1
            }
            for i, user in enumerate(users)
        ]
    })

@app.route('/api/hello', methods=['GET'])
def hello():
    stats = get_db_stats()
    return jsonify({
        'message': 'Hello from Flask with SQLite!',
        'stats': stats,
        'status': 'success'
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)