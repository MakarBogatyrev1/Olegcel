from flask import Flask
from models import db, User, Message
import os

def init_db(app):
    """Инициализация базы данных"""
    os.makedirs(app.instance_path, exist_ok=True)
    
    with app.app_context():
        db.drop_all()  # Только для разработки
        db.create_all()
        print("База данных мессенджера инициализирована!")
        
        # Создаем тестовых пользователей
        users_data = [
            {'username': 'test_user', 'total_messages': 0},
            {'username': 'john', 'total_messages': 0},
            {'username': 'jane', 'total_messages': 0},
            {'username': 'bob', 'total_messages': 0},
            {'username': 'alice', 'total_messages': 0},
        ]
        
        users = []
        for user_data in users_data:
            user = User.query.filter_by(username=user_data['username']).first()
            if not user:
                user = User(**user_data)
                db.session.add(user)
                users.append(user)
        
        db.session.commit()
        print(f"Создано {len(users_data)} пользователей")
        
        # Создаем тестовые сообщения
        if len(users) >= 2:
            test_messages = [
                {
                    'sender': users[0],  # test_user
                    'receiver': users[1],  # john
                    'content': 'Привет, Джон! Как дела?'
                },
                {
                    'sender': users[1],  # john
                    'receiver': users[0],  # test_user
                    'content': 'Привет! Всё отлично, работаю над проектом'
                },
                {
                    'sender': users[0],  # test_user
                    'receiver': users[2],  # jane
                    'content': 'Джейн, привет! Есть минутка?'
                },
                {
                    'sender': users[2],  # jane
                    'receiver': users[0],  # test_user
                    'content': 'Да, конечно! Что случилось?'
                },
                {
                    'sender': users[0],  # test_user
                    'receiver': users[3],  # bob
                    'content': 'Боб, как прошла встреча?'
                }
            ]
            
            for msg_data in test_messages:
                message = Message(
                    sender_id=msg_data['sender'].id,
                    receiver_id=msg_data['receiver'].id,
                    content=msg_data['content']
                )
                db.session.add(message)
                
                # Обновляем счетчик сообщений у отправителя
                msg_data['sender'].total_messages += 1
            
            db.session.commit()
            print(f"Создано {len(test_messages)} тестовых сообщений")

def get_db_stats():
    """Получение статистики из БД"""
    total_users = User.query.count()
    total_messages = Message.query.count()
    unread_messages = Message.query.filter_by(is_read=False).count()
    
    # Последние сообщения
    recent_messages = Message.query.order_by(Message.timestamp.desc()).limit(10).all()
    
    # Активные пользователи (с сообщениями за последние 5 минут)
    active_users = User.query.filter(User.last_seen > datetime.utcnow()).count()
    
    return {
        'total_users': total_users,
        'total_messages': total_messages,
        'unread_messages': unread_messages,
        'active_users': active_users,
        'recent_messages': [msg.to_dict() for msg in recent_messages]
    }