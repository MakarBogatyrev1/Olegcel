from flask import Flask, jsonify, request
from flask_cors import CORS
from models import db, User, Message
from database import init_db
from datetime import datetime
from flask import render_template
import os

app = Flask(__name__)
CORS(app)

# Конфигурация базы данных
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(app.instance_path, 'messenger.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Инициализация БД
db.init_app(app)

with app.app_context():
    init_db(app)
# ========== ОШИБКИ ============

# Обработчик для ошибки 404
@app.errorhandler(404)
def page_not_found(e):
    """Показываем кастомную HTML страницу для 404"""
    return render_template('404.html', error=e), 404

# Обработчик для ошибки 500
@app.errorhandler(500)
def internal_server_error(e):
    """Показываем кастомную HTML страницу для 500"""
    return render_template('500.html', error=e), 500

@app.route('/500')
def error500():
    return render_template('500.html')

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

# ========== ЧАТЫ ==========

@app.route('/api/chats/<username>', methods=['GET'])
def get_chats(username):
    """Получить все чаты пользователя"""
    user = User.query.filter_by(username=username).first()
    if not user:
        return jsonify({'status': 'error', 'message': 'User not found'}),404
    
    # Находим всех уникальных собеседников
    sent = db.session.query(Message.receiver_id).filter(Message.sender_id == user.id).distinct()
    received = db.session.query(Message.sender_id).filter(Message.receiver_id == user.id).distinct()
    
    chat_partner_ids = set([r[0] for r in sent.union(received).all()])
    chats = []
    
    for partner_id in chat_partner_ids:
        partner = User.query.get(partner_id)
        if not partner:
            continue
        
        # Последнее сообщение в чате
        last_message = Message.query.filter(
            ((Message.sender_id == user.id) & (Message.receiver_id == partner.id)) |
            ((Message.sender_id == partner.id) & (Message.receiver_id == user.id))
        ).order_by(Message.timestamp.desc()).first()
        
        # Количество непрочитанных
        unread_count = Message.query.filter_by(
            sender_id=partner.id,
            receiver_id=user.id,
            is_read=False
        ).count()
        
        chats.append({
            'chat_with': partner.username,
            'chat_with_id': partner.id,
            'last_message': last_message.content if last_message else None,
            'last_message_time': last_message.timestamp.isoformat() if last_message else None,
            'unread_count': unread_count
        })
    
    return jsonify({
        'status': 'success',
        'username': username,
        'chats': chats
    })

# ========== СООБЩЕНИЯ ==========

@app.route('/api/messages', methods=['POST'])
def send_message():
    """Отправить сообщение"""
    try:
        data = request.json
        sender_name = data.get('sender')
        receiver_name = data.get('receiver')
        content = data.get('content')
        
        if not all([sender_name, receiver_name, content]):
            return jsonify({'status': 'error', 'message': 'Missing fields'}), 400
        
        sender = User.query.filter_by(username=sender_name).first()
        receiver = User.query.filter_by(username=receiver_name).first()
        
        if not sender or not receiver:
            return jsonify({'status': 'error', 'message': 'User not found'}),404
        
        message = Message(
            sender_id=sender.id,
            receiver_id=receiver.id,
            content=content
        )
        db.session.add(message)
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': message.to_dict()
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/messages/<user1>/<user2>', methods=['GET'])
def get_messages(user1, user2):
    """Получить переписку между двумя пользователями"""
    user_a = User.query.filter_by(username=user1).first()
    user_b = User.query.filter_by(username=user2).first()
    
    if not user_a or not user_b:
        return jsonify({'status': 'error', 'message': 'User not found'}), 404
    
    messages = Message.query.filter(
        ((Message.sender_id == user_a.id) & (Message.receiver_id == user_b.id)) |
        ((Message.sender_id == user_b.id) & (Message.receiver_id == user_a.id))
    ).order_by(Message.timestamp.asc()).all()
    
    return jsonify({
        'status': 'success',
        'user1': user1,
        'user2': user2,
        'messages': [msg.to_dict() for msg in messages]
    })

@app.route('/api/messages/<message_id>/read', methods=['POST'])
def mark_as_read(message_id):
    """Отметить сообщение как прочитанное"""
    try:
        message = Message.query.get(message_id)
        if not message:
            return jsonify({'status': 'error', 'message': 'Message not found'}), 404
        
        message.is_read = True
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': 'Marked as read'
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

# ========== ТЕСТОВЫЙ ENDPOINT ==========

@app.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({
        'status': 'success',
        'message': 'Messenger API is running',
        'endpoints': [
            'GET /api/users',
            'POST /api/users/<username>',
            'GET /api/chats/<username>',
            'POST /api/messages',
            'GET /api/messages/<user1>/<user2>',
            'POST /api/messages/<message_id>/read'
        ]
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)