from sqlalchemy import Column, Integer, String

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(64), unique=True, index=True, nullable=False)
    full_name = Column(String(120), nullable=False)
    role = Column(String(20), nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
