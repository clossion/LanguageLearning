import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/controller/reader_state.dart';
import 'content_screen.dart';  
import 'package:frontend/utils/word_utils.dart';  
import 'sidebar_words_list_view.dart';
import 'sidebar_word_detail_view.dart';

// 用于跟踪当前选中的单词ID（如果有）
final selectedWordIdProvider = StateProvider<int?>((ref) => null);

class ReaderSidebar extends ConsumerWidget {
  const ReaderSidebar({super.key});

  // 确保边框和阴影等效果正常
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerState = ref.watch(readerProvider);
    final selectedWordId = ref.watch(selectedWordIdProvider);

    // 找到选中的单词（如果有）
    WordInfo? selectedWord;
    if (selectedWordId != null) {
      selectedWord = _findSelectedWord(readerState, selectedWordId, ref);  
    }


    // 使用Material给侧边栏添加阴影和圆角边框
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        elevation: 8.0,
        shadowColor: Colors.black38,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            border: Border.all(color: Colors.grey.shade300, width: 1.0),
          ),
          // 根据是否有选中的单词显示不同的视图
          child: selectedWord != null
              ? SidebarWordDetailView(word: selectedWord)
              : SidebarVocabularyView(readerState: readerState),
        ),
      ),
    );
  }

  // 查找选中的单词 - 同时匹配ID和文本
  WordInfo? _findSelectedWord(ReaderState state, int wordId, WidgetRef ref) {
    // 获取当前选中的单词文本
    final wordText = ref.watch(contentSelectedWordTextProvider);
    
    // 先尝试同时匹配ID和文本
    for (var para in state.subs) {
      for (var word in para.words) {
        if (word.id == wordId && 
            (wordText == null || cleanWord(word.text) == cleanWord(wordText))) {
          return word;
        }
      }
    }
    
    // 如果找不到完全匹配，退而求其次只匹配ID
    if (wordText != null) {
      for (var para in state.subs) {
        for (var word in para.words) {
          if (word.id == wordId) {
            return word;
          }
        }
      }
    }
    
    return null;
  }
}
