import 'widgets/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/service_provider.dart';
import 'package:frontend/services/library_service.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/controller/reader_state.dart';
import 'package:frontend/pages/reader/widgets/reader_bottom_subtitles.dart';
import 'package:frontend/pages/reader/widgets/reader_content.dart';
import 'package:frontend/pages/reader/widgets/reader_sidebar.dart';
import 'package:frontend/pages/reader/widgets/reader_top_bar.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String userId;
  final String? subtitlePath;
  final String? filePath;
  final String? type;
  final String? title;

  // 构造函数
  const ReaderPage({
    super.key,
    required this.userId,
    this.subtitlePath,
    this.filePath,
    this.type,
    this.title,
  });

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  @override
  void initState() {
    super.initState();
    // 异步启动加载
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResources());
  }

  Future<void> _loadResources() async {
  try {
    // 1. 先清空所有状态
    ref.read(readerProvider.notifier).reset();

    // 2. 确保词库完全加载
    final vocab = ServiceProvider.of(context).vocabularyService;
    if (vocab.userWords.isEmpty) {
      await vocab.loadUserWords();
      // 等待词库映射构建完成
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // 可以添加额外检查确保词库已加载
    debugPrint('词库加载完成，词条数量: ${vocab.userWords.length}');
    debugPrint('词库熟悉度映射大小: ${vocab.wordFamiliarityMap.length}');
    
    // 3. 等待一小段时间确保词库映射构建完毕
    await Future.delayed(Duration(milliseconds: 100));
    
    // 4. 再加载字幕和应用匹配
    if (widget.subtitlePath != null) {
      final subs = await ServiceProvider.of(context)
        .subtitleService
        .loadAndParse(widget.subtitlePath!);
        
      // 打印词库映射状态
      debugPrint('应用熟悉度映射，词典大小: ${vocab.wordFamiliarityMap.length}');
      
      await ref.read(readerProvider.notifier).loadSubtitles(
        subs.cast<SubtitleParagraph>(),
        vocab.wordFamiliarityMap,
      );
    }
    
    // 5. 最后加载视频路径
    if (widget.filePath != null) {
      ref.read(readerProvider.notifier).loadFileByPath(
        widget.filePath!,
        ResourceType.video.toString(),
        widget.title,
      );
    }
  } catch (e) {
    // 错误处理
  }
}

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerProvider);
    final settings = ref.watch(readerSettingsProvider);

    return Scaffold(
      body: Container(
        color: settings.backgroundColor,
        child: Column(
          children: [
            // 顶层布局 (固定不变)
            const ReaderTopBar(),

            // 中间内容区域 (包含侧边栏)
            Expanded(
              child: Stack(
                children: [
                  // 主内容
                  const ReaderContent(),

                  // 侧边栏 (使用动画控制显示/隐藏)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    right: readerState.sidebarOpen ? 0 : -300,
                    top: 0,
                    bottom: 0,
                    width: 300,
                    child: const ReaderSidebar(),
                  ),

                  // 视频播放窗口 - 当视频打开时显示
                  if (readerState.videoOpen)
                    const Center(child: VideoPlayerWidget()),
                ],
              ),
            ),

            // 底层布局 (固定不变)
            const ReaderBottomBar(),
          ],
        ),
      ),
    );
  }
}
