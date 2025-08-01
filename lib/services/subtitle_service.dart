import 'dart:convert' show jsonEncode;
import 'package:frontend/utils/word_utils.dart';
import 'package:http/http.dart' as http;
import '../utils/api_service.dart';
import '../pages/reader/controller/reader_state.dart';

class _WordIdGenerator {
  int _currentId = 0;
  final Map<String, int> _wordIdMap = {};
  
  void reset() {
    _currentId = 0;
    _wordIdMap.clear();
  }
  
  int getIdForWord(String word) {
    final cleanedWord = cleanWord(word);
    if (_wordIdMap.containsKey(cleanedWord)) {
      return _wordIdMap[cleanedWord]!;
    }
    final newId = _currentId++;
    _wordIdMap[cleanedWord] = newId;
    return newId;
  }
}

class SubtitleService {
  final _idGenerator = _WordIdGenerator();
  
  Future<List<SubtitleParagraph>> loadAndParse(String path) async {
    _idGenerator.reset();

    final res = await http.post(
      Uri.parse('$API_BASE/subtitles/load'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'file_path': path}),
    );

    final data = decodeJson(res);
    if (data['status'] != 'loaded' || data['paragraphs'] == null) {
      throw '字幕加载失败';
    }
    return _toParagraphs(List<String>.from(data['paragraphs']));
  }

  /// 纯文本 → 段落结构
  List<SubtitleParagraph> _toParagraphs(List<String> raws) {
    final List<SubtitleParagraph> subs = [];
    for (var i = 0; i < raws.length; i++) {
      // 处理连字符：在连字符右边添加空格
      String processedText = raws[i]
          .replaceAllMapped(RegExp(r'([—–-―])(\S)'), (match) {
            // 在连字符右边添加空格，避免与下个单词粘连
            return '${match.group(1)} ${match.group(2)}';
          });
      
      final words = processedText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      subs.add(
        SubtitleParagraph(
          index: i,
          start: Duration.zero,
          end: Duration.zero,
          words: List.generate(
            words.length,
            (j) => WordInfo(
              id: _idGenerator.getIdForWord(words[j]),
              text: words[j],
              familiarity: 0,
            ),
          ),
        ),
      );
    }
    return subs;
  }
}