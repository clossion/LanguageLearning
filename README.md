# 个人生词本应用 (Personal Vocabulary Builder)

一个使用 **Flutter** 和 **Python (FastAPI)** 构建的个人化生词学习应用，旨在帮助用户高效管理和学习新单词。

![状态](https://img.shields.io/badge/status-in_development-yellow.svg) ![Python](https://img.shields.io/badge/Python-3.13-blue.svg) ![Flutter](https://img.shields.io/badge/Flutter-blue?logo=flutter) ![FastAPI](https://img.shields.io/badge/FastAPI-0.111.0-green?logo=fastapi)

---

## ⚠️ 项目状态

**开发中**。本项目尚处于早期开发阶段，功能和代码结构可能会发生较大变化。目前仅提供源代码。

---

## ✨ 主要功能

* **后端 (Python & FastAPI)**
    * **生词管理**: 添加、删除用户的个人生词。
    * **熟悉度标记**: 为单词标记不同的熟悉程度（如：陌生、了解、掌握）。
    * **个人化释义**: 允许用户为单词增删个性化的笔记和理解。

* **前端 (Flutter)**
    * **用户系统**: 提供完整的用户登录与资料管理界面。
    * **个人词库**: 清晰展示用户的生词库，并支持检索。
    * **学习界面**: 卡片式的学习与复习交互界面。

* **语音生成 (Text-to-Speech)**
    * **离线 TTS**: 集成 [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) 模型，提供高质量的离线单词发音功能。

---

## 🛠️ 技术栈

| 分类       | 技术                                                                             |
| :--------- | :------------------------------------------------------------------------------- |
| **后端** | Python 3.13                                                                      |
| **API 框架** | FastAPI                                                                          |
| **前端** | Flutter                                                                          |
| **TTS 模型** | [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M)                            |
| **词典数据** | [ECDICT](https://github.com/skywind3000/ECDICT)                                  |

---

## 🚀 快速开始

请遵循以下步骤来设置和运行本项目。

### 环境准备

确保你的开发环境中已安装：
* Python 3.13+
* Flutter SDK
* Git

### 安装与运行

1.  **克隆仓库**
    ```bash
    git clone <your-repository-url>
    cd <repository-name>
    ```

2.  **配置并运行后端**
    * 进入后端目录：
        ```bash
        cd backend
        ```
    * 创建 `data` 文件夹用于存放词典：
        ```bash
        mkdir data
        ```
    * **下载词典**：访问 [ECDICT 词典项目](https://github.com/skywind3000/ECDICT)，下载其 **DB 文件**，将其放入 `data` 文件夹内，并**重命名为 `en.db`**。
    * 创建并激活 Python 虚拟环境：
        ```bash
        # 创建虚拟环境
        python -m venv venv
        # 在 Windows 上激活
        .\venv\Scripts\activate
        # 在 macOS/Linux 上激活
        source venv/bin/activate
        ```
    * 安装所需的 Python 依赖包 (请根据你的 `requirements.txt` 文件或项目依赖进行调整)：
        ```bash
        pip install fastapi uvicorn[standard]
        ```
    * 启动后端服务 (假设入口文件为 `main.py`):
        ```bash
        uvicorn main:app --reload
        ```
    * *看到类似 `Uvicorn running on http://127.0.0.1:8000` 的输出，表示后端已成功运行。*

3.  **配置并运行前端**
    * 进入前端目录：
        ```bash
        # 确保你在项目的根目录
        cd ../frontend
        ```
    * 获取 Flutter 依赖项：
        ```bash
        flutter pub get
        ```
    * 根据 `pubspec.yaml` 文件中的配置，确保已添加所需的图标和字体资源。
    * 连接你的设备（或启动模拟器）并运行应用：
        ```bash
        flutter run
        ```

---

## 🙏 致谢

* **词典数据**: [ECDICT Project by skywind3000](https://github.com/skywind3000/ECDICT)
* **TTS 模型**: [Kokoro-82M by hexgrad](https://huggingface.co/hexgrad/Kokoro-82M)
