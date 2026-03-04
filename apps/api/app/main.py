from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .auth import create_access_token, decode_token, verify_password
from .database import Base, engine, get_db
from .models import User
from .schemas import LoginRequest, LoginResponse, UserOut
from .seed import seed_users

app = FastAPI(title="Study Platform API")
security = HTTPBearer()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(bind=engine)
    db = next(get_db())
    seed_users(db)


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/auth/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == payload.username).first()
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    token = create_access_token(subject=user.username, role=user.role)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": user,
    }


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload = decode_token(creds.credentials)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid token")

    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


@app.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@app.get("/role/{role_name}")
def role_data(role_name: str, user: User = Depends(get_current_user)):
    if user.role != role_name:
        raise HTTPException(status_code=403, detail="Forbidden for this role")

    data = {
        "learner": {"message": "Learner-specific data", "tasks_due": 4},
        "teacher": {"message": "Teacher-specific data", "classes_today": 3},
        "admin": {"message": "Admin-specific data", "open_alerts": 1},
        "parent": {"message": "Parent-specific data", "children_linked": 2},
    }

    return {"role": role_name, "data": data.get(role_name, {})}
