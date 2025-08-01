import 'dart:async';
import 'dart:convert' show jsonEncode, jsonDecode, utf8;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/utils/word_utils.dart'; 
import '../utils/api_service.dart';

/// 词汇管理服务类，处理单词查询、记录和更新熟悉度等功能
class VocabularyService {
  // 用户ID
  final String? userId;
  // 状态更新回调
  final Function(VocabularyService)? onStateChanged;

  // —— 新增：查词序号，用来丢弃过期的请求 —— 
  int _lookupSeq = 0;

  // ===== 新增缓存与防抖 =====
  /// 单词查询结果缓存：key = cleanWord(word)，value = 后端返回的 info map
  final Map<String, Map<String, dynamic>> _lookupCache = {};
  /// 更新熟练度的防抖 Timer：key = cleanWord(word)
  final Map<String, Timer> _debounceTimers = {};
  // ========================

  // 单词熟悉度映射
  Map<String, int> wordFamiliarityMap = {};

  // 用户单词列表
  List<Map<String, dynamic>> userWords = [];

  // 当前选中的单词及其信息
  String selectedWord = '';
  String selectedOriginalWord = ''; // 存储原始单词（包含标点符号等）
  String selectedProcessedWord = ''; // 存储处理后的单词（去除标点符号）
  Map<String, dynamic>? selectedWordInfo;

  // 防止重复加载用户词库
  bool _isLoadingUserWords = false;
  // 缓存用户词库上次加载时间，避免频繁刷新
  DateTime? _lastUserWordsLoadTime;

  VocabularyService({required this.userId, this.onStateChanged});

  /// 加载用户词汇数据
  Future<void> loadUserWords() async {
    if (userId == null) return;

    // 防止重复加载 - 如果已在加载过程中，直接返回
    if (_isLoadingUserWords) return;

    // 如果上次加载时间在3秒内，避免频繁请求
    if (_lastUserWordsLoadTime != null) {
      final diff = DateTime.now().difference(_lastUserWordsLoadTime!);
      if (diff.inSeconds < 3) {
        return;
      }
    }

    try {
      _isLoadingUserWords = true;

      final response = await http.get(
        Uri.parse('$API_BASE/words?user_id=$userId&lang=en'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

        userWords = List<Map<String, dynamic>>.from(data);

        // 更新加载时间
        _lastUserWordsLoadTime = DateTime.now();

        // 创建查询表以快速检查熟悉度
        wordFamiliarityMap.clear(); // 先清空避免旧数据
        for (final wordData in userWords) {
          final String word = wordData['user_word'].toString().toLowerCase();
          final int level = wordData['familiarity'] ?? 0;
          wordFamiliarityMap[word] = level;
        }

        // 通知状态更新
        if (onStateChanged != null) {
          onStateChanged!(this);
        }
      }
    } catch (e) {
      debugPrint('获取用户词汇错误: $e');
    } finally {
      _isLoadingUserWords = false;
    }
  }

  /// 处理单词点击
  Future<void> handleWordClick(String word) async {
    final cleanedWord = cleanWord(word);

    // 存储原始形式和处理后的形式
    selectedOriginalWord = word;
    selectedProcessedWord = cleanedWord;
    selectedWord = cleanedWord;
    selectedWordInfo = null;

    // 查询单词
    await lookupWord(cleanedWord);

    // 通知状态更新 - 确保在查询完成后才通知，减少更新次数
    if (onStateChanged != null) {
      onStateChanged!(this);
    }

  }

  CaseMode caseMode = CaseMode.lower; 
  String getDisplayForm(String cleanedLower) =>
    applyCase(cleanedLower, caseMode);
  void setCaseMode(CaseMode mode) {
  if (caseMode == mode) return;
  caseMode = mode;
  _lookupCache.clear();
  onStateChanged?.call(this);
}


  /// 查询单词定义，尝试多种大小写形式
  Future<void> lookupWord(String word, {int level = 0}) async {
    final cleaned = cleanWord(word);
    final queryWord = getDisplayForm(cleaned); 
    if (cleaned.isEmpty || userId == null) return;

    // 序号自增，并捕获当前序号
    final thisSeq = ++_lookupSeq;

    // 1. 先本地库查（如有实现 _localDbQuery），否则可跳过这步
    // final local = await _localDbQuery(cleaned);
    // if (local != null) {
    //   if (thisSeq != _lookupSeq) return;
    //   selectedWordInfo = local;
    //   selectedWord     = cleaned;
    //   _lookupCache[cleaned] = local;
    //   onStateChanged?.call(this);
    //   return;
    // }

    // 2. 缓存命中
    if (_lookupCache.containsKey(cleaned)) {
      if (thisSeq != _lookupSeq) return;
      selectedWordInfo = _lookupCache[cleaned];
      selectedWord     = cleaned;
      onStateChanged?.call(this);
      return;
    }

    // 3. 网络查询
    final resp = await http.get(
      Uri.parse(
        '$API_BASE/translation/lookup?'
        'word=${Uri.encodeComponent(queryWord)}'
        '&user_id=$userId&lang=en&level=$level',
      ),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['translation'] != null) {
        data['translation'] = _formatTranslation(data['translation'].toString());
        if (data['examples'] != null) {
          data['examples'] = _formatExamples(data['examples'].toString());
        }
        if (thisSeq != _lookupSeq) return;
        selectedWordInfo = data;
        selectedWord     = queryWord.toLowerCase();
      }
    }

    // 4. 写缓存 & 通知（仍需检查是否过期）
    if (thisSeq == _lookupSeq && selectedWordInfo != null) {
      _lookupCache[cleaned] = selectedWordInfo!;
      onStateChanged?.call(this);
    }
  }

  /// 格式化翻译文本，改善中文显示效果
  String _formatTranslation(String text) {
    if (text.isEmpty) return text;

    // 移除多余空格
    String result = text.trim().replaceAll(RegExp(r'\s+'), ' ');

    // 词性标记映射 - 用于识别和替换
    final Map<String, String> posMap = {
      'n.': '名词：',
      'v.': '动词：',
      'adj.': '形容词：',
      'adv.': '副词：',
      'prep.': '介词：',
      'conj.': '连词：',
      'pron.': '代词：',
      'art.': '冠词：',
      'num.': '数词：',
      'vi.': '不及物动词：',
      'vt.': '及物动词：',
      'aux.': '助动词：',
      'int.': '感叹词：',
      'pl.': '复数：',
      'abbr.': '缩写：',
      'sing.': '单数：',
    };

    // 处理常见的格式问题 - 中英文间空格和标点符号
    result = result
        // 修复中英文之间的空格
        .replaceAllMapped(
          RegExp(r'([a-zA-Z])([\u4e00-\u9fa5])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'([\u4e00-\u9fa5])([a-zA-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        // 英文标点转中文标点
        .replaceAll(';', '；')
        .replaceAll(', ', '，')
        .replaceAll('?', '？')
        .replaceAll('!', '！')
        .replaceAll(':', '：')
        // 处理括号
        .replaceAll('(', '（')
        .replaceAll(')', '）');

    // 如果包含多个词性标记，使用更加结构化的格式
    bool hasMultiplePOS = false;

    // 检查是否存在多个词性标记
    for (final pos in posMap.keys) {
      if (result.contains(pos)) {
        hasMultiplePOS = true;
        break;
      }
    }

    // 如果存在多个词性，进行结构化处理
    if (hasMultiplePOS) {
      // 替换词性标记，并添加换行符
      for (final entry in posMap.entries) {
        final pos = entry.key;
        final posLabel = entry.value;
        result = result.replaceAll(pos, '\n$posLabel');
      }

      // 移除开头可能的多余换行符
      if (result.startsWith('\n')) {
        result = result.substring(1);
      }
    }

    return result;
  }

  /// 格式化例句文本
  String _formatExamples(String text) {
    if (text.isEmpty) return text;

    // 分割例句并重新格式化
    final examples = text.split('\n');
    final formattedExamples = <String>[];

    for (var example in examples) {
      if (example.trim().isEmpty) continue;

      // 处理常见的格式问题 - 中英文间空格和标点符号
      var formattedExample = example
          .trim()
          // 修复中英文之间的空格
          .replaceAllMapped(
            RegExp(r'([a-zA-Z])([\u4e00-\u9fa5])'),
            (match) => '${match.group(1)} ${match.group(2)}',
          )
          .replaceAllMapped(
            RegExp(r'([\u4e00-\u9fa5])([a-zA-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}',
          )
          // 英文标点转中文标点 (仅在中文上下文中)
          .replaceAll('?', '？')
          .replaceAll('!', '！')
          .replaceAll(':', '：')
          // 处理括号
          .replaceAll('(', '（')
          .replaceAll(')', '）');

      formattedExamples.add(formattedExample);
    }

    return formattedExamples.join('\n\n');
  }

  /// 更新单词熟练度
  Future<bool> updateWordLevel(String word, int level) async {
    final key = cleanWord(word);
    if (key.isEmpty || userId == null) return false;

    // —— 本地立即更新并通知 UI —— 
    wordFamiliarityMap[key] = level;
    final idx = userWords.indexWhere(
      (e) => e['user_word'].toString().toLowerCase() == key,
    );
    if (idx != -1) {
      userWords[idx]['familiarity'] = level;
    }
    onStateChanged?.call(this);

    // —— 防抖提交 —— 
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(const Duration(seconds: 1), () async {
      try {
        final resp = await http.post(
          Uri.parse('$API_BASE/words/familiarity'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'word': word,
            'level': level,
            'lang': 'en',
          }),
        );
        if (resp.statusCode != 200) {
          debugPrint('防抖提交失败：$word → $level');
        }
      } catch (e) {
        debugPrint('防抖提交异常：$e');
      }
    });

    return true;
  }

  /// 生成查询变体的方法（可复用）
  List<String> _generateVariants(String cleanedWord) {
    if (cleanedWord.isEmpty) return [];
    final lowercase = cleanedWord.toLowerCase();
    final capitalized = lowercase[0].toUpperCase() + lowercase.substring(1);
    return cleanedWord == lowercase
        ? [lowercase, capitalized]
        : [cleanedWord, lowercase];
  }

  /// 保存用户自定义单词释义
  Future<void> saveUserMeaning(String word, String meaning,
       {bool reload = false}) async {
    final response = await http.post(
      Uri.parse('$API_BASE/words/meaning'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'word': word,
        'meaning': meaning,
        'lang': 'en',
      }),
    );
    if (response.statusCode == 200 && reload) {
      await loadUserWords(); 
      if (onStateChanged != null) {
        onStateChanged!(this);
      }// 保存成功后刷新用户词库
    }
  }

  /// 仅更新内存，不访问网络
  void setMeaningLocal(String word, String meaning) {
    final idx = userWords.indexWhere(
        (e) => e['user_word'].toString().toLowerCase() == word.toLowerCase());
    if (idx == -1) {
      userWords.add({
        'user_word': word,
        'meaning': meaning,
        'familiarity': 0,
        'dictionary_word': word,
      });
    } else {
      userWords[idx]['meaning'] = meaning;
    }
    if (onStateChanged != null) onStateChanged!(this); // 通知 UI
  }

  /// 批量获取单词翻译
  Future<Map<String, String>> batchGetTranslations(List<String> words) async {
    if (words.isEmpty || userId == null) return {};
    Map<String, String> translations = {};

    try {
      // 使用新的批量查询API端点
      final response = await http.post(
        Uri.parse('$API_BASE/translation/batch_lookup?user_id=$userId&lang=en'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(words),
      );

      if (response.statusCode == 200) {
        // 解析返回的批量单词信息
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        // 提取每个单词的翻译
        for (String word in words) {
          if (data.containsKey(word) && data[word] != null) {
            final wordData = data[word];
            if (wordData.containsKey('translation') &&
                wordData['translation'] != null) {
              translations[word] = wordData['translation'].toString();
            }
          }
        }
      } else {

        // 如果批量API失败，回退到使用用户词库数据
        if (userWords.isNotEmpty) {
          for (final wordData in userWords) {
            if (wordData['user_word'] != null &&
                wordData['meaning'] != null &&
                words.contains(wordData['user_word'])) {
              translations[wordData['user_word']] =
                  wordData['meaning'];
            }
          }
        }
      }
    } catch (e) {

      // 发生错误时，尝试从缓存中获取
      if (userWords.isNotEmpty) {
        for (final wordData in userWords) {
          if (wordData['user_word'] != null &&
              wordData['meaning'] != null &&
              words.contains(wordData['user_word'])) {
            translations[wordData['user_word']] = wordData['meaning'];
          }
        }
      }
    }

    return translations;
  }

  /// 强制从数据库刷新单词熟悉度映射
  Future<void> refreshWordFamiliarityMap() async {
    // 清空旧映射
    wordFamiliarityMap.clear();
    
    // 重新从数据库加载最新数据
    await loadUserWords();
    
    debugPrint('词库熟悉度映射已刷新，大小: ${wordFamiliarityMap.length}');
  }

  /// 批量获取词典单词形式（去除标点符号等，返回标准形式）
  Future<Map<String, String>> batchGetDictionaryForms(
    List<String> words,
  ) async {
    if (words.isEmpty || userId == null) return {};
    Map<String, String> dictionaryForms = {};

    try {
      // 优先使用已有的单词数据
      if (userWords.isNotEmpty) {
        for (final wordData in userWords) {
          if (wordData['user_word'] != null &&
              wordData['dictionary_word'] != null &&
              words.contains(wordData['user_word'])) {
            dictionaryForms[wordData['user_word']] =
                wordData['dictionary_word'];
          }
        }
      }

      // 找出缺少词典形式的单词
      List<String> missingWords =
          words.where((word) => !dictionaryForms.containsKey(word)).toList();

      // 如果还有未获取到词典形式的单词，批量请求
      if (missingWords.isNotEmpty) {
        // 只处理前10个单词，避免大量请求
        final limit = missingWords.length > 10 ? 10 : missingWords.length;

        // 逐个请求单词词典形式
        for (int i = 0; i < limit; i++) {
          final word = missingWords[i];
          // 只尝试一次，减少API调用
          final response = await http.get(
            Uri.parse(
              '$API_BASE/translation/lookup?word=${Uri.encodeComponent(word)}&user_id=$userId&lang=en',
            ),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data != null && data['word'] != null) {
              // 词典返回的标准单词形式
              dictionaryForms[word] = data['word'];
            } else {
              dictionaryForms[word] = word;
            }
          } else {
            dictionaryForms[word] = word;
          }
        }
      }
    } catch (e) {
      debugPrint('批量获取词典单词形式错误: $e');
    }

    return dictionaryForms;
  }


  /// 请求单个单词的释义
  Future<Map<String, dynamic>?> fetchSingleMeaning(String word) async {
  if (userId == null || word.isEmpty) return null;
  final key      = cleanWord(word);
  final display  = getDisplayForm(key);
  final response = await http.get(Uri.parse(
      '$API_BASE/words/meaning?user_id=$userId&word=$display&lang=en'));

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data;
    }
    return null;
  }

  /// 批量把当前页面用户库里没有的词，标记为 0 并插入到用户词表
  void addMissingWords(List<String> rawWords) {
    // 打印收到的列表
    //debugPrint('addMissingWords received: $rawWords');

    for (var w in rawWords) {
      final key = cleanWord(w);
      if (!wordFamiliarityMap.containsKey(key)) {
        //debugPrint('  ▶ will add missing: $key');
        updateWordLevel(key, 0);
      } else {
        //debugPrint('  ✕ already exists: $key');
      }
    }
  }
}
