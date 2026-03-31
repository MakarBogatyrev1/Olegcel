from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()

# Ассоциативная таблица для участников звонка
call_participants = db.Table('call_participants',
    db.Column('call_id', db.Integer, db.ForeignKey('calls.id'), primary_key=True),
    db.Column('user_id', db.Integer, db.ForeignKey('users.id'), primary_key=True),
    db.Column('joined_at', db.DateTime, default=datetime.utcnow)
)

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    in_call = db.Column(db.Boolean, default=False)
    current_call_id = db.Column(db.Integer, db.ForeignKey('calls.id'), nullable=True)
    last_seen = db.Column(db.DateTime, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'in_call': self.in_call,
            'current_call_id': self.current_call_id,
            'last_seen': self.last_seen.isoformat() if self.last_seen else None
        }

class Call(db.Model):
    __tablename__ = 'calls'
    
    id = db.Column(db.Integer, primary_key=True)
    caller_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    status = db.Column(db.String(20), default='active')  # active, ended
    started_at = db.Column(db.DateTime, default=datetime.utcnow)
    ended_at = db.Column(db.DateTime, nullable=True)
    
    # Участники звонка
    participants = db.relationship('User', 
                                  secondary=call_participants,
                                  lazy='subquery',
                                  backref=db.backref('calls', lazy=True))
    
    def to_dict(self):
        return {
            'id': self.id,
            'caller_id': self.caller_id,
            'status': self.status,
            'started_at': self.started_at.isoformat() if self.started_at else None,
            'ended_at': self.ended_at.isoformat() if self.ended_at else None,
            'participants': [p.id for p in self.participants],
            'participant_count': len(self.participants)
        }