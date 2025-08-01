import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/utils/word_utils.dart'; // ← 确保导入 cleanWord
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/services/service_provider.dart';
import 'content_screen.dart';

class ReaderContent extends ConsumerWidget {
  const ReaderContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerState = ref.watch(readerProvider);
    final itemsPerPage = ref.watch(itemsPerPageProvider);
    final controller = ref.read(readerProvider.notifier); // ← Controller
    final vocabService = ServiceProvider.of(context).vocabularyService;

    // 侧边栏宽度常量
    const double sidebarWidth = 300.0;

    // ① 计算本页要显示的段落区间
    final startIdx = readerState.currentPara;
    final endIdx = min(startIdx + itemsPerPage, readerState.subs.length);

    // ② 扁平化收集这几段所有单词文本 + id
    final pageEntries = <MapEntry<String, int>>[];
    for (int i = startIdx; i < endIdx; i++) {
      for (var wi in readerState.subs[i].words) {
        pageEntries.add(MapEntry(wi.text, wi.id));
      }
    }
    // 只要文本列表给子组件
    final pageWords = pageEntries.map((e) => e.key).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 1. 固定位置的上一页按钮
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 48,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed:
                      readerState.currentPara > 0
                          ? () => controller.prevPage(itemsPerPage)
                          : null,
                  tooltip: '上一页',
                ),
              ),
            ),

            // 2. 内容区域 - 居中且随sidebar移动
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              // 左侧空间：
              // - sidebar关闭时，左侧预留按钮空间 + 半个sidebar宽度
              // - sidebar打开时，仅预留按钮空间
              left: readerState.sidebarOpen ? 48 : (48 + sidebarWidth / 2),
              // 右侧空间：
              // - sidebar关闭时，预留按钮空间 + 半个sidebar宽度
              // - sidebar打开时，预留按钮空间 + 完整sidebar宽度
              right:
                  readerState.sidebarOpen
                      ? (sidebarWidth + 48)
                      : (48 + sidebarWidth / 2),
              top: 0,
              bottom: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SubtitleWidget(pageWords: pageWords),
                ),
              ),
            ),
             // 3. 下一页按钮 - 使用AnimatedPositioned
             AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              right: readerState.sidebarOpen ? sidebarWidth : 0,
              top: 0,
              bottom: 0,
              width: 48,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                 onPressed:
                      readerState.subs.isNotEmpty &&
                              readerState.currentPara <
                                  readerState.subs.length - 1
                          ? () async {
                              // 1) 标记当前页所有单词并等待操作完成
                              final wordsLower = {
                                for (var w in pageWords) cleanWord(w),
                              }.toList();
                              vocabService.addMissingWords(wordsLower);
                              
                              // 2) 同步当前页面单词熟悉度
                              final famMap = vocabService.wordFamiliarityMap;
                              for (var entry in pageEntries) {
                                final word = cleanWord(entry.key);
                                final lvl = famMap[word];
                                
                                if (lvl != null) {
                                  // 获取当前单词的实际熟悉度状态
                                  int? currentLevel;
                                  for (int i = startIdx; i < endIdx; i++) {
                                    for (var w in readerState.subs[i].words) {
                                      if (w.id == entry.value) {
                                        currentLevel = w.familiarity;
                                        break;
                                      }
                                    }
                                    if (currentLevel != null) break;
                                  }
                                  
                                  // 只在需要更新时更新
                                  if (currentLevel == null || currentLevel != lvl) {
                                    controller.updateWordLevel(entry.value, lvl, wordText: entry.key);
                                  }
                                }
                              }
                              
                              // 3) 计算下一页范围并预加载单词熟悉度
                              final nextStartIdx = startIdx + itemsPerPage;
                              final nextEndIdx = min(nextStartIdx + itemsPerPage, readerState.subs.length);
                              
                              if (nextStartIdx < readerState.subs.length) {
                                for (int i = nextStartIdx; i < nextEndIdx; i++) {
                                  for (var word in readerState.subs[i].words) {
                                    final cleanedWord = cleanWord(word.text);
                                    if (famMap.containsKey(cleanedWord)) {
                                      // 强制应用下一页单词的熟悉度
                                      controller.updateWordLevel(
                                        word.id, 
                                        famMap[cleanedWord]!, 
                                        wordText: word.text
                                      );
                                    }
                                  }
                                }
                              }
                              
                              // 4) 最后才执行翻页操作
                              controller.nextPage(itemsPerPage);
                            }
                          : null,
                  tooltip: '下一页',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}