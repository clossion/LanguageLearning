from fastapi import APIRouter, Query, Body
from typing import List
from backend.services.translation_services import TranslationService

router = APIRouter(prefix="/translation")
translator = TranslationService()

@router.get("/lookup")
def lookup_word(word: str = Query(..., description="要查询的单词")):
    return translator.lookup_word(word)

@router.post("/batch_lookup")
def batch_lookup_words(words: List[str] = Body(..., description="要查询的单词列表")):
    result = {}
    for w in words:
        if not w or not isinstance(w, str):
            result[w] = {"error": "无效的单词"}
            continue
        result[w] = translator.lookup_word(w)
    return result

@router.get("/translate")
def translate_sentence(q: str = Query(..., description="要翻译的句子")):
    return {"translation": translator.translate_sentence(q)}
