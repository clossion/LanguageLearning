import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/service_provider.dart';
import 'package:frontend/services/library_service.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/widgets/reader_content.dart';
import 'package:frontend/pages/reader/widgets/reader_sidebar.dart';
import 'package:frontend/pages/reader/widgets/reader_top_bar.dart';
import 'package:frontend/pages/reader/widgets/reader_bottom_text.dart';
import 'package:path/path.dart' as path; // 添加引入

class EbookReaderPage extends ConsumerStatefulWidget {
  final String userId;
  final String filePath; 
  final String? title;

  const EbookReaderPage({
    super.key,
    required this.userId,
    required this.filePath,
    this.title,
  });

  @override
  ConsumerState<EbookReaderPage> createState() => _EbookReaderPageState();
}

class _EbookReaderPageState extends ConsumerState<EbookReaderPage> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 异步启动加载
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEbookContent());
  }

  /// 通过后端服务加载电子书文本 → 构造SubtitleParagraph → 注入到ReaderState
  Future<void> _loadEbookContent() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. 先清空所有状态
      ref.read(readerProvider.notifier).reset();
      
      // 2. 确保词库完全加载
      final vocab = ServiceProvider.of(context).vocabularyService;
      await vocab.loadUserWords();  
      
      // 3. 等待一小段时间确保词库映射构建完毕
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 4. 加载文本内容
      final textService = ServiceProvider.of(context).textService;
      final paragraphs = await textService.loadAndParseText(widget.filePath);

      // 5. 先设置文件路径和标题
      ref.read(readerProvider.notifier).loadFileByPath(
        widget.filePath,
        ResourceType.ebook.toString(),
        widget.title ?? path.basenameWithoutExtension(widget.filePath),
      );
      
      // 6. 然后应用词库映射 (注意:不要在这里使用await)
      ref.read(readerProvider.notifier).loadSubtitles(
        paragraphs, 
        vocab.wordFamiliarityMap
      );
      
    } catch (e) {
      setState(() => _errorMessage = '电子书加载失败：$e');
    } finally {
      setState(() => _isLoading = false);
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
                  // 加载状态或错误提示
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  // 主内容
                  else
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
                ],
              ),
            ),
            
            // 添加底部栏
            ReaderBottomBar(
              filePath: widget.filePath,  // 直接从widget属性传递
              title: widget.title ?? path.basenameWithoutExtension(widget.filePath),
            ),
          ],
        ),
      ),
    );
  }
}