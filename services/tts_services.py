import os
import tempfile
import hashlib
import numpy as np
import torch
import soundfile as sf
import io
import asyncio
import json
import re
import nltk
from pydub import AudioSegment
from concurrent.futures import ThreadPoolExecutor
from functools import partial
from kokoro import KModel, KPipeline
from nltk.tokenize import sent_tokenize
# 确保NLTK数据已下载
try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('punkt')

class TTSService:
    """文本到语音服务类，使用Kokoro模型生成音频文件并返回路径"""

    # 单例实例
    _instance = None
    _init_lock = asyncio.Lock()
    _initialized = False

    # Kokoro模型配置
    REPO_ID = 'hexgrad/Kokoro-82M-v1.1-zh'
    SAMPLE_RATE = 24000
    
    # 线程池，用于处理CPU密集型任务
    _executor = ThreadPoolExecutor(max_workers=2)
    
    # 语言配置 - 使用JSON格式定义，方便扩展
    LANGUAGE_CONFIG = {
        'en': {
            'lang_code': 'a',  # Kokoro模型的语言代码
            'voices': {
                'female': 'af_maple',  # 美国女声
                'male': 'af_sol'       # 美国男声
            },
            'speed_adjust': lambda len_ps, base_speed: base_speed,  # 英语使用固定速度
            'max_chunk_length': 150     # 限制每次处理的文本长度
        },
        'en-GB': {
            'lang_code': 'b',
            'voices': {
                'female': 'bf_vale',   # 英国女声
            },
            'speed_adjust': lambda len_ps, base_speed: base_speed,  # 英式英语使用固定速度
            'max_chunk_length': 150     # 限制每次处理的文本长度
        },
        'zh': {
            'lang_code': 'z',
            'voices': {
                'female': 'zf_001',    # 中文女声
                'male': 'zm_010'       # 中文男声
            },
            'speed_adjust': lambda len_ps, base_speed: base_speed * (1.0 if len_ps <= 83 else (1.0 - (len_ps - 83) / 500.0 if len_ps < 183 else 0.8)),
            'max_chunk_length': 100     # 中文处理单元较短
        }
    }
    
    # 段落间的静音长度
    N_ZEROS = 5000  # 约0.2秒的静默
    
    # 句子间的静音长度(更短)
    SENTENCE_N_ZEROS = 2000  # 约0.08秒的静默

    @classmethod
    async def get_instance(cls, cache_dir=None):
        """获取TTSService单例，确保模型只加载一次"""
        if cls._instance is None:
            async with cls._init_lock:
                if cls._instance is None:
                    cls._instance = cls(cache_dir)
                    await cls._instance.initialize()
        return cls._instance

    def __init__(self, cache_dir=None):
        """构造函数，注意这里不再加载模型，只进行基本初始化"""
        self.cache_dir = cache_dir or os.path.join(tempfile.gettempdir(), "tts_cache")
        self.ensure_cache_dir()
        self.model = None
        self.pipelines = {}
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
        
        # 尝试从外部JSON加载语言配置
        self._load_language_config()

    def _load_language_config(self):
        """从外部JSON文件加载语言配置，如果存在"""
        config_path = os.path.join(os.path.dirname(__file__), 'tts_language_config.json')
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r', encoding='utf-8') as f:
                    lang_config = json.load(f)
                
                # 处理加载的配置
                for lang, config in lang_config.items():
                    # 确保保留原始的速度调整函数逻辑
                    if lang in self.LANGUAGE_CONFIG:
                        speed_adjust = self.LANGUAGE_CONFIG[lang]['speed_adjust']
                        self.LANGUAGE_CONFIG[lang].update(config)
                        self.LANGUAGE_CONFIG[lang]['speed_adjust'] = speed_adjust
                    else:
                        # 对于新语言，创建默认的速度调整函数
                        config['speed_adjust'] = lambda len_ps, base_speed: base_speed
                        config['max_chunk_length'] = config.get('max_chunk_length', 150)
                        self.LANGUAGE_CONFIG[lang] = config
                
                print(f"从{config_path}加载了语言配置")
            except Exception as e:
                print(f"加载语言配置失败: {e}")

    async def initialize(self):
        """异步初始化模型和管道"""
        if self._initialized:
            return
            
        print(f"使用设备: {self.device}加载Kokoro模型...")
        
        # 在线程池中异步加载模型
        self.model = await self._run_in_executor(
            lambda: KModel(repo_id=self.REPO_ID).to(self.device).eval()
        )
        
        # 为支持的每种语言创建管道
        self.pipelines = {}
        for lang, config in self.LANGUAGE_CONFIG.items():
            lang_code = config.get('lang_code')
            if not lang_code:
                print(f"警告：语言 {lang} 缺少lang_code配置，跳过初始化")
                continue
                
            self.pipelines[lang] = await self._run_in_executor(
                lambda lc=lang_code: KPipeline(
                    lang_code=lc, 
                    repo_id=self.REPO_ID, 
                    model=self.model
                )
            )
        
        print("Kokoro TTS模型加载完成")
        self._initialized = True

    def ensure_cache_dir(self):
        """确保缓存目录存在"""
        if not os.path.exists(self.cache_dir):
            os.makedirs(self.cache_dir)

    def _get_audio_filename(self, text, lang, speed=1.0, is_word=False):
        """获取缓存音频文件的文件名，加入了速度参数和单词/文章区分"""
        prefix = "word_" if is_word else "text_"
        text_hash = hashlib.md5(f"{text}_{lang}_{speed}".encode()).hexdigest()
        return os.path.join(self.cache_dir, f"{prefix}{text_hash}.mp3")
    
    def _convert_wav_to_mp3(self, wav_data, sample_rate):
        """将WAV音频数据转换为MP3格式"""
        # 将numpy数组保存为WAV格式的内存数据
        wav_io = io.BytesIO()
        sf.write(wav_io, wav_data, sample_rate, format='WAV')
        wav_io.seek(0)
        
        # 使用pydub转换为MP3
        audio_segment = AudioSegment.from_wav(wav_io)
        mp3_io = io.BytesIO()
        audio_segment.export(mp3_io, format="mp3")
        return mp3_io.getvalue()

    async def _run_in_executor(self, func, *args, **kwargs):
        """在线程池中运行同步函数"""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            self._executor, 
            partial(func, *args, **kwargs)
        )

    def _get_voice(self, lang, gender='female'):
        """获取指定语言和性别的声音ID"""
        config = self.LANGUAGE_CONFIG.get(lang)
        if not config:
            # 默认使用英语
            config = self.LANGUAGE_CONFIG['en']
        
        voices = config.get('voices', {})
        return voices.get(gender, list(voices.values())[0] if voices else None)

    def _get_speed_callable(self, lang, base_speed=1.0):
        """获取语言特定的速度调整函数"""
        config = self.LANGUAGE_CONFIG.get(lang)
        if not config:
            # 默认使用英语配置
            config = self.LANGUAGE_CONFIG['en']
            
        # 创建封装了基础速度的callable
        speed_adjust_func = config.get('speed_adjust', lambda len_ps, bs: bs)
        return lambda len_ps: speed_adjust_func(len_ps, base_speed)

    def _get_max_chunk_length(self, lang):
        """获取语言的最大处理块长度"""
        config = self.LANGUAGE_CONFIG.get(lang)
        if not config:
            return 200  # 默认最大长度
        return config.get('max_chunk_length', 200)

    def _split_text_into_sentences(self, text):
        """
        使用NLTK将文本拆分为句子
        """
        try:
            # 预处理文本，处理引号等特殊情况
            processed_text = self._preprocess_for_sentence_tokenization(text)
            
            # 使用NLTK的sent_tokenize进行句子分割
            sentences = sent_tokenize(processed_text)
            
            # 恢复被替换的标点符号
            restored_sentences = []
            for s in sentences:
                s = s.replace('{{DOT}}', '.').replace('{{EXCL}}', '!').replace('{{QMARK}}', '?')
                restored_sentences.append(s)
            
            # 过滤空句
            return [s.strip() for s in restored_sentences if s.strip()]
        except Exception as e:
            print(f"NLTK句子拆分错误: {e}")
            # 回退到简单的拆分方法
            return self._simple_split_sentences(text)
    
    def _simple_split_sentences(self, text):
        """简单的句子拆分方法，作为NLTK的备用"""
        # 简单规则，按句号、问号、感叹号+空格拆分
        splits = []
        for line in text.split("\n"):
            if not line.strip():
                continue
            # 使用更安全的正则表达式
            for part in re.split(r'(?<=[.!?])\s+(?=[A-Z])', line):
                if part.strip():
                    splits.append(part.strip())
        return splits
    
    def _preprocess_for_sentence_tokenization(self, text):
        """预处理文本，以便更好地进行句子分割"""
        # 处理省略号
        text = text.replace('...', '…')
        
        # 处理一些常见的误分情况
        text = re.sub(r'(\.)([A-Z][a-z]*\.)', r'\1 \2', text)  # 处理缩写词后的句点
        
        # 处理引号内的内容，临时替换引号内的句点
        quote_pattern = r'[\'"][^\'"]+"'
        
        def replace_quote_content(match):
            quote = match.group(0)
            # 临时替换引号内的句点
            return quote.replace('.', '{{DOT}}').replace('!', '{{EXCL}}').replace('?', '{{QMARK}}')
        
        text = re.sub(quote_pattern, replace_quote_content, text)
        
        return text
    
    def _output_debug_text(self, paragraphs, output_path=None):
        """
        输出拆分后的文本到文件，用于调试 - 不再显示句子内部拆分
        """
        if not output_path:
            output_path = os.path.join(self.cache_dir, "debug_split_text.txt")
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("===== 段落和句子拆分调试输出 =====\n\n")
            
            for i, para in enumerate(paragraphs):
                f.write(f"[段落 {i+1}]\n")
                f.write(f"{para}\n\n")
                
                # 句子拆分调试
                sentences = self._split_text_into_sentences(para)
                f.write(f"-- 拆分为 {len(sentences)} 个句子 --\n")
                
                for j, sent in enumerate(sentences):
                    f.write(f"  [句子 {j+1}] {sent}\n")
                
                f.write("\n" + "-" * 60 + "\n\n")
        
        print(f"拆分调试文本已保存到: {output_path}")
        return output_path

    async def _process_audio(self, text, lang, pipeline, voice, speed_callable, is_word=False, min_file_size=100):
        """通用的音频处理逻辑"""
        if not text:
            return None
            
        # 使用不同的缓存文件名区分单词和文章
        audio_file = self._get_audio_filename(text, lang, speed=speed_callable(100), is_word=is_word)
        
        # 检查文件是否存在且大小合理
        if os.path.exists(audio_file) and os.path.getsize(audio_file) >= min_file_size:
            return audio_file
            
        # 文件不存在或大小异常，重新生成
        temp_file = f"{audio_file}.temp"
        try:
            # 异步生成音频
            generator = pipeline(text, voice=voice, speed=speed_callable)
            result = await self._run_in_executor(lambda: next(generator))
            wav_data = result.audio
            
            # 转换为MP3
            mp3_data = await self._run_in_executor(
                self._convert_wav_to_mp3, wav_data, self.SAMPLE_RATE
            )
            
            # 保存文件
            with open(temp_file, 'wb') as f:
                f.write(mp3_data)
            
            # 验证生成的文件大小
            file_size = os.path.getsize(temp_file)
            if file_size < min_file_size:
                if os.path.exists(temp_file):
                    os.remove(temp_file)
                print(f"生成的音频文件太小: {file_size} bytes")
                return None
                
            # 生成成功，移动到正式位置
            if os.path.exists(audio_file):
                os.remove(audio_file)
            os.rename(temp_file, audio_file)
            return audio_file
            
        except Exception as e:
            print(f"Kokoro TTS错误: {e}")
            if os.path.exists(temp_file):
                os.remove(temp_file)
            return None

    async def speak_word(self, text, lang='en', speed=1.0, gender='female'):
        """
        单词/短语TTS服务 - 针对短文本优化
        
        Args:
            text: 要转换的文本（单词或短语）
            lang: 语言代码，支持的语言取决于LANGUAGE_CONFIG
            speed: 语速倍率
            gender: 声音性别，'female'或'male'
            
        Returns:
            生成的音频文件路径，或者None(如果失败)
        """
        if not self._initialized:
            await self.initialize()
            
        if not text:
            return None
            
        # 限制单词长度
        if len(text) > 50:
            text = text[:50]
            
        # 获取语言配置和管道
        lang_config = self.LANGUAGE_CONFIG.get(lang)
        if not lang_config:
            print(f"不支持的语言: {lang}，使用默认语言英语")
            lang = 'en'
            lang_config = self.LANGUAGE_CONFIG['en']
            
        pipeline = self.pipelines.get(lang)
        if not pipeline:
            print(f"语言 {lang} 的管道未初始化")
            return None
            
        voice = self._get_voice(lang, gender)
        if not voice:
            print(f"语言 {lang} 没有可用的{gender}声音")
            return None
            
        speed_callable = self._get_speed_callable(lang, speed)
        
        # 处理单词音频 - 使用is_word=True标记为单词音频
        return await self._process_audio(
            text=text,
            lang=lang,
            pipeline=pipeline,
            voice=voice,
            speed_callable=speed_callable,
            is_word=True,
            min_file_size=100
        )

    async def speak(self, text, lang='en', speed=1.0, gender='female'):
        """
        文章/段落TTS服务 - 针对较长文本优化
        
        Args:
            text: 要转换的文本
            lang: 语言代码，支持的语言取决于LANGUAGE_CONFIG
            speed: 语速倍率
            gender: 声音性别，'female'或'male'
            
        Returns:
            生成的音频文件路径，或者None(如果失败)
        """
        if not self._initialized:
            await self.initialize()
            
        if not text:
            return None
        
        text = text.replace('\r\n', '\n').replace('\r', '\n')
        
        # 获取语言配置
        lang_config = self.LANGUAGE_CONFIG.get(lang)
        if not lang_config:
            print(f"不支持的语言: {lang}，使用默认语言英语")
            lang = 'en'
            lang_config = self.LANGUAGE_CONFIG['en']
            
        pipeline = self.pipelines.get(lang)
        if not pipeline:
            print(f"语言 {lang} 的管道未初始化")
            return None
            
        voice = self._get_voice(lang, gender)
        if not voice:
            print(f"语言 {lang} 没有可用的{gender}声音")
            return None
            
        speed_callable = self._get_speed_callable(lang, speed)
            
        # 使用语速参数获取缓存文件名    
        audio_file = self._get_audio_filename(text, lang, speed=speed_callable(100), is_word=False)

        # 检查缓存
        if os.path.exists(audio_file) and os.path.getsize(audio_file) >= 100:
            return audio_file
        
        # ===== 改进的文本拆分处理 =====
        
        # 分割段落
        paragraphs = text.split('\n\n')

        debug_file = self._output_debug_text(paragraphs)
        print(f"拆分调试信息已写入: {debug_file}")
        
        # 处理每个段落并合并
        all_wavs = []
        processed_chunks = 0
        total_chunks = sum(1 for p in paragraphs if p.strip())

        for i, paragraph in enumerate(paragraphs):
            if not paragraph.strip():
                continue
                
            print(f"处理段落 {i+1}/{len(paragraphs)} (长度: {len(paragraph)}字符)")
            
            # 添加段落间静默
            if i > 0 and all_wavs and self.N_ZEROS > 0:
                all_wavs.append(np.zeros(self.N_ZEROS))
            
            # 将段落拆分为句子
            sentences = self._split_text_into_sentences(paragraph)
            
            for j, sentence in enumerate(sentences):
                processed_chunks += 1            
                
                # 句子间添加较短的静默
                if j > 0:
                    if all_wavs and self.SENTENCE_N_ZEROS > 0:
                        all_wavs.append(np.zeros(self.SENTENCE_N_ZEROS))
                
                # 直接处理完整句子，不再拆分
                try:
                    generator = pipeline(sentence, voice=voice, speed=speed_callable)
                    result = await self._run_in_executor(lambda: next(generator))
                    wav_data = result.audio
                    
                    if wav_data is not None and hasattr(wav_data, 'shape') and len(wav_data.shape) > 0:
                        all_wavs.append(wav_data)
                    else:
                        print(f"  警告: 句子生成了空音频: '{sentence[:50]}...'")
                except Exception as e:
                    print(f"  句子处理错误: '{sentence[:50]}...' - {e}")
                    continue

        # 检查是否有有效音频
        if not all_wavs:
            print("没有生成任何有效的音频片段")
            return None
        
        print(f"音频处理完成，合并 {len(all_wavs)} 个音频片段...")
        
        # 合并所有音频
        try:
            combined_wav = np.concatenate(all_wavs)
        except ValueError as e:
            print(f"音频连接错误: {e}")
            # 尝试过滤掉不符合要求的数组
            valid_wavs = [wav for wav in all_wavs if hasattr(wav, 'shape') and len(wav.shape) > 0]
            if not valid_wavs:
                return None
            combined_wav = np.concatenate(valid_wavs)

        # 转换为MP3并保存
        temp_file = f"{audio_file}.temp"
        try:
            mp3_data = await self._run_in_executor(
                self._convert_wav_to_mp3, combined_wav, self.SAMPLE_RATE
            )
            
            with open(temp_file, 'wb') as f:
                f.write(mp3_data)
                
            # 验证生成的文件大小
            file_size = os.path.getsize(temp_file)
            if file_size < 100:
                if os.path.exists(temp_file):
                    os.remove(temp_file)
                print(f"生成的音频文件太小: {file_size} bytes")
                return None
                
            # 生成成功，移动到正式位置
            if os.path.exists(audio_file):
                os.remove(audio_file)
            os.rename(temp_file, audio_file)
            
            print(f"音频文件保存成功: {audio_file}")
            return audio_file
        except Exception as e:
            print(f"音频保存错误: {e}")
            if os.path.exists(temp_file):
                os.remove(temp_file)
            return None

    async def clear_cache(self):
        """清除所有缓存的音频文件"""
        try:
            count = 0
            for file in os.listdir(self.cache_dir):
                if file.endswith(".mp3"):
                    os.remove(os.path.join(self.cache_dir, file))
                    count += 1
            print(f"已清除 {count} 个缓存文件")
        except Exception as e:
            print(f"清除缓存失败: {e}")