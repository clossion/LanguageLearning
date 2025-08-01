import srt
from lxml import html
import re
import unicodedata
from dataclasses import dataclass


@dataclass
class Subtitle:
    """字幕数据类"""
    start_time: int  # 毫秒
    end_time: int  # 毫秒
    content: str


class SubtitleManager:
    """字幕管理类，负责字幕文件加载、解析和查询"""

    def __init__(self):
        self.subtitles = []

    def load_subtitle(self, file_path):
        """
        加载 SRT 格式字幕文件，自动尝试多种编码

        Args:
            file_path: 字幕文件路径
        """
        encodings_to_try = ['utf-8', 'utf-8-sig', 'gbk', 'big5', 'latin1']
        for enc in encodings_to_try:
            try:
                with open(file_path, 'r', encoding=enc) as f:
                    content = f.read()
                break
            except UnicodeDecodeError:
                continue
        else:
            # UnicodeDecodeError 要求五个参数：encoding, object, start, end, reason
            raise UnicodeDecodeError(
                                 "utf-8",  # encoding
                                 b"",  # object
                                 0,  # start
                                 0,  # end
                                 "无法识别字幕文件编码，请转换为 UTF-8 或 GBK 等通用格式"
                 )

        srt_subtitles = list(srt.parse(content))
        self.subtitles = []
        for sub in srt_subtitles:
            start_time = SubtitleManager._timedelta_to_ms(sub.start)
            end_time = SubtitleManager._timedelta_to_ms(sub.end)

            # 清理字幕内容：去除 HTML 标签和非字母字符
            clean_content = self.clean_subtitle_text(sub.content)

            self.subtitles.append(Subtitle(
                start_time=start_time,
                end_time=end_time,
                content=clean_content
            ))

    @staticmethod
    def _timedelta_to_ms(td):
        """将 timedelta 转为毫秒"""
        return int(td.total_seconds() * 1000)

    @staticmethod
    def clean_subtitle_text(text: str) -> str:
        """
        清理字幕文本，去除 HTML 标签和非字母字符
        使用 lxml 解析 HTML 并提取文本内容
        """
        # 1. 去 HTML 标签
        tree = html.fromstring(text)
        clean_text = tree.text_content()

        # 2. 把换行、回车都替换为单个空格
        clean_text = clean_text.replace('\r\n', ' ').replace('\n', ' ').replace('\r', ' ')

        # 3. 把连续的空白折叠成一个空格，并去掉首尾空白
        clean_text = re.sub(r'\s+', ' ', clean_text).strip()

        # 4. 去掉除可打印之外的控制字符（选做）
        clean_text = re.sub(r'[\x00-\x08\x0B-\x1F\x7F]', '', clean_text)

        # 5. 去掉所有 Unicode 分类以 S（Symbol）或 C（Control） 开头的字符
        clean_text = ''.join(
            ch for ch in clean_text
            if not unicodedata.category(ch).startswith(('S', 'C'))
        )

        return clean_text

    def get_subtitle_at(self, position_ms):
        """
        获取指定时间点的字幕

        Args:
            position_ms: 当前播放位置（毫秒）
        """
        for subtitle in self.subtitles:
            if subtitle.start_time <= position_ms <= subtitle.end_time:
                return subtitle
        return None

    def has_subtitles(self):
        """检查是否加载了字幕"""
        return len(self.subtitles) > 0
