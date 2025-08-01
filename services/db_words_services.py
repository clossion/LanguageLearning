import sqlite3
from .db_auth_services import AuthDB  # 引入认证模块

class UserWordDB:
    """负责用户单词数据库的管理，和用户表共用同一个 SQLite 文件"""

    def __init__(self, db_path):
        self.db_path = db_path
        # ① 先用 AuthDB 确保 users 表存在
        self.auth_db = AuthDB(db_path)
        # ② 再创建 user_words 表
        self.init_database()

    def init_database(self):
        """初始化 user_words 表，并开启外键约束"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("PRAGMA foreign_keys = ON")
                cursor = conn.cursor()
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS user_words (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id INTEGER NOT NULL,
                        word TEXT,
                        meaning TEXT,
                        level INTEGER DEFAULT 0,
                        lang TEXT DEFAULT 'en',
                        added_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY(user_id) REFERENCES users(id)
                    )
                ''')
                conn.commit()
        except Exception as e:
            print(f"数据库初始化失败: {e}")

    def get_all_words(self, user_id, lang="en"):
        """获取某用户、某语言的全部单词记录"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT word, meaning, level, added_time 
                  FROM user_words 
                 WHERE user_id = ? AND lang = ?
            ''', (user_id, lang))
            rows = cursor.fetchall()

        return [
            {
                'user_word':   row[0],
                'meaning':     row[1],
                'familiarity': row[2],
                'added_time':  row[3],
            }
            for row in rows
        ]

    def get_single_word(self, user_id: int, word: str, lang="en"):
        """获取单个单词记录（含自定义释义和熟练度）"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT word, meaning, level
                  FROM user_words
                 WHERE user_id = ? AND word = ? AND lang = ?
            """, (user_id, word, lang))
            row = cursor.fetchone()

        if row:
            return {
                'user_word': row[0],
                'meaning':   row[1],
                'level':     row[2],
            }
        return None

    def add_single_word(self, user_id, word, level=0, lang="en"):
        """插入一条新单词记录（首次查词时用）"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO user_words (user_id, word, level, lang)
                VALUES (?, ?, ?, ?)
            ''', (user_id, word, level, lang))
            conn.commit()

    def update_user_meaning(self, user_id, word, meaning, lang="en"):
        """更新用户自定义释义"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE user_words
                   SET meaning = ?
                 WHERE user_id = ? AND word = ? AND lang = ?
            ''', (meaning, user_id, word, lang))
            conn.commit()

    def update_word_level(self, user_id, word, familiarity, lang="en"):
        """更新用户单词的熟悉度，如果单词不存在则先添加"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            # 先检查单词是否已存在
            cursor.execute('''
                SELECT COUNT(*) FROM user_words
                WHERE user_id = ? AND lower(word) = lower(?) AND lang = ?
            ''', (user_id, word, lang))
            
            # 如果不存在，先添加
            if cursor.fetchone()[0] == 0:
                cursor.execute('''
                    INSERT INTO user_words (user_id, word, level, lang)
                    VALUES (?, ?, ?, ?)
                ''', (user_id, word, familiarity, lang))
            else:
                # 存在则更新
                cursor.execute('''
                    UPDATE user_words
                    SET level = ?
                    WHERE user_id = ? AND lower(word) = lower(?) AND lang = ?
                ''', (familiarity, user_id, word, lang))
                
            conn.commit()

    def get_username(self, user_id: int) -> str | None:
        """仅返回用户名，不暴露其他字段"""
        user = self.auth_db.get_user(user_id)
        return user["username"] if user else None
