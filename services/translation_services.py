import os
import sqlite3
import requests
import hashlib
import random

class TranslationService:
    """翻译服务类，支持本地词典查询和句子翻译"""

    def __init__(self,
                 app_id="YOUR_APP_ID",
                 app_key="YOUR_APP_KEY",
                 db_relative_path="../data/en.db"):
        self.app_id = app_id
        self.app_key = app_key
        self.youdao_api_url = "https://openapi.youdao.com/api"
        base_dir = os.path.dirname(os.path.abspath(__file__))
        self.db_path = os.path.normpath(os.path.join(base_dir, db_relative_path))

    def lookup_word(self, word: str) -> dict:
        """从本地 SQLite 词典数据库查询单词释义"""
        word_raw = word.strip()
        variants = [
            word_raw,
            word_raw.lower(),
            word_raw.capitalize(),
            word_raw.upper(),
        ]
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            row = None
            for w in variants:
                cursor.execute(
                    "SELECT id, word, phonetic, definition, translation, exchange "
                    "FROM stardict WHERE word = ? LIMIT 1",
                    (w,)
                )
                row = cursor.fetchone()
                if row:
                    break
            conn.close()

            if row:
                _, word_std, phonetic, definition, translation, exchange = row
                return {
                    "word":       word_std,
                    "phonetic":   phonetic or "无",
                    "definition": definition or "无",
                    "translation": translation or "无",
                    "exchange":    exchange or "无",
                }
            else:
                return {"error": f"❌ 未找到定义：{word_raw}"}
        except Exception as e:
            return {"error": f"⚠️ 查询失败：{str(e)}"}

    def translate_sentence(self, text: str) -> str:
        """使用有道翻译 API（或模拟）翻译整个句子"""
        if self.app_id == "YOUR_APP_ID":
            return f"[模拟翻译] {text}"

        try:
            salt = str(random.randint(1, 65536))
            sign = hashlib.md5((self.app_id + text + salt + self.app_key).encode()).hexdigest()
            params = {
                "q": text,
                "from": "en",
                "to": "zh-CHS",
                "appKey": self.app_id,
                "salt":   salt,
                "sign":   sign
            }
            response = requests.get(self.youdao_api_url, params=params)
            data = response.json()

            if data.get("errorCode") == "0":
                return data.get("translation", ["翻译失败"])[0]
            else:
                return f"❌ 翻译失败 (错误码 {data.get('errorCode')})"
        except Exception as e:
            return f"⚠️ 网络或接口错误：{str(e)}"
