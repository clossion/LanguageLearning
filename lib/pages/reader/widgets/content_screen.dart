import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/utils/word_utils.dart';
import 'package:frontend/services/service_provider.dart';
import 'package:frontend/services/reader_settings_service.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/controller/reader_state.dart';
import 'package:frontend/pages/reader/widgets/reader_top_bar.dart';
import 'package:frontend/pages/reader/controller/reader_word_click.dart';

const double kRunSpacing = 4;       // 行与行之间的 Wrap 间距
const double paragraphGap = 8;      // 段落之间的外边距


// 创建一个状态提供者来存储当前选中的单词ID
final contentSelectedWordProvider = StateProvider<int?>((ref) => null);
// 增加一个状态提供者来存储当前选中的单词文本
final contentSelectedWordTextProvider = StateProvider<String?>((ref) => null);

class SubtitleWidget extends ConsumerWidget {

  final List<String> pageWords;
  const SubtitleWidget({super.key, required this.pageWords});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(readerProvider);
    final settings = ref.watch(readerSettingsProvider);

    // 监听单词选择状态
    ref.watch(contentSelectedWordProvider);

    if (st.subs.isEmpty) {
      return const Center(child: Text('暂无字幕，先导入文件吧！'));
    }

    // 页面视图下显示多个段落，句子视图下只显示当前段落
    if (st.isPageView) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // 计算可用高度（减去安全边距）
          double availableHeight = constraints.maxHeight - 50;
          double availableWidth = constraints.maxWidth;

          double fontSize = settings.fontSize;
          double estimatedLineHeight =
              fontSize * settings.lineHeight  + kRunSpacing;

          // 更准确估算每段落所需行数
          int startIdx = st.currentPara;
          int estimatedTotalLines = 0;
          int paragraphCount = 0;

          // 尝试估算能放下多少段落
          for (int i = startIdx; i < st.subs.length; i++) {
            // 估算当前段落需要的行数
            int estWordCount = st.subs[i].words.length;
            // 每行大约能放置的字符数 (假设每个单词平均5个字符加空格)
            int charsPerLine = (availableWidth / (fontSize * 0.6)).floor();
            int wordsPerLine = (charsPerLine / 6).floor();

            // 当前段落估计需要的行数（至少1行）
            int paragraphLines = (estWordCount / wordsPerLine).ceil();
            if (paragraphLines < 1) paragraphLines = 1;

            // 累加行数和段落数
            int newTotalLines = estimatedTotalLines + paragraphLines;
            double estHeight =
                (newTotalLines * estimatedLineHeight) +
                ((paragraphCount + 1) * paragraphGap);

            // 如果加上这段后超出可用高度，就停止累加
            if (estHeight > availableHeight && paragraphCount > 0) {
              break;
            }

            estimatedTotalLines = newTotalLines;
            paragraphCount++;
          }

          // 确保至少显示一个段落
          if (paragraphCount < 1) paragraphCount = 1;

          // 仅当 paragraphCount 发生变化时再更新 itemsPerPageProvider，避免每次 build 都触发
          final prevCount = ref.watch(itemsPerPageProvider);
          if (prevCount != paragraphCount) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(itemsPerPageProvider.notifier).state = paragraphCount;
            });
          }

          // 决定当前页应显示的段落范围
          int endIdx = startIdx + paragraphCount;
          if (endIdx > st.subs.length) endIdx = st.subs.length;

          // 构建正好容纳 itemsPerPage 个段落的列表
          return Container(
            color: Colors.transparent,
            width: double.infinity,
            child: ListView.builder(
              itemCount: endIdx - startIdx,
              physics: const BouncingScrollPhysics(), 
              //physics: const NeverScrollableScrollPhysics(), // 👈 禁止滚动
              itemBuilder: (context, index) {
                int realIdx = startIdx + index;
                return buildParagraph(st.subs[realIdx], settings, ref);
              },
            ),
          );
        },
      );
    } else {
      // 句子视图模式下，itemsPerPage 固定为 1
      if (ref.watch(itemsPerPageProvider) != 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(itemsPerPageProvider.notifier).state = 1;
        });
      }

      // 句子视图：只显示当前段落
      final para = st.subs[st.currentPara];
      // 确保句子视图也占满整个区域
      return Container(
        alignment: Alignment.center,
        color: settings.backgroundColor,
        // 去掉高度限制，确保容器扩展到可用空间
        width: double.infinity,
        child: buildSentenceView(para, settings, ref),
      );
    }
  }

  // 处理单词点击，尝试多种大小写形式进行匹配
  void _handleWordClick(BuildContext context, WidgetRef ref, WordInfo word) {
    if (word.familiarity == -1) {
      final vocab = ServiceProvider.of(context).vocabularyService;
      final cleaned = cleanWord(word.text);

      // UI 先行更新（整页所有同形单词都会跟着变黄）
      ref.read(readerProvider.notifier).updateWordLevel(
        word.id, 
        1, 
        wordText: word.text
      );

      // 后端写入（带 1 秒防抖，已在 VocabularyService 里实现）
      vocab.updateWordLevel(cleaned, 1);
    }

    // 完全使用公共方法，移除重复的状态设置
    WordClickHandler.handleWordSelection(context, ref, word);
  }

  // 构建一个段落
  Widget buildParagraph(
    SubtitleParagraph para,
    ReaderSettingsService settings,
    WidgetRef ref,
  ) {
    // 获取当前选中的单词ID和文本
    final selectedWordId = ref.watch(contentSelectedWordProvider);
    final selectedWordText = ref.watch(contentSelectedWordTextProvider); // 添加这行


    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 4,
        runSpacing: kRunSpacing,
        children:
            para.words.map((w) {
              Color bg = getWordBackgroundColor(w);

              // 检查当前单词是否被选中
              final isSelected = selectedWordId == w.id &&
                (selectedWordText == null || cleanWord(selectedWordText) == cleanWord(w.text));

              // 使用 InkWell 替代 GestureDetector 以获得更好的点击效果
              return Builder(
                builder:
                    (builderContext) => InkWell(
                      // 使用 builderContext 而不是 context
                      onTap: () => _handleWordClick(builderContext, ref, w),
                      borderRadius: BorderRadius.circular(4),
                      splashColor: Colors.blue.withOpacity(0.3),
                      highlightColor: Colors.blue.withOpacity(0.1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(4), // 圆角边框
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.blue
                                    : (w.familiarity == 4
                                        ? Colors.black
                                        : Colors.transparent),
                            width: isSelected ? 1.5 : 1,
                            style: BorderStyle.solid, // 使用solid替代可能存在的dashed
                          ),
                          // 选中效果增强
                          // boxShadow:
                          //     isSelected
                          //         ? [
                          //           BoxShadow(
                          //             color: Colors.blue.withOpacity(0.3),
                          //             blurRadius: 4,
                          //             spreadRadius: 1,
                          //           ),
                          //         ]
                          //         : null,
                        ),
                        child: Text(
                          w.text,
                          style: TextStyle(
                            fontSize: settings.fontSize,
                            fontFamily: settings.fontFamily,
                            height:settings.lineHeight,
                            color:
                                settings.backgroundColor == Colors.black
                                    ? Colors.white
                                    : Colors.black,
                            // 选中单词时加粗显示
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
              );
            }).toList(),
      ),
    );
  }

  // 句子视图 - 显示当前句子
  Widget buildSentenceView(
    SubtitleParagraph para,
    ReaderSettingsService settings,
    WidgetRef ref,
  ) {
    // 将所有单词合并为一句
    final sentence = para.words.map((w) => w.text).join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        sentence,
        style: TextStyle(
          fontSize: settings.fontSize + 8,
          fontFamily: settings.fontFamily,
          height: settings.lineHeight,
          color:
              settings.backgroundColor == Colors.black
                  ? Colors.white
                  : Colors.black,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // 获取单词背景色
  Color getWordBackgroundColor(WordInfo w) {
    // 根据熟悉度设置背景色
    switch (w.familiarity) {
      case 1:
        return Colors.amber.shade500; // 不认识
      case 2:
        return Colors.amber.shade300; // 模糊
      case 3:
        return Colors.amber.shade100; // 有印象
      case 4:
        return Colors.transparent; // 认识，无背景色
      case 5:
        return Colors.transparent; // 已掌握，无背景色
      case 0:
        return Colors.transparent; // 未标记，无背景色
      case -1: // -1表示词库中不存在的词
        return Colors.blue.shade100; // 蓝色背景，表示未添加到词库的新词
      default:
        return Colors.transparent; // 默认无背景色
    }
  }
}
