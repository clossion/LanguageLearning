import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import '../utils/api_service.dart';

class TTSService {
  // 当前活跃的播放器实例
  Player? _activePlayer;

  /// 单词/短语TTS - 使用word端点，针对单个词优化
  Future<void> speakText(
    String text, {
    String lang = 'en',
    double speed = 0.8,
    String gender = 'female',
  }) async {
    if (text.isEmpty) return;

    try {
      // 停止当前播放（如果有）
      await _stopCurrentPlayback();

      // 请求单词TTS服务 - 使用word端点
      final ttsUrl =
          '$API_BASE/tts/word?text=${Uri.encodeComponent(text)}&lang=$lang&speed=$speed&gender=$gender';
      final res = await http
          .get(Uri.parse(ttsUrl))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) {
        debugPrint('单词TTS请求失败: ${res.statusCode}');
        return;
      }

      // 创建临时文件解决方案
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/tts_word_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );

      // 写入音频数据
      await tempFile.writeAsBytes(res.bodyBytes);

      // 创建新播放器
      final player = Player();
      _activePlayer = player;

      // 播放临时文件
      await player.open(Media(tempFile.path));
      await player.play();

      // 播放完成后释放资源
      player.stream.completed.listen((isCompleted) {
        if (isCompleted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            player.dispose();
            tempFile.delete();
            if (_activePlayer == player) {
              _activePlayer = null;
            }
          });
        }
      });
    } catch (e) {
      debugPrint('单词播放失败: $e');
    }
  }

  /// 生成文本文件的音频 - 直接读取文件内容发送给后端
  Future<bool> generateAudioFile(
    String textFilePath,
    String outputPath, {
    String lang = 'en',
    double speed = 1.0,
    String gender = 'female',
  }) async {
    try {
      // 停止当前播放
      await _stopCurrentPlayback();

      // 检查输出音频文件是否已存在
      final outputFile = File(outputPath);
      bool audioExists = await outputFile.exists();

      if (!audioExists) {
        // 删除可能存在的临时文件
        final tempPath = '$outputPath.temp';
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        // 直接从文件读取文本
        final textFile = File(textFilePath);
        if (!await textFile.exists()) {
          throw Exception('文本文件不存在: $textFilePath');
        }
        
        // 读取文本内容
        final text = await textFile.readAsString();
        
        // 直接发送到后端，让后端处理段落拆分
        final encodedText = Uri.encodeComponent(text);
        final ttsUrl = Uri.parse(
          '$API_BASE/tts/speak?text=$encodedText&lang=$lang&speed=$speed&gender=$gender',
        );

        final response = await http
            .get(ttsUrl)
            .timeout(const Duration(seconds: 60));

        if (response.statusCode != 200) {
          throw Exception('TTS API错误: ${response.statusCode}');
        }

        // 写入临时文件
        await tempFile.writeAsBytes(response.bodyBytes);

        // 移动到最终位置
        await tempFile.rename(outputPath);
        audioExists = true;
      }

      return audioExists;
    } catch (e) {
      debugPrint('音频生成错误: $e');
      return false;
    }
  }

  /// 停止当前播放
  Future<void> _stopCurrentPlayback() async {
    if (_activePlayer != null) {
      await _activePlayer!.pause();
      await _activePlayer!.dispose();
      _activePlayer = null;
    }
  }
}