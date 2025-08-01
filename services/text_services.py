# backend/services/text_services.py
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Tuple
import re
import unicodedata
import chardet  # pip install chardet


# ------------------------- 数据结构 ------------------------- #
@dataclass
class TextFile:
    id: int
    title: str              # 默认用文件名（不含后缀）
    path: Path
    paragraphs: List[str]   # 清洗后段落
    encoding: str           # 实际使用的编码名


# ------------------------- 核心管理器 ------------------------ #
class TextManager:
    """
    加载 TXT → 清洗 → 切段 → 内存缓存。
    若后续迁移数据库，只需把 self._store 换成 DAO（Data Access Object）即可。
    """

    def __init__(self) -> None:
        self._store: Dict[int, TextFile] = {}
        self._next_id: int = 1

    # ---------- 公共 API ---------- #
    def load_txt(self, file_path: str) -> TextFile:
        """
        读取本地 TXT 并按段缓存，返回 TextFile 对象。
        自动处理常见编码误判（UTF-8 ↔ Windows-1252）。
        """
        p = Path(file_path).expanduser().resolve()
        if not p.exists() or not p.is_file():
            raise FileNotFoundError(f"找不到文件: {p}")

        # (1) 读取字节并解码（包含多重回退）
        raw_bytes = p.read_bytes()
        text, encoding = self._decode_bytes(raw_bytes)

        # (2) 统一换行符
        text = text.replace("\r\n", "\n").replace("\r", "\n")

        # (3) 按空行切段，然后按句子分割
        raw_paras = re.split(r"\n\s*\n+", text)

        # 进一步按句子分割
                # 进一步按句子分割
                # 进一步按句子分割
        sentences = []
        for para in raw_paras:
            if para.strip():
                # 按标点符号分割并保留标点
                parts = re.split(r'([.!?]+)', para.strip())
                current_sentence = ""
                
                for i, part in enumerate(parts):
                    part = part.strip()
                    if not part:
                        continue
                        
                    if re.match(r'^[.!?]+$', part):  # 这是标点符号
                        current_sentence += part
                        if current_sentence.strip():
                            sentences.append(current_sentence.strip())
                        current_sentence = ""
                    else:  # 这是文本内容
                        current_sentence += part
                
                # 处理最后一个句子（如果没有标点结尾）
                if current_sentence.strip():
                    sentences.append(current_sentence.strip())

        # (4) 清洗段落
        paragraphs = [
            self._clean_para(par) for par in raw_paras if par.strip()
        ]

        # (5) 缓存并返回
        t = TextFile(
            id=self._next_id,
            title=p.stem,
            path=p,
            paragraphs=paragraphs,
            encoding=encoding,
        )
        self._store[self._next_id] = t
        self._next_id += 1
        return t

    def list_all(self) -> List[Tuple[int, str]]:
        """返回 (id, title) 元组列表，供前端展示。"""
        return [(t.id, t.title) for t in self._store.values()]

    def get_slice(
        self, text_id: int, start_para: int = 0, limit: int = 50
    ) -> List[str]:
        """分页返回段落（前端可二次分页）。"""
        t = self._store.get(text_id)
        if not t:
            raise KeyError(f"text_id={text_id} 未加载")
        return t.paragraphs[start_para : start_para + limit]

    def info(self, text_id: int) -> Dict:
        """返回文本元信息。"""
        t = self._store.get(text_id)
        if not t:
            raise KeyError(f"text_id={text_id} 未加载")
        return {
            "id": t.id,
            "title": t.title,
            "paragraphs": len(t.paragraphs),
            "encoding": t.encoding,
            "path": str(t.path),
        }

    # ---------- 私有工具 ---------- #
    @staticmethod
    def _decode_bytes(raw: bytes) -> Tuple[str, str]:
        """
        尝试多种策略解码字节流，返回 (文本, 编码名)。
        优先 UTF-8；若失败则使用 chardet；置信度低或可能误判时回退 Windows-1252。
        """
        # 1 最常见：UTF-8
        try:
            return raw.decode("utf-8"), "utf-8"
        except UnicodeDecodeError:
            pass

        # 2 让 chardet 猜测
        det = chardet.detect(raw)
        enc = (det["encoding"] or "").lower()
        conf = det.get("confidence", 0)

        # chardet 在全英文文本里易把 UTF-8 误判成 Windows-1252/LATIN-1
        if conf < 0.70 or enc in {"ascii", ""}:
            enc = "windows-1252"

        try:
            return raw.decode(enc), enc
        except UnicodeDecodeError:
            # 3 最后兜底：宽容解码 Windows-1252
            return raw.decode("windows-1252", errors="replace"), "windows-1252"

    @staticmethod
    def _clean_para(p: str) -> str:
        """
        清洗段落：
        1. 连续空白 → 1 空格
        2. 去控制字符
        3. 移除 Unicode 类别为 S* / C* 的符号与不可见字符（emoji、控制符等）
        """
        # 1. 折叠空白
        p = re.sub(r"\s+", " ", p).strip()

        # 2. 去控制字符 (ASCII 0–8, 11–31, 127)
        p = re.sub(r"[\x00-\x08\x0B-\x1F\x7F]", "", p)

        # 3. 过滤 Symbol (S) & Other (C) 类别字符
        p = "".join(
            ch for ch in p if not unicodedata.category(ch).startswith(("S", "C"))
        )
        return p
