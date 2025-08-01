import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/controller/reader_video_provider.dart';
import 'package:frontend/pages/reader/widgets/video_player_controller.dart';
import "package:frontend/utils/icon_button.dart";
import 'reader_sidebar.dart';

class ReaderBottomBar extends ConsumerWidget {
  const ReaderBottomBar({super.key});

  static const double _barHeight   = kToolbarHeight+10; // 72
  static const double _ctlWidth    = 300;
  static const double _ctlHeight   = 65;
  static const double _ctlPaddingL = 2;
  static const double _ctlPaddingB = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st    = ref.watch(readerProvider);
    final selId = ref.watch(selectedWordIdProvider);

    return Container(
      height: _barHeight,
      color : Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child : Stack(
        clipBehavior: Clip.none,
        children: [
          /// ─────────── 主操作区 ───────────
          Row(
            children: [
              /// ① 播放 / 关闭视频
              AppIconButton(
                icon   : 'assets/icons/video-play.svg',
                active : st.videoControllerVisible,
                tooltip: st.videoControllerVisible ? '关闭视频' : '播放视频',
                onPressed: () {
                  if (st.videoControllerVisible) {
                    final player = ref.read(videoPlayerProvider);
                    player.pause();
                    ref.read(readerProvider.notifier)
                       .rememberVideoPos(player.state.position);
                  }
                  ref.read(readerProvider.notifier).toggleVideoComponents();
                },
              ),

              const Spacer(),

              /// ② 视图切换（页面 / 句子）
              AppIconButton(
                icon   : st.isPageView
                    ? 'assets/icons/page-view.svg'
                    : 'assets/icons/sentence-view.svg',
                tooltip: st.isPageView ? '页面视图' : '句子视图',
                onPressed: () =>
                    ref.read(readerProvider.notifier).toggleViewMode(),
              ),

              const Spacer(),

              /// ③ 词库 / 返回
              AppIconButton(
                icon   : 'assets/icons/vocabulary-icon.svg',
                active : selId != null,
                tooltip: selId != null ? '返回词库' : '打开词库',
                onPressed: () {
                  if (selId != null) {
                    ref.read(selectedWordIdProvider.notifier).state = null;
                  } else if (!st.sidebarOpen) {
                    ref.read(readerProvider.notifier).toggleSidebar();
                  }
                },
              ),
            ],
          ),

          /// ─────────── 视频控制条 ───────────
          if (st.videoControllerVisible)
            Positioned(
              left  : _ctlPaddingL,
              bottom: _ctlPaddingB,
              width : _ctlWidth,
              height: _ctlHeight,
              child : const VideoControllerWidget(),
            ),
        ],
      ),
    );
  }
}