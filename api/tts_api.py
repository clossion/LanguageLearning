from fastapi import APIRouter, Query, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from backend.services.tts_services import TTSService
import asyncio
import time

router = APIRouter(prefix="/tts")
tts_service = None  # 将在启动时初始化
loading_task = None  # 用于跟踪后台加载任务
loading_started = False

async def load_model_in_background():
    """在后台加载TTS模型"""
    global tts_service
    try:
        print("开始在后台加载TTS模型...")
        start_time = time.time()
        tts_service = await TTSService.get_instance()
        elapsed = time.time() - start_time
        print(f"TTS模型加载完成，耗时: {elapsed:.2f}秒")
    except Exception as e:
        print(f"TTS模型加载失败: {e}")

@router.on_event("startup")
async def startup_event():
    """应用启动事件：启动后台加载任务但不等待其完成"""
    global loading_task, loading_started
    if not loading_started:
        loading_started = True
        # 创建任务但不等待它
        loading_task = asyncio.create_task(load_model_in_background())
        print("应用启动完成，TTS模型正在后台加载...")

@router.get("/word")
async def word_to_speech(
    text: str = Query(...), 
    lang: str = Query("en"),
    speed: float = Query(1.0, ge=0.5, le=1.5),
):
    """
    单词TTS API - 针对简短文本优化
    """
    global tts_service, loading_task
    
    # 检查服务初始化...与原代码相同
    if tts_service is None:
        if loading_task is not None and not loading_task.done():
            raise HTTPException(status_code=503, detail="TTS服务正在初始化")
        elif loading_task is None or loading_task.done():
            loading_task = asyncio.create_task(load_model_in_background())
            raise HTTPException(status_code=503, detail="TTS服务正在初始化")
    
    # 对text进行长度限制，确保是单词级别
    if len(text) > 50:  # 单词不应超过这个长度
        text = text[:50]
    
    # 调用优化后的单词TTS方法
    audio_path = await tts_service.speak_word(text, lang, speed)
    if not audio_path:
        raise HTTPException(status_code=500, detail="单词TTS生成失败")
    return FileResponse(audio_path)

@router.get("/speak")
async def text_to_speech(
    text: str = Query(...), 
    lang: str = Query("en"),
    speed: float = Query(1.0, ge=0.5, le=1.5),
):
    """
    文章TTS API - 原有功能，优化后用于处理较长文本
    """
    global tts_service, loading_task
    
    # 服务初始化检查...
    if tts_service is None:
        if loading_task is not None and not loading_task.done():
            raise HTTPException(status_code=503, detail="TTS服务正在初始化")
        elif loading_task is None or loading_task.done():
            loading_task = asyncio.create_task(load_model_in_background())
            raise HTTPException(status_code=503, detail="TTS服务正在初始化")
    
    # 调用文章TTS方法
    audio_path = await tts_service.speak(text, lang, speed)
    if not audio_path:
        raise HTTPException(status_code=500, detail="TTS生成失败")
    return FileResponse(audio_path)