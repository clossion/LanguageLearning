from fastapi import APIRouter, Query
from pydantic import BaseModel
from backend.services.db_words_services import UserWordDB

router = APIRouter(prefix="/words")
db = UserWordDB("backend/data/user.db")

class WordBase(BaseModel):
    user_id: int
    word:    str
    lang:    str = "en"

class LevelData(WordBase):
    level: int  # 0–5

class MeaningIn(WordBase):
    meaning: str

@router.get("")
def get_words(user_id: int = Query(...), lang: str = Query("en")):
    return db.get_all_words(user_id, lang)

@router.post("/familiarity")
def update_level(data: LevelData):
    db.update_word_level(data.user_id, data.word, data.level, data.lang)
    return {"status": "updated"}

@router.post("/meaning")
def save_meaning(data: MeaningIn):
    db.update_user_meaning(data.user_id, data.word, data.meaning, data.lang)
    return {"status": "ok"}

@router.get("/meaning")
def get_single_word_meaning(user_id: int = Query(...), word: str = Query(...), lang: str = Query("en")):
    result = db.get_single_word(user_id, word, lang)
    if result:
        return result
    return {"error": "Word not found"}
