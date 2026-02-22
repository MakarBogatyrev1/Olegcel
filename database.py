from models import db, User, Call
import os

def init_db(app):
    """Инициализация базы данных"""
    os.makedirs(app.instance_path, exist_ok=True)
    
    with app.app_context():
        db.create_all()
        print("База данных инициализирована!")
        
        # Создаем тестовых пользователей если их нет
        test_users = ['user1', 'user2', 'user3', 'user4']
        for username in test_users:
            if not User.query.filter_by(username=username).first():
                user = User(username=username)
                db.session.add(user)
        
        db.session.commit()
        print(f"Созданы тестовые пользователи: {test_users}")