# app/api/auth_api.py
from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional
from backend.services.db_auth_services import AuthDB   # 改为从 auth_db 模块导入

router = APIRouter(prefix="/auth")
db = AuthDB("backend/data/user.db")  # 使用专门的认证模块

class RegisterRequest(BaseModel):
    username: str
    password: Optional[str] = ""  # 以后可以加密

class LoginRequest(BaseModel):
    username: str

@router.post("/register")
def register(data: RegisterRequest):
    with open("auth.log", "a", encoding="utf-8") as f:
        f.write(f"[REGISTER] 收到用户名: {data.username}\n")
    try:
        existing = db.get_user_id(data.username)
        if existing:
            return {"status": "fail", "message": "用户名已存在"}
        db.add_user(data.username, data.password or "")
        user_id = db.get_user_id(data.username)
        return {"status": "ok", "user_id": user_id}
    except Exception as e:
        with open("auth.log", "a", encoding="utf-8") as f:
            f.write(f"[ERROR] 注册异常: {str(e)}\n")
        return {"status": "error", "message": str(e)}

@router.post("/login")
def login(data: LoginRequest):
    user_id = db.get_user_id(data.username)
    if user_id:
        return {"status": "ok", "user_id": user_id}
    else:
        return {"status": "fail", "message": "用户不存在"}
