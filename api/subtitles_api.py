# ✅ app/api/subtitles_services.py
from fastapi import APIRouter, Query
from pydantic import BaseModel
from backend.services.subtitles_services import SubtitleManager 
import os

router = APIRouter(prefix="/subtitles")
manager = SubtitleManager()

class SubtitlePath(BaseModel):
    file_path: str

@router.post("/load")
def load_subtitles(data: SubtitlePath):
    subtitle_path = data.file_path

    if not os.path.isfile(subtitle_path):
        return {"status": "error", "message": "File not found"}

    try:
        manager.load_subtitle(subtitle_path)
        return {
            "status": "loaded",
            "count": len(manager.subtitles),
            "paragraphs": [s.content for s in manager.subtitles]
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


@router.get("/at")
def get_subtitle_at(position_ms: int = Query(...)):
    sub = manager.get_subtitle_at(position_ms)
    if sub:
        return {
            "start_time": sub.start_time,
            "end_time": sub.end_time,
            "content": sub.content
        }
    else:
        return {"status": "no_subtitle"}

@router.get("/status")
def subtitle_status():
    return {"loaded": manager.has_subtitles()}