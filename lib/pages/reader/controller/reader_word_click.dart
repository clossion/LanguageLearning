import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/widgets/content_screen.dart';
import 'package:frontend/pages/reader/widgets/reader_sidebar.dart';
import 'package:frontend/pages/reader/controller/reader_state.dart';

class WordClickHandler {
  /// 统一的单词点击处理逻辑
  /// 复用 content_screen.dart 中的逻辑
  static void handleWordSelection(BuildContext context, WidgetRef ref, WordInfo word) {
    // 设置完整的状态链，确保与 content 点击行为一致
    ref.read(selectedWordIdProvider.notifier).state = word.id;
    ref.read(contentSelectedWordProvider.notifier).state = word.id;
    ref.read(contentSelectedWordTextProvider.notifier).state = word.text;
    
    // 如果侧边栏关闭，则打开它
    if (!ref.read(readerProvider).sidebarOpen) {
      ref.read(readerProvider.notifier).toggleSidebar();
    }
  }
}