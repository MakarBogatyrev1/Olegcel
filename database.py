from flask import Flask
from models import db, Click, User
import os

def init_db(app):
    """Инициализация базы данных"""
    # Создаем папку instance если её нет
    os.makedirs(app.instance_path, exist_ok=True)
    
    # Создаем таблицы
    with app.app_context():
        db.drop_all()  # Удаляем старые таблицы (только для разработки)
        db.create_all()
        print("База данных инициализирована!")
        
        # Создаем тестового пользователя если его нет
        test_user = User.query.filter_by(username='test_user').first()
        if not test_user:
            test_user = User(username='test_user', total_clicks=0)
            db.session.add(test_user)
            db.session.commit()
            print(f"Создан тестовый пользователь с ID: {test_user.id}")
            
            # Создаем несколько тестовых нажатий
            for i in range(3):
                click = Click(
                    user_id=test_user.id,
                    click_count=1
                )
                db.session.add(click)
            db.session.commit()
            print("Созданы тестовые нажатия")

def get_db_stats():
    """Получение статистики из БД"""
    total_users = User.query.count()
    total_clicks_all = db.session.query(db.func.sum(Click.click_count)).scalar() or 0
    recent_clicks = Click.query.order_by(Click.timestamp.desc()).limit(10).all()
    
    return {
        'total_users': total_users,
        'total_clicks_all': total_clicks_all,
        'recent_clicks': [click.to_dict() for click in recent_clicks]
    }