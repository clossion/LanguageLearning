import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/controller/reader_video_provider.dart';
import 'package:frontend/pages/reader/widgets/video_player_controller.dart';
import 'package:frontend/services/service_provider.dart';
import "package:frontend/utils/icon_button.dart";
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;
import 'reader_sidebar.dart';

class ReaderBottomBar extends ConsumerWidget {
  final String? filePath;
  final String? title;

  const ReaderBottomBar({
    super.key,
    this.filePath,
    this.title,
  });

  static const double _barHeight = kToolbarHeight + 10; // 72
  static const double _ctlWidth = 300;
  static const double _ctlHeight = 65;
  static const double _ctlPaddingL = 2;
  static const double _ctlPaddingB = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(readerProvider);
    final selId = ref.watch(selectedWordIdProvider);

    return Container(
      height: _barHeight,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          /// ─────────── 主操作区 ───────────
          Row(
            children: [
              /// ① 播放/关闭音频控制条 - 完全学习字幕页面的做法
              AppIconButton(
                icon: 'assets/icons/video-play.svg',
                active: st.videoControllerVisible,
                tooltip: st.videoControllerVisible ? '关闭音频' : '播放音频',
                onPressed: () {
                  if (st.videoControllerVisible) {
                    // 关闭时：暂停并保存位置
                    final player = ref.read(videoPlayerProvider);
                    player.pause();
                    ref.read(readerProvider.notifier).rememberVideoPos(player.state.position);
                  } else {
                    // 开启时：准备音频（异步进行，不阻塞UI）
                    _prepareAudioAndPlay(context, ref);
                  }
                  // 直接切换控制条状态
                  ref.read(readerProvider.notifier).toggleVideoComponents();
                },
              ),

              const Spacer(),

              /// ② 视图切换（页面 / 句子）
              AppIconButton(
                icon: st.isPageView
                    ? 'assets/icons/page-view.svg'
                    : 'assets/icons/sentence-view.svg',
                tooltip: st.isPageView ? '页面视图' : '句子视图',
                onPressed: () =>
                    ref.read(readerProvider.notifier).toggleViewMode(),
              ),

              const Spacer(),

              /// ③ 词库 / 返回
              AppIconButton(
                icon: 'assets/icons/vocabulary-icon.svg',
                active: selId != null,
                tooltip: selId != null ? '返回词库' : '打开词库',
                onPressed: () {
                  if (selId != null) {
                    ref.read(selectedWordIdProvider.notifier).state = null;
                  } else if (!st.sidebarOpen) {
                    ref.read(readerProvider.notifier).toggleSidebar();
                  }
                },
              ),
            ],
          ),

          /// ─────────── 复用视频控制条组件 ───────────
          if (st.videoControllerVisible)
            Positioned(
              left: _ctlPaddingL,
              bottom: _ctlPaddingB,
              width: _ctlWidth,
              height: _ctlHeight,
              child: const VideoControllerWidget(),
            ),
        ],
      ),
    );
  }

  /// 准备音频并自动播放（学习字幕页面：异步进行，不阻塞UI更新）
  Future<void> _prepareAudioAndPlay(BuildContext context, WidgetRef ref) async {
    if (filePath == null || title == null) {
      _showErrorMessage(context, '没有加载文件信息，无法生成音频');
      return;
    }
    
    try {
      final textFile = File(filePath!);
      final directory = textFile.parent.path;
      final basename = path.basenameWithoutExtension(textFile.path);
      final audioFilePath = path.join(directory, '$basename.mp3');
      
      final audioFile = File(audioFilePath);
      bool audioExists = await audioFile.exists();
      
      if (!audioExists) {
        _showLoadingDialog(context, '正在生成音频，请耐心等待...');
        
        if (!textFile.existsSync()) {
          Navigator.of(context).pop();
          _showErrorMessage(context, '无法读取文本文件');
          return;
        }
        
        const lang = 'en';
        final ttsService = ServiceProvider.of(context).ttsService;
        final success = await ttsService.generateAudioFile(
          filePath!,
          audioFilePath,
          lang: lang,
          speed: 1.0,
          gender: 'female'
        );
        
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        if (!success) {
          _showErrorMessage(context, '音频生成失败');
          return;
        }
        
        audioExists = true;
      }
      
      if (audioExists) {
        // 先设置 videoPath，确保 toggleVideoComponents 能正常工作
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        ref.read(readerProvider.notifier).state = ref.read(readerProvider).copyWith(
          videoPath: audioFilePath,
        );
        
        // 加载音频并自动播放（学习字幕页面的行为）
        final player = ref.read(videoPlayerProvider);
        await player.open(Media(audioFilePath));
        await player.play();  // 自动播放，控制条会立即显示暂停图标
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorMessage(context, '音频处理错误: $e');
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }
  
  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}