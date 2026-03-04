from sqlalchemy.orm import Session

from .auth import get_password_hash
from .models import User

DEMO_USERS = [
    {"username": "learner_alex", "password": "Pass1234!", "full_name": "Alex Kim", "role": "learner"},
    {"username": "learner_mia", "password": "Pass1234!", "full_name": "Mia Johnson", "role": "learner"},
    {"username": "teacher_john", "password": "Teach1234!", "full_name": "John Carter", "role": "teacher"},
    {"username": "teacher_nina", "password": "Teach1234!", "full_name": "Nina Patel", "role": "teacher"},
    {"username": "admin_sara", "password": "Admin1234!", "full_name": "Sara Lee", "role": "admin"},
    {"username": "admin_mike", "password": "Admin1234!", "full_name": "Mike Brown", "role": "admin"},
    {"username": "parent_olivia", "password": "Parent1234!", "full_name": "Olivia Wilson", "role": "parent"},
    {"username": "parent_david", "password": "Parent1234!", "full_name": "David Taylor", "role": "parent"},
]


def seed_users(db: Session) -> None:
    for user_data in DEMO_USERS:
        existing = db.query(User).filter(User.username == user_data["username"]).first()
        if existing:
            continue

        user = User(
            username=user_data["username"],
            full_name=user_data["full_name"],
            role=user_data["role"],
            hashed_password=get_password_hash(user_data["password"]),
        )
        db.add(user)

    db.commit()
