# backend/api/texts_api.py
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel
from backend.services.text_services import TextManager

router = APIRouter(prefix="/texts", tags=["texts"])
tm = TextManager()

# ---------- 输入模型 ----------
class FileIn(BaseModel):
    file_path: str

# ---------- 路由 ----------
@router.post("/load")
def load_text(payload: FileIn):
    """
    加载 TXT 文件到内存，返回文本元信息
    """
    try:
        t = tm.load_txt(payload.file_path)
        return {
            "status": "ok",
            "info": tm.info(t.id),
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/list")
def list_texts():
    """列出当前已缓存的全部文本 (id, title)"""
    return tm.list_all()


@router.get("/content")
def get_content(
    text_id: int = Query(..., description="load 接口返回的 id"),
    start_para: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500)
):
    """
    按『段』返回文本切片；前端收到后自行分页/排版
    """
    try:
        return tm.get_slice(text_id, start_para, limit)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
