import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'settings_fonts_bg.dart';
import 'package:frontend/services/reader_settings_service.dart';

// 状态：字体/背景设置对话框是否打开
final fontSettingsOpenProvider = StateProvider<bool>((ref) => false);

// ReaderSettings Provider
final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettingsService>((ref) {
  return ReaderSettingsNotifier();
});

class ReaderSettingsNotifier extends StateNotifier<ReaderSettingsService> {
  ReaderSettingsNotifier() : super(ReaderSettingsService()) {
    state.loadSettings();
  }

  /// 只剩 fontSize / backgroundColor / fontFamily / lineHeight 四项
  Future<void> updateSettings({
    double? fontSize,
    Color? backgroundColor,
    String? fontFamily,
    double? lineHeight,
  }) async {
    await state.updateAllSettings(
      fontSize: fontSize,
      backgroundColor: backgroundColor,
      fontFamily: fontFamily,
      lineHeight: lineHeight,
    );

    // 重新实例化以触发 UI 刷新
    final newState = ReaderSettingsService();
    await newState.loadSettings();
    state = newState;
  }
}

class ReaderTopBar extends ConsumerWidget {
  const ReaderTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerState = ref.watch(readerProvider);
    final settingsService = ref.watch(readerSettingsProvider);
    final isSettingsOpen = ref.watch(fontSettingsOpenProvider);

    // 计算页码 / 进度
    final itemsPerPage = ref.watch(itemsPerPageProvider);
    final int totalPages =
        readerState.subs.isEmpty ? 1 : (readerState.subs.length / itemsPerPage).ceil();
    final int currentPage =
        readerState.subs.isEmpty ? 0 : (readerState.currentPara / itemsPerPage).floor() + 1;
    final double progress = readerState.subs.isEmpty ? 0 : currentPage / totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 关闭按钮 ----------------------------------------------------------
          IconButton(
            icon: SvgPicture.asset('assets/icons/close.svg', width: 24, height: 24),
            tooltip: '关闭',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('确定要退出阅读页面吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);          // 先关对话框
                        Navigator.pushReplacementNamed(context, '/library');
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),

          // 进度条 + 页码 -------------------------------------------------------
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: Colors.blue.shade700,
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: Colors.blue.shade600,
                    overlayColor: Colors.blue.withOpacity(0.3),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: readerState.subs.isEmpty
                        ? 0
                        : readerState.currentPara / (readerState.subs.length - 1),
                    onChanged: readerState.subs.isEmpty
                        ? null
                        : (v) {
                            final itemsPerPage = ref.read(itemsPerPageProvider);
                            final totalPages = (readerState.subs.length / itemsPerPage).ceil();
                            final targetPage = (v * (totalPages - 1)).round();
                            final targetPara =
                                (targetPage * itemsPerPage).clamp(0, readerState.subs.length - 1);
                            ref.read(readerProvider.notifier).jumpToPara(targetPara);
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$currentPage / $totalPages',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 字体/背景设置按钮 ----------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: isSettingsOpen ? Colors.blue.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: IconButton(
              icon: const Icon(Icons.format_size),
              color: isSettingsOpen ? Colors.blue : null,
              tooltip: '字体背景设置',
              onPressed: () {
                ref.read(fontSettingsOpenProvider.notifier).state = true;

                showDialog(
                  context: context,
                  builder: (_) => FontSettingsDialog(
                    initialFontSize: settingsService.fontSize,
                    initialBackgroundColor: settingsService.backgroundColor,
                    lineHeight: settingsService.lineHeight,
                    onSave: (fontSize, backgroundColor, lineHeight) {
                      ref.read(readerSettingsProvider.notifier).updateSettings(
                        fontSize: fontSize,
                        backgroundColor: backgroundColor,
                        lineHeight: lineHeight,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('设置已保存并应用')),
                      );
                    },
                  ),
                ).then((_) {
                  ref.read(fontSettingsOpenProvider.notifier).state = false;
                });
              },
            ),
          ),

          // Sidebar 切换 --------------------------------------------------------
          IconButton(
            icon: SvgPicture.asset(
              readerState.sidebarOpen
                  ? 'assets/icons/sidebar-close.svg'
                  : 'assets/icons/sidebar-open.svg',
              width: 24,
              height: 24,
            ),
            tooltip: readerState.sidebarOpen ? '关闭侧边栏' : '打开侧边栏',
            onPressed: () => ref.read(readerProvider.notifier).toggleSidebar(),
          ),
        ],
      ),
    );
  }
}
