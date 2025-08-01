// lib/services/service_provider.dart
import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'video_service.dart';
import 'vocabulary_service.dart';
import 'subtitle_service.dart';  
import 'reader_settings_service.dart';
import 'texts_service.dart';
import 'tts_service.dart';

/// 服务提供者类
/// 统一管理所有服务实例，简化服务访问和依赖注入
class ServiceProvider extends InheritedWidget {
  // 视频服务
  final VideoService videoService;
  // TTS服务
  final TTSService ttsService;

  // 词汇服务
  final VocabularyService vocabularyService;
  final SubtitleService subtitleService; 
  final TextService textService;  

  // 阅读设置服务
  final ReaderSettingsService settingsService;

  // 消息提示回调
  final Function(String message) showMessage;

  // 添加是否已初始化用户词库的标志
  final bool _hasInitializedUserWords;

  const ServiceProvider({
    super.key,
    required this.videoService,
    required this.vocabularyService,
    required this.subtitleService,   
    required this.textService,
    required this.settingsService,
    required this.ttsService, 
    required this.showMessage,
    bool hasInitializedUserWords = false,
    required super.child,
  }) : _hasInitializedUserWords = hasInitializedUserWords;

  /// 静态方法，用于在widget树中获取ServiceProvider实例
  static ServiceProvider of(BuildContext context) {
    final ServiceProvider? result =
        context.dependOnInheritedWidgetOfExactType<ServiceProvider>();
    assert(result != null, 'No ServiceProvider found in context');

    // 优化：如果词库还未初始化，在第一次访问时初始化
    if (!result!._hasInitializedUserWords &&
        result.vocabularyService.userId != null) {
      // 使用异步加载，不阻塞UI
      unawaited(result.vocabularyService.loadUserWords());

      // 标记为已初始化（通过新建一个实例）
      return ServiceProvider(
        videoService: result.videoService,
        vocabularyService: result.vocabularyService,
        subtitleService: result.subtitleService,
        textService: result.textService,
        settingsService: result.settingsService,
        ttsService: result.ttsService,
        showMessage: result.showMessage,
        hasInitializedUserWords: true,
        child: result.child,
      );
    }

    return result;
  }

  @override
  bool updateShouldNotify(ServiceProvider oldWidget) {
    // 只有在关键服务实例变化时才通知更新
    return vocabularyService != oldWidget.vocabularyService ||
        _hasInitializedUserWords != oldWidget._hasInitializedUserWords ||
        subtitleService != oldWidget.subtitleService;
  }

  /// 初始化所有服务
  static ServiceProvider init({
    required Function(String message) showMessage,
    required String? userId,
    required Widget child,
  }) {
    // 创建视频服务
    final videoService = VideoService(onMessage: showMessage);

    // 创建TTS服务
    final ttsService = TTSService();

    // 创建词汇服务
    final vocabularyService = VocabularyService(userId: userId);

     // 创建字幕服务
    final subtitleService = SubtitleService();

    // 创建阅读设置服务
    final settingsService = ReaderSettingsService();

    return ServiceProvider(
      videoService: videoService,
      vocabularyService: vocabularyService,
      subtitleService: subtitleService,   
      textService: TextService(),
      settingsService: settingsService,
      ttsService: ttsService,  
      showMessage: showMessage,
      hasInitializedUserWords: false, // 初始为未加载状态
      child: child,
    );
  }
}
