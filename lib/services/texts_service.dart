import 'dart:convert' show jsonEncode;
import 'package:http/http.dart' as http;
import '../utils/api_service.dart';
import '../pages/reader/controller/reader_state.dart';

class TextService {
  /// 加载并解析文本文件，返回段落列表
  Future<List<SubtitleParagraph>> loadAndParseText(String path) async {
    // ① 发送 load
    final loadRes = await http.post(
      Uri.parse('$API_BASE/texts/load'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'file_path': path}),
    );

    final loadData = decodeJson(loadRes);
    if (loadData['status'] != 'ok' || loadData['info'] == null) {
      throw '电子书信息加载失败';
    }
    final textId = loadData['info']['id'];

    // ② 获取内容
    final contentRes = await http.get(
      Uri.parse('$API_BASE/texts/content?text_id=$textId'),
    );

    final List<dynamic> paragraphs = decodeJson(contentRes);
    return _toParagraphs(paragraphs.cast<String>());
  }

  /// 纯文本 → 段落结构（与字幕相同格式）
  List<SubtitleParagraph> _toParagraphs(List<String> raws) {
    final List<SubtitleParagraph> subs = [];
    for (var i = 0; i < raws.length; i++) {
      // ① 处理连字符：在连字符右边添加空格
      String processedText = raws[i]
          .replaceAllMapped(RegExp(r'([—–-―])(\S)'), (match) {
            // 在连字符右边添加空格，避免与下个单词粘连
            return '${match.group(1)} ${match.group(2)}';
          })
          // ② 处理粘连的断句标点符号，在它们前面添加空格
          .replaceAllMapped(RegExp(r'(\w)([.!?]+)(\w)'), (match) {
            return '${match.group(1)} ${match.group(2)} ${match.group(3)}';
          })
          .replaceAllMapped(RegExp(r'(\w)([.!?]+)$'), (match) {
            return '${match.group(1)} ${match.group(2)}';
          });
      
      // ③ 然后按空格分词
      final rawWords = processedText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      
      // ④ 处理断句标点符号：将独立的标点符号合并到前一个词
      final List<String> words = [];
      for (int j = 0; j < rawWords.length; j++) {
        final word = rawWords[j];
        
        // 如果当前词只是断句标点符号，且前面有词，则合并到前一个词
        if (RegExp(r'^[.!?]+$').hasMatch(word) && words.isNotEmpty) {
          words[words.length - 1] += word;
        } else {
          words.add(word);
        }
      }

      subs.add(
        SubtitleParagraph(
          index: i,
          start: Duration.zero,
          end: Duration.zero,
          words: List.generate(
            words.length,
            (j) => WordInfo(
              id: i * 100 + j,
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