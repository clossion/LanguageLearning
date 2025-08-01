import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/controller/reader_video_provider.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({super.key});

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  late final VideoController _videoController;
  bool _isInitialized = false;
  bool _isError = false;
  bool _disposed = false;
  String _errorMessage = '';
  Offset _offset = const Offset(250, 120);
  final Offset _initialOffset = const Offset(250, 120);
  ProviderSubscription<String?>? _pathSub;
  Size _videoSize = const Size(45, 10);

  @override
  void dispose() {
    // 完全避免在dispose中使用ref
    _pathSub?.close();
    _disposed = true;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final player = ref.read(videoPlayerProvider);
    _videoController = VideoController(player);

    _pathSub = ref.listenManual<String?>(
      readerProvider.select((s) => s.videoPath),
      (_, next) async {
        if (_disposed) return;
        if (!_isInitialized && next != null && next.isNotEmpty) {
          await _initializePlayer(next);
        }
      },
      fireImmediately: true,
    );
  }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      // 在didChangeDependencies中更新视频尺寸
      final screenSize = MediaQuery.of(context).size;
      double videoWidth = screenSize.width * 0.3;
      double videoHeight = videoWidth * 9/16;
      setState(() {
        _videoSize = Size(videoWidth, videoHeight);
      });
    }

  Future<void> _initializePlayer(String videoPath) async {
    if (_disposed || _isInitialized) return;

    final player = ref.read(videoPlayerProvider);
    final normalized = videoPath.replaceAll('\\', '/');

    if (!await File(videoPath).exists()) {
      setState(() {
        _isError = true;
        _errorMessage = '文件不存在: $videoPath';
      });
      return;
    }

    try {
      // 记住要恢复的位置
      final positionToRestore = ref.read(readerProvider).videoPosition;

      // 打开媒体
      await player.open(Media(normalized));
      if (_disposed) return;
      
      // 设置其他播放参数
      player.setRate(ref.read(playbackSpeedProvider));
      player.setPlaylistMode(
        ref.read(loopModeProvider) ? PlaylistMode.single : PlaylistMode.none,
      );
      
      // 先标记组件已初始化
      if (!_disposed) {
        setState(() {
          _isInitialized = true;
          _offset = _initialOffset;
        });
      }

      // 正确使用seek方法并等待它完成
      if (positionToRestore > Duration.zero) {
        // 暂停播放器，确保跳转后不立即播放
        await player.pause();
        
        // 等待一点时间，确保播放器准备好接受跳转命令
        await Future.delayed(const Duration(milliseconds: 200));
        
        // 执行跳转
        await player.seek(positionToRestore);
        
        // 再次检查当前位置
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      if (!_disposed) {
        setState(() {
          _isError = true;
          _errorMessage = '加载视频失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: Material(               // Dialog → Material；方便 Stack 里放把手
        color: Colors.transparent,
        child:SizedBox(
          width: _videoSize.width,
          height: _videoSize.height,
          child: Stack(
            children: [
              // —— ① 播放器主体 ——
              Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildBody(),        // 你原来显示 Video 的方法
                ),
              ),

              // —— ② 顶部 28PX 透明把手 ——
              Positioned(
                left: 0,
                right: 0,
                height: 28,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,   // 完全接管事件
                  onPanUpdate: (d) => setState(() => _offset += d.delta),
                  child: const SizedBox(),           // 透明占位即可
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_errorMessage,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(readerProvider.notifier).toggleVideo(),
              child: const Text('关闭'),
            )
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return AbsorbPointer(
      absorbing: true,   
      child: Video(controller: _videoController),
    );
  }
}
