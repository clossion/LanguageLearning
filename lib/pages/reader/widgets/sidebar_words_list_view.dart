import 'package:frontend/pages/reader/controller/reader_word_click.dart';
import 'reader_sidebar.dart';
import 'package:frontend/utils/word_utils.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/service_provider.dart';
import 'package:frontend/pages/reader/controller/reader_state.dart';

class SidebarVocabularyView extends ConsumerStatefulWidget {
  final ReaderState readerState;

  const SidebarVocabularyView({super.key, required this.readerState});

  @override
  ConsumerState<SidebarVocabularyView> createState() => _SidebarVocabularyViewState();
}

class _SidebarVocabularyViewState extends ConsumerState<SidebarVocabularyView> {
  final Map<String, String> _meanings = {};
  final Map<String, String> _dictionaryWords = {};
  bool _isLoading = false;
  // 移除 _selectedIndex，改用 selectedWordIdProvider

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserMeanings();
  }

  Future<void> _loadUserMeanings() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final displayWords = _getDisplayWords();
      final vocab = ServiceProvider.of(context).vocabularyService;
      if (vocab.userWords.isEmpty) {
        await vocab.loadUserWords();
      }

      Map<String, String> meanings = {};
      Map<String, String> dictionaryForms = {};
      Map<String, String> debugInfo = {};

      for (var word in displayWords) {
        final cleanedWord = cleanWord(word.text);
        var found = false;
        
        // 先尝试精确匹配
        for (var entry in vocab.userWords) {
          final userWord = cleanWord(entry['user_word'].toString());
          if (userWord == cleanedWord) {
            if (entry['meaning'] != null) {
              meanings[cleanedWord] = entry['meaning'];  // 使用cleanedWord作为键
            }
            if (entry['dictionary_word'] != null) {
              dictionaryForms[cleanedWord] = entry['dictionary_word'];  // 使用cleanedWord作为键
            }
            found = true;
            break;
          }
        }
        
        // 如果没找到，添加调试信息
        if (!found) {
          debugInfo[cleanedWord] = '找不到匹配: "$cleanedWord"';  // 使用cleanedWord作为键
          //debugPrint('词汇查询失败: "${word.text}" (清理后: "$cleanedWord") 在用户词库中未找到');
        }
      }

      if (mounted) {
        setState(() {
          _meanings.addAll(meanings);
          _dictionaryWords.addAll(dictionaryForms);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载释义出错: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 修改后的方法，只返回当前文本中的单词
  List<WordInfo> _getDisplayWords() {
    final currentTextWords = <String, WordInfo>{};
    
    // 1. 从当前文本中收集所有单词
    for (var para in widget.readerState.subs) {
      for (var word in para.words) {
        // 只关注熟悉度为1-4的单词
        if (word.familiarity >= 1) {
          // 用单词的小写形式作为key来去重
          final key = cleanWord(word.text);
          if (!currentTextWords.containsKey(key)) {
            currentTextWords[key] = word;
          }
        }
      }
    }
    
    // 2. 转换为列表并排序
    final list = currentTextWords.values.toList();
    list.sort((a, b) => a.familiarity.compareTo(b.familiarity));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final words = _getDisplayWords();

    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                const Text('本文生词', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: words.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.book, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          '词库中暂无单词\n点击文本中的单词将其添加到词库',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: words.length,
                    itemBuilder: (context, index) {
                      final word = words[index];
                      return _buildWordCard(context, word, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(BuildContext context, WordInfo word, int index) {
    final colors = {
      1: Colors.amber.shade500,
      2: Colors.amber.shade300,
      3: Colors.amber.shade100,
      4: Colors.grey.shade200,
      5: Colors.greenAccent.shade100,
    };
    final color = colors[word.familiarity] ?? Colors.grey[200];

    final cleanedText = cleanWord(word.text);
    final meaning = _meanings[cleanedText] ?? '（无含义 - 请检查大小写或标点符号）';
    // 修改这里，使用清理后的文本作为备选
    final dictionaryWord = _dictionaryWords[cleanedText] ?? cleanedText;
    
    // 使用 selectedWordIdProvider 来判断是否选中，而不是本地的 _selectedIndex
    final selectedWordId = ref.watch(selectedWordIdProvider);
    final isSelected = selectedWordId == word.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (isSelected)
            DottedBorder(
              color: Colors.blue,
              strokeWidth: 1.5,
              borderType: BorderType.RRect,
              radius: const Radius.circular(8),
              padding: EdgeInsets.zero,
              dashPattern: const [6, 3],
              child: const SizedBox.expand(),
            ),
          InkWell(
            onTap: () {
              // 移除复杂的本地状态管理，直接使用公共方法
              WordClickHandler.handleWordSelection(context, ref, word);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${word.familiarity}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: word.familiarity < 3 ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dictionaryWord, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          meaning,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}