from flask import Flask, jsonify, request
from flask_cors import CORS
from models import db, User, Call
from database import init_db
from datetime import datetime
from flask import render_template
import os

app = Flask(__name__)
CORS(app)

# Конфигурация базы данных
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(app.instance_path, 'calls.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Инициализация БД
db.init_app(app)

with app.app_context():
    init_db(app)

# ========== ОШИБКИ ============

@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html', error=e), 404

@app.errorhandler(500)
def internal_server_error(e):
    return render_template('500.html', error=e), 500

# ========== ПОЛЬЗОВАТЕЛИ ==========

@app.route('/api/users', methods=['GET'])
def get_users():
    """Получить всех пользователей"""
    users = User.query.all()
    return jsonify({
        'status': 'success',
        'users': [user.to_dict() for user in users]
    })

@app.route('/api/users/<username>', methods=['POST'])
def create_user(username):
    """Создать нового пользователя"""
    try:
        if User.query.filter_by(username=username).first():
            return jsonify({
                'status': 'error',
                'message': 'User already exists'
            }), 400
        
        user = User(username=username)
        db.session.add(user)
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'user': user.to_dict()
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Получить пользователя по ID"""
    user = User.query.get(user_id)
    if not user:
        return jsonify({'status': 'error', 'message': 'User not found'}), 404
    
    return jsonify({
        'status': 'success',
        'user': user.to_dict()
    })

# ========== ЗВОНКИ ==========

@app.route('/api/calls', methods=['GET'])
def get_calls():
    """Получить все активные звонки"""
    calls = Call.query.filter_by(status='active').all()
    return jsonify({
        'status': 'success',
        'calls': [call.to_dict() for call in calls]
    })

@app.route('/api/calls/<int:call_id>', methods=['GET'])
def get_call(call_id):
    """Получить звонок по ID"""
    call = Call.query.get(call_id)
    if not call:
        return jsonify({'status': 'error', 'message': 'Call not found'}), 404
    
    return jsonify({
        'status': 'success',
        'call': call.to_dict()
    })

@app.route('/api/calls/start', methods=['POST'])
def start_call():
    """Начать звонок"""
    try:
        data = request.json
        user_id = data.get('user_id')
        
        if not user_id:
            return jsonify({'status': 'error', 'message': 'user_id required'}), 400
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'status': 'error', 'message': 'User not found'}), 404
        
        # Создаем звонок
        call = Call(caller_id=user.id)
        db.session.add(call)
        db.session.flush()
        
        # Добавляем создателя как участника
        call.participants.append(user)
        user.in_call = True
        user.current_call_id = call.id
        
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'call': call.to_dict()
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/calls/<int:call_id>/join', methods=['POST'])
def join_call(call_id):
    """Присоединиться к звонку"""
    try:
        data = request.json
        user_id = data.get('user_id')
        
        if not user_id:
            return jsonify({'status': 'error', 'message': 'user_id required'}), 400
        
        user = User.query.get(user_id)
        call = Call.query.get(call_id)
        
        if not user or not call:
            return jsonify({'status': 'error', 'message': 'User or call not found'}), 404
        
        if call.status != 'active':
            return jsonify({'status': 'error', 'message': 'Call is not active'}), 400
        
        # Добавляем участника
        call.participants.append(user)
        user.in_call = True
        user.current_call_id = call.id
        
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'call': call.to_dict()
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/calls/<int:call_id>/leave', methods=['POST'])
def leave_call(call_id):
    """Покинуть звонок"""
    try:
        data = request.json
        user_id = data.get('user_id')
        
        if not user_id:
            return jsonify({'status': 'error', 'message': 'user_id required'}), 400
        
        user = User.query.get(user_id)
        call = Call.query.get(call_id)
        
        if not user or not call:
            return jsonify({'status': 'error', 'message': 'User or call not found'}), 404
        
        # Убираем участника
        if user in call.participants:
            call.participants.remove(user)
        
        user.in_call = False
        user.current_call_id = None
        user.last_seen = datetime.utcnow()
        
        # Если звонок пуст - завершаем
        if len(call.participants) == 0:
            call.status = 'ended'
            call.ended_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'call': call.to_dict() if call.status == 'active' else {'status': 'ended'}
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/calls/<int:call_id>/end', methods=['POST'])
def end_call(call_id):
    """Завершить звонок"""
    try:
        call = Call.query.get(call_id)
        if not call:
            return jsonify({'status': 'error', 'message': 'Call not found'}), 404
        
        # Освобождаем всех участников
        for user in call.participants:
            user.in_call = False
            user.current_call_id = None
        
        call.status = 'ended'
        call.ended_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': 'Call ended'
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': str(e)}), 500

# ========== ТЕСТОВЫЙ ENDPOINT ==========

@app.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({
        'status': 'success',
        'message': 'Calls API is running',
        'endpoints': [
            'GET /api/users - все пользователи',
            'POST /api/users/<username> - создать пользователя',
            'GET /api/users/<user_id> - пользователь по ID',
            'GET /api/calls - все активные звонки',
            'GET /api/calls/<call_id> - звонок по ID',
            'POST /api/calls/start - начать звонок {user_id}',
            'POST /api/calls/<call_id>/join - присоединиться {user_id}',
            'POST /api/calls/<call_id>/leave - покинуть {user_id}',
            'POST /api/calls/<call_id>/end - завершить звонок'
        ]
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)