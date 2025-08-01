import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reader_state.dart';

final readerProvider = StateNotifierProvider<ReaderController, ReaderState>((
  ref,
) {
  return ReaderController();
});

// 添加这个 Provider 到文件中
final itemsPerPageProvider = StateProvider<int>((ref) => 1); // 默认值为1

/// 扩展 WidgetRef 为阅读器提供刷新功能
extension ReaderRefreshExtension on WidgetRef {
  /// 强制刷新整个阅读界面的内容，特别是更新单词背景颜色
  void refreshReaderContent() {
    // 直接调用 Controller 的刷新接口
    read(readerProvider.notifier).reset();
  }
}
