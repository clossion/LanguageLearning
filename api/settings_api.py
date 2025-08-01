# app/api/settings_api.py
from fastapi import APIRouter
from pydantic import BaseModel
import json
import os

router = APIRouter(prefix="/settings")

class FontSettings(BaseModel):
    fontSize: int
    fontFamily: str
    backgroundColor: str

# 获取字体设置
@router.get("/")
def get_settings():
    try:
        with open("user_settings.json", "r") as file:
            settings = json.load(file)
        return settings
    except FileNotFoundError:
        return {"fontSize": 16, "fontFamily": "Roboto", "backgroundColor": "white"}

# 保存字体设置
@router.post("/save")
def save_settings(settings: FontSettings):
    try:
        with open("user_settings.json", "w") as file:
            json.dump(settings.dict(), file)
        return {"status": "success", "message": "Settings saved successfully"}
    except Exception as e:
        return {"status": "error", "message": str(e)}
