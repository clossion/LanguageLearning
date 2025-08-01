import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/library_service.dart';
import 'package:frontend/utils/word_utils.dart'; 

class WordInfo {
  final int id;
  final String text;
  int familiarity; // 0‑5
  String? userNote;

  WordInfo({
    required this.id,
    required this.text,
    required this.familiarity,
    this.userNote,
  });

  WordInfo copyWith({int? familiarity, String? userNote}) => WordInfo(
    id: id,
    text: text,
    familiarity: familiarity ?? this.familiarity,
    userNote: userNote ?? this.userNote,
  );
}

class SubtitleParagraph {
  final int index;
  final List<WordInfo> words;
  final Duration start;
  final Duration end;

  SubtitleParagraph({
    required this.index,
    required this.words,
    required this.start,
    required this.end,
  });
}

class ReaderState {
  final List<SubtitleParagraph> subs;
  final int currentPara;
  final bool sidebarOpen;
  final bool videoOpen;
  final Duration videoPosition;
  final bool isPageView;
  final String? videoPath; 
  final String? filePath; 
  final String? title; 
  final Offset videoOffset;     
  final bool videoControllerVisible;

  const ReaderState({
    required this.subs,
    this.currentPara = 0,
    this.sidebarOpen = false,
    this.videoOpen = false,
    this.videoPosition = Duration.zero,
    this.isPageView = true,
    this.videoPath,
    this.filePath,    
    this.title,
    this.videoOffset = const Offset(280, 120),
    this.videoControllerVisible = false,
  });

  get paragraphs => null;

  ReaderState copyWith({
    List<SubtitleParagraph>? subs,
    int? currentPara,
    bool? sidebarOpen,
    bool? videoOpen,
    Duration? videoPosition,
    bool? isPageView,
    String? videoPath,
    String? filePath, 
    String? title,  
    Offset? videoOffset,
    bool? videoControllerVisible,
  }) => ReaderState(
    subs: subs ?? this.subs,
    currentPara: currentPara ?? this.currentPara,
    sidebarOpen: sidebarOpen ?? this.sidebarOpen,
    videoOpen: videoOpen ?? this.videoOpen,
    videoPosition: videoPosition ?? this.videoPosition,
    isPageView: isPageView ?? this.isPageView,
    videoPath: videoPath ?? this.videoPath,
    filePath: filePath ?? this.filePath,
    title: title ?? this.title,
    videoOffset: videoOffset ?? this.videoOffset,
    videoControllerVisible: videoControllerVisible ?? this.videoControllerVisible,
  );
}

class ReaderController extends StateNotifier<ReaderState> {
  ReaderController() : super(const ReaderState(subs: []));

  /// ① 切文件时清空旧状态，防止 ListView 复用旧引用
  void reset() {
    // 保留侧边栏状态但重置其他所有状态
    final sidebarOpen = state.sidebarOpen;
    final filePath = state.filePath;   // 保留文件路径
    final title = state.title;  

    state = ReaderState(
      subs: [],
      currentPara: 0,
      sidebarOpen: sidebarOpen,
      videoOpen: false,
      isPageView: true,
      videoControllerVisible: false,
      videoPosition: Duration.zero,
      filePath: filePath,              // 保留文件路径
      title: title,       
    );
    
    // 重要: 清空手动更新缓存
    _lastManualUpdates.clear();
    
    debugPrint('ReaderState 已完全重置');
  }

  /// ② 当词库后来才更新，可随时重新套用熟悉度
  void applyFamiliarity(Map<String, int> famMap) {
    if (state.subs.isEmpty) return;
    
    debugPrint('应用词库熟悉度映射，词条数量: ${famMap.length}');

    final patched = state.subs.map((p) => SubtitleParagraph(
      index: p.index,
      start: p.start,
      end: p.end,
      words: p.words.map((w) {
        final cleanedText = cleanWord(w.text);
        
        // 检查是否是用户最近手动更新的单词
        if (_lastManualUpdates.containsKey(cleanedText)) {
          return w.copyWith(familiarity: _lastManualUpdates[cleanedText]!);
        } 
        // 否则使用词库中的熟悉度
        else if (famMap.containsKey(cleanedText)) {
          return w.copyWith(familiarity: famMap[cleanedText]!);
        } 
        // 词库中不存在的单词
        else {
          return w.copyWith(familiarity: -1);
        }
      }).toList(),
    )).toList();

    state = state.copyWith(subs: patched);
  }

  // ——— 加载字幕，并把数据库熟悉度套进去 ———
  Future<void> loadSubtitles(
    List<SubtitleParagraph> raw,
    Map<String, int> familiarityMap,
  ) async {
    // 先清空手动更新缓存，确保使用最新的词库数据
    _lastManualUpdates.clear();

    final patched = raw.map((p) => SubtitleParagraph(
      index: p.index,
      start: p.start,
      end: p.end,
      words: p.words.map((w) {
        final cleanedWord = cleanWord(w.text);
        int? familiarityLevel;
        
        if (familiarityMap.containsKey(cleanedWord)) {
          familiarityLevel = familiarityMap[cleanedWord];
        }
        
        return w.copyWith(
          familiarity: familiarityLevel ?? -1
        );
      }).toList(),
    )).toList();

    state = state.copyWith(subs: patched, currentPara: 0);
    
    // 不使用延迟，立即再次应用确保一致性
    applyFamiliarity(familiarityMap);
  }

  void nextPage(int itemsPerPage) {
    if (state.currentPara < state.subs.length - itemsPerPage) {
      state = state.copyWith(currentPara: state.currentPara + itemsPerPage);
    } else {
      // 如果剩余不足 itemsPerPage 段，则直接跳到最后一段开头
      state = state.copyWith(currentPara: state.subs.length - 1);
    }
  }

  void prevPage(int itemsPerPage) {
    if (state.currentPara >= itemsPerPage) {
      state = state.copyWith(currentPara: state.currentPara - itemsPerPage);
    } else {
      state = state.copyWith(currentPara: 0);
    }
  }

  // ——— 跳转到指定段落 ———
  void jumpToPara(int index) {
    if (index >= 0 && index < state.subs.length) {
      state = state.copyWith(currentPara: index);
    }
  }

  // ——— 更新熟悉度 ———
  void updateWordLevel(int wordId, int newLvl, {String? wordText}) {
    // 如果state.subs为空，直接返回避免操作空数据
    if (state.subs.isEmpty) return;

    // 1. 找到要更新的单词和其文本
    String? targetKey;
    bool foundExactMatch = false;
    
    // 如果提供了文本参数，尝试精确匹配ID和文本
    if (wordText != null) {
      final cleanedText = cleanWord(wordText);
      // 先尝试精确匹配
      for (var p in state.subs) {
        for (var w in p.words) {
          if (w.id == wordId && cleanWord(w.text) == cleanedText) {
            targetKey = cleanedText;
            foundExactMatch = true;
            break;
          }
        }
        if (foundExactMatch) break;
      }
    }
    
    // 如果没有找到精确匹配，退回到只按ID查找
    if (!foundExactMatch) {
      for (var p in state.subs) {
        for (var w in p.words) {
          if (w.id == wordId) {
            targetKey = cleanWord(w.text);
            break;
          }
        }
        if (targetKey != null) break;
      }
    }
    
    if (targetKey == null) return; // 未找到目标单词，无法更新
    
    // 2. 更新所有相同文本的单词
    final updatedSubs = state.subs.map((p) => SubtitleParagraph(
      index: p.index,
      start: p.start,
      end: p.end,
      words: p.words.map((w) => 
        cleanWord(w.text) == targetKey 
          ? w.copyWith(familiarity: newLvl) 
          : w,
      ).toList(),
    )).toList();
    
    // 3. 更新状态并添加防止冲突的记录
    state = state.copyWith(subs: updatedSubs);
    
    // 4. 确保此更新不会被其他自动更新覆盖
    _lastManualUpdates[targetKey] = newLvl;
  }

  // 添加一个字段记录最近手动更新的单词
  final Map<String, int> _lastManualUpdates = {};

  // ——— 切换视图模式 ———
  void toggleViewMode() {
    state = state.copyWith(isPageView: !state.isPageView);
  }

  // ——— UI 控制 ———
  void toggleSidebar() =>
      state = state.copyWith(sidebarOpen: !state.sidebarOpen);

  void toggleVideo() => state = state.copyWith(videoOpen: !state.videoOpen);

  void rememberVideoPos(Duration pos) =>
      state = state.copyWith(videoPosition: pos);

  Future<void> loadFileByPath(
    String filePath,
    String? type,
    String? title, ) async {
    try {
      // 如果是视频类型，保存视频路径但不显示组件
      final typeStr = type?.toString();
      if (typeStr == ResourceType.video.toString() ||
      typeStr == 'ResourceType.video') {
        // 保存视频路径，但不自动设置为打开状态
        state = state.copyWith(
          videoPath: filePath,
          videoOpen: false,          // 确保不自动打开视频窗口
          videoControllerVisible: false  // 确保不自动显示控制器
        );
      }

      // 表示文件已加载
      state = state.copyWith(currentPara: 0);
    } catch (e) {
      debugPrint('加载文件路径失败: $e');
    }
  }

  /// 拖动
  void moveVideo(Offset delta) =>
      state = state.copyWith(videoOffset: state.videoOffset + delta);
  
  /// 同步切换视频窗口与控制器
  void toggleVideoComponents() {
    if (!state.videoControllerVisible) {
      // 准备开启：先确认路径
      if (state.videoPath == null || state.videoPath!.isEmpty) {
        return;
      }
      
      // 路径就绪 → 打开窗口 + 控制器
      state = state.copyWith(
        videoControllerVisible: true,
        videoOpen: true,
      );
      
    } else {
      // 已经可见 → 保存当前位置，然后关闭窗口 + 控制器
      try {
        // 不在这里保存位置，而是通过按钮点击时保存
        state = state.copyWith(
          videoControllerVisible: false,
          videoOpen: false,
        );
      } catch (e) {
        debugPrint('关闭视频组件时发生错误: $e');
      }
    }
  }
}